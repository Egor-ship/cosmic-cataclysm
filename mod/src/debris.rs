//! Flying debris is captured from the affected world, never invented geometry/materials.
//! Four 5x5 patches retain neighbouring trunk, leaf and ground blocks as rigid fragments.
//! read-columns supplies block IDs without state properties, so the atlas uses each ID's
//! default cube model. Non-cubes, translucent models and block entities are left out.
use crate::terrain;
use horizon_mod_sdk::{atlas, render, world};
use std::collections::HashMap;

pub const BELOW: u32 = 32;
pub const ABOVE: u32 = 0;
const MAGIC: u32 = 0x4344_4232;
const MAX_BLOCKS: usize = 256;
const GROUP_WORDS: usize = 16;
const BLOCK_WORDS: usize = 64;

#[derive(Clone)]
struct Source { x: i32, z: i32, floor: i32, top: i32, group: usize }
struct Piece { source: [i32; 3], group: usize, palette: usize, class: usize }

pub struct Capture {
    planet: usize,
    target: [f64; 3],
    sources: Vec<Source>,
    words: Vec<u32>,
    finished: bool,
}

pub fn capture(planet: usize, target: [f64; 3], columns: &[terrain::Column]) -> Capture {
    let mut candidates: Vec<_> = columns.iter().filter(|c| {
        let dx=f64::from(c.x)-target[0]; let dz=f64::from(c.z)-target[2];
        dx*dx+dz*dz < (f64::from(terrain::footprint(planet))*0.62).powi(2)
    }).collect();
    // High surveyed patches are likely to contain real tree canopies. Separation keeps
    // samples spread around the crater; the last patch samples lower ground as well.
    candidates.sort_by_key(|c| (-i64::from(c.top), (i64::from(c.x)*73856093 ^ i64::from(c.z)*19349663).unsigned_abs()));
    let lookup: HashMap<_, _> = columns.iter().map(|c| ((c.x,c.z),c)).collect();
    let mut centers=Vec::new();
    for c in &candidates {
        if centers.iter().all(|&(x,z): &(i32,i32)| (x-c.x).pow(2)+(z-c.z).pow(2)>12*12) {
            centers.push((c.x,c.z));
            if centers.len()==3 {break}
        }
    }
    candidates.reverse();
    if let Some(c)=candidates.iter().find(|c| centers.iter().all(|&(x,z)| (x-c.x).pow(2)+(z-c.z).pow(2)>12*12)) {
        centers.push((c.x,c.z));
    }
    let mut sources=Vec::new();
    for (group,(x,z)) in centers.into_iter().enumerate() {
        for dx in -2..=2 {for dz in -2..=2 {
            if let Some(c)=lookup.get(&(x+dx,z+dz)) {
                sources.push(Source{x:c.x,z:c.z,floor:c.floor,top:c.top,group});
            }
        }}
    }
    Capture{planet,target,sources,words:vec![MAGIC,0,0,BLOCK_WORDS as u32],finished:false}
}

fn class(name: &str) -> Option<usize> {
    let n=name.strip_prefix("minecraft:")?;
    if ["air","cave_air","void_air","water","lava","bedrock","barrier"].contains(&n)
        || n.contains("chest") || n.contains("shulker") || n.contains("spawner") {return None}
    Some(if n.ends_with("_log") || n.ends_with("_wood") || n.ends_with("_stem") {0}
         else if n.ends_with("_leaves") {1}
         else if ["dirt","grass_block","stone","deepslate","sand","red_sand","gravel","mud","sandstone","red_sandstone","coarse_dirt","podzol"].contains(&n) {2}
         else {3})
}

fn tint(t: &atlas::Tint, biome: &[u32]) -> u32 {
    match t {
        atlas::Tint::None=>0xff_ffff,
        atlas::Tint::Grass=>biome.first().copied().unwrap_or(0xff_ffff),
        atlas::Tint::Foliage | atlas::Tint::DryFoliage=>biome.get(1).copied().unwrap_or(0xff_ffff),
        atlas::Tint::Water=>biome.get(2).copied().unwrap_or(0xff_ffff),
        atlas::Tint::Fixed(c)=>*c,
    }
}

impl Capture {
    pub fn positions(&self) -> Vec<(i32,i32)> {self.sources.iter().map(|s|(s.x,s.z)).collect()}

    /// The reply must be for positions(), BELOW=32 and ABOVE=0. Returns removals
    /// guarded by each sampled block ID, so changes made since the read are spared.
    pub fn finish(&mut self, reply: &world::ColumnBlocks) -> Option<world::BlockEdit> {
        if self.finished || reply.bases.len()!=self.sources.len()
            || reply.blocks.len()!=self.sources.len()*BELOW as usize {return None}
        let models=atlas::block_sprites(&reply.palette);
        let valid:Vec<_>=models.iter().map(|m|m.as_ref().is_some_and(|m|m.cube && m.sides.len()==6
            && m.sides.iter().all(|side|side.first().is_some_and(|f|f.sprite.array==0 && !f.translucent)))).collect();
        let mut choices: [Vec<Piece>;4]=std::array::from_fn(|_|Vec::new());
        for (i,source) in self.sources.iter().enumerate() {
            let Some(base)=reply.bases[i] else {continue};
            for j in 0..BELOW as usize {
                let y=base-BELOW as i32+j as i32;
                if y<=source.floor || y>source.top || y<=terrain::LOWEST_FLOOR {continue}
                let palette=usize::from(reply.blocks[i*BELOW as usize+j]);
                let Some(name)=reply.palette.get(palette) else {continue};
                let Some(kind)=class(name) else {continue};
                if !valid.get(palette).copied().unwrap_or(false) {continue}
                choices[kind].push(Piece{source:[source.x,y,source.z],group:source.group,palette,class:kind});
            }
        }
        // Keep trunks, canopies AND soil. A forest query otherwise spends the whole
        // budget on either its first tree or its topmost leaves.
        for list in &mut choices {list.sort_by_key(|p|(p.source[1],p.source[0],p.source[2],p.group));}
        let quotas=[64,144,48,0];
        let mut selected=Vec::new();
        for (kind,list) in choices.iter_mut().enumerate() {
            let n=quotas[kind].min(list.len());
            selected.extend(list.drain(..n));
        }
        for list in &mut choices {while selected.len()<MAX_BLOCKS {let Some(p)=list.pop() else {break};selected.push(p);}}
        selected.truncate(MAX_BLOCKS);
        selected.sort_by_key(|p|p.group);
        if selected.is_empty() {self.finished=true;self.upload();return None}
        let groups=self.sources.iter().map(|s|s.group).max().unwrap_or(0)+1;
        let mut words=vec![0;4+groups*GROUP_WORDS+selected.len()*BLOCK_WORDS];
        words[..4].copy_from_slice(&[MAGIC,selected.len() as u32,groups as u32,BLOCK_WORDS as u32]);
        let mut edit=world::BlockEdit{palette:vec!["minecraft:air".into()],filters:reply.palette.clone(),runs:Vec::new()};
        for group in 0..groups {
            let members:Vec<_>=selected.iter().enumerate().filter(|(_,p)|p.group==group).collect();
            if members.is_empty(){continue}
            let mut pivot=[0.0_f32;3];
            for (_,p) in &members {for a in 0..3 {pivot[a]+=(f64::from(p.source[a])+0.5-self.target[a]) as f32/members.len() as f32;}}
            let radius=members.iter().map(|(_,p)|{
                (0..3).map(|a|((f64::from(p.source[a])+0.5-self.target[a]) as f32-pivot[a]).powi(2)).sum::<f32>().sqrt()+0.87
            }).fold(0.87_f32,f32::max);
            let radial=(pivot[0]*pivot[0]+pivot[2]*pivot[2]).sqrt().max(1.0);
            let speed=[16.,9.,22.,12.,26.,11.][self.planet.min(5)];
            let lift=[26.,18.,22.,40.,28.,34.][self.planet.min(5)]+group as f32*2.;
            let h=4+group*GROUP_WORDS;
            let vals=[pivot[0],pivot[1],pivot[2],pivot[0]/radial*speed,lift,pivot[2]/radial*speed,
                0.18+group as f32*0.09,0.24,0.12-group as f32*0.08,group as f32*0.10,radius];
            for (i,v) in vals.into_iter().enumerate(){words[h+i]=v.to_bits();}
            words[h+11]=members[0].0 as u32;words[h+12]=members.len() as u32;
            for (index,p) in members {
                let source_index=self.sources.iter().position(|s|s.x==p.source[0] && s.z==p.source[2]).unwrap();
                let biome=reply.tints.get(source_index*3..source_index*3+3).unwrap_or(&[]);
                let model=models[p.palette].as_ref().unwrap();
                let at=4+groups*GROUP_WORDS+index*BLOCK_WORDS;
                for a in 0..3 {words[at+a]=((f64::from(p.source[a])+0.5-self.target[a]) as f32-pivot[a]).to_bits();}
                words[at+3]=p.class as u32;
                for side in 0..6 {
                    let f=&model.sides[side][0];let off=at+16+side*8;
                    words[off]=f.sprite.layer | if f.sprite.cutout {1<<31}else{0};
                    words[off+1]=tint(&f.tint,biome);
                    for (k,v) in [f.uv.0,f.uv.1,f.uv.2,f.uv.3,f.uv.4,f.uv.5].into_iter().enumerate(){words[off+2+k]=v.to_bits();}
                }
                edit.runs.push(world::BlockRun{x:p.source[0],z:p.source[2],y:p.source[1],height:1,surface:None,block:0,only:Some(p.palette as u32)});
            }
        }
        self.words=words;self.finished=true;Some(edit)
    }

    pub fn upload(&self) {render::set_data(&self.words);}
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn excludes_fluids_bedrock_and_containers() {
        for s in ["minecraft:air","minecraft:water","minecraft:lava","minecraft:bedrock","minecraft:chest","minecraft:ender_chest"] {assert!(class(s).is_none());}
        assert_eq!(class("minecraft:oak_log"),Some(0));assert_eq!(class("minecraft:oak_leaves"),Some(1));assert_eq!(class("minecraft:dirt"),Some(2));
    }
    #[test] fn sources_are_actual_columns_in_four_bounded_patches() {
        let cols=terrain::plan(0,[0,72,0]);let capture=capture(0,[0.,72.,0.],&cols);
        let p=capture.positions();assert!(!p.is_empty() && p.len()<=100);
        for (x,z) in p {assert!(cols.iter().any(|c|c.x==x&&c.z==z));}
    }
}
