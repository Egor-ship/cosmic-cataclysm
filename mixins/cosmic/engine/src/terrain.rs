//! SDK-independent voxel geology. Apply clear, lining, feature, then solids.
use std::f64::consts::{PI, TAU};

pub const LOWEST_FLOOR: i32 = -59;
pub const HIGHEST_BLOCK: i32 = 319;
pub type Solid = (i32, i32, &'static str);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Column {
    pub x: i32,
    pub z: i32,
    pub floor: i32,
    pub top: i32,
    pub lining: &'static str,
    pub feature: Option<Solid>,
    /// Inclusive strata and disconnected ice overhangs; never fill their gaps.
    pub solids: Vec<Solid>,
}

impl Column {
    /// Survey heights are top solid blocks, not heightmap first-air values.
    pub fn fit_surface(&mut self, surface: i32) {
        let surface = surface.clamp(LOWEST_FLOOR, HIGHEST_BLOCK);
        let shift = (surface - self.floor).min(0);
        self.floor += shift;
        let fit = |(lo, hi, block): Solid| {
            let lo = (lo + shift).max(LOWEST_FLOOR);
            let hi = (hi + shift).min(HIGHEST_BLOCK);
            (lo <= hi).then_some((lo, hi, block))
        };
        self.feature = self.feature.and_then(fit);
        self.solids = self.solids.iter().copied().filter_map(fit).collect();
        self.top = self.top.max(surface.saturating_add(8)).min(HIGHEST_BLOCK);
    }
}

pub fn footprint(planet: usize) -> i32 {
    [46, 60, 64, 44, 68, 54].get(planet).copied().unwrap_or(0)
}

fn noise(x: i32, z: i32, salt: u32) -> f64 {
    let mut h = (x as u32).wrapping_mul(0x9e37_79b9)
        ^ (z as u32).wrapping_mul(0x85eb_ca6b) ^ salt;
    h ^= h >> 16;
    h = h.wrapping_mul(0x7feb_352d);
    h ^= h >> 15;
    f64::from(h) / f64::from(u32::MAX)
}

fn step(value: f64, size: f64) -> f64 { (value / size).round() * size }
fn angle_delta(a: f64, b: f64) -> f64 { (a - b + PI).rem_euclid(TAU) - PI }

/// Broad patches, tilted strata and sparse veins prevent random confetti noise.
fn rock(planet: usize, x: i32, z: i32, y: i32) -> &'static str {
    let patch = noise(x.div_euclid(5), z.div_euclid(5), 171 + planet as u32);
    let band = (y + (x + z).div_euclid(11)).div_euclid(4).rem_euclid(8);
    let vein = ((x * 3 - z * 2 + y).rem_euclid(37) < 2) && patch > 0.46;
    match planet {
        0 => if vein { "minecraft:iron_ore" } else { match band {
            0 => "minecraft:calcite", 1|2 => "minecraft:tuff", 3 => "minecraft:deepslate",
            4|5 => "minecraft:basalt", _ => "minecraft:obsidian" } },
        1 => if vein { "minecraft:oxidized_copper" } else { match band {
            0|1 => "minecraft:calcite", 2 => "minecraft:diorite", 3|4 => "minecraft:yellow_terracotta",
            5 => "minecraft:sandstone", _ => "minecraft:orange_terracotta" } },
        2 => match band { 0 => "minecraft:deepslate", 1 => "minecraft:granite",
            2|3 => "minecraft:red_terracotta", 4 => "minecraft:terracotta",
            5|6 => "minecraft:red_sandstone", _ => "minecraft:brown_terracotta" },
        3 => if vein { "minecraft:gold_ore" } else { match band {
            0 => "minecraft:calcite", 1 => "minecraft:oxidized_copper", 2 => "minecraft:tuff",
            3|4 => "minecraft:deepslate", 5 => "minecraft:basalt", _ => "minecraft:blackstone" } },
        4 => if vein { "minecraft:gold_ore" } else { match band {
            0|1 => "minecraft:calcite", 2 => "minecraft:amethyst_block", 3|4 => "minecraft:end_stone",
            5 => "minecraft:yellow_terracotta", _ => "minecraft:sandstone" } },
        _ => match band { 0 => "minecraft:snow_block", 1 => "minecraft:calcite",
            2|3 => "minecraft:packed_ice", 4|5 => "minecraft:blue_ice",
            6 => "minecraft:dark_prismarine", _ => "minecraft:cyan_terracotta" },
    }
}

fn add_run(runs: &mut Vec<Solid>, lo: i32, hi: i32, block: &'static str) {
    let lo = lo.max(LOWEST_FLOOR);
    let hi = hi.min(HIGHEST_BLOCK);
    if lo > hi { return; }
    if let Some(last) = runs.last_mut() {
        if last.1 + 1 == lo && last.2 == block { last.1 = hi; return; }
    }
    runs.push((lo, hi, block));
}

/// Radius <=68. Exposed walls receive real strata; buried rock stays intact.
pub fn plan(planet: usize, center: [i32; 3]) -> Vec<Column> {
    let radius = footprint(planet);
    if radius == 0 || !(LOWEST_FLOOR + 1..=HIGHEST_BLOCK).contains(&center[1])
        || center[0].checked_add(radius).is_none() || center[0].checked_sub(radius).is_none()
        || center[2].checked_add(radius).is_none() || center[2].checked_sub(radius).is_none() {
        return Vec::new();
    }
    let [cx, cy, cz] = center;
    let width = 2 * radius + 1;
    let index = |x: i32, z: i32| ((x + radius) * width + z + radius) as usize;
    let mut heights = vec![cy; (width * width) as usize];
    let mut columns = Vec::new();
    for x in -radius..=radius { for z in -radius..=radius {
        let r = f64::from(x*x + z*z).sqrt();
        let u = r / f64::from(radius);
        let a = f64::from(z).atan2(f64::from(x));
        let rough = noise(x.div_euclid(3), z.div_euclid(3), 81 + planet as u32);
        let edge = if planet == 2 { 0.84 + 0.16 * (a*5.).cos() }
            else { 0.975 + 0.018 * (a*7. + 0.7).sin() };
        if u > edge { continue; }
        let mut fill = None;
        let (depth, material) = match planet {
            0 => {
                let along = (f64::from(x) + f64::from(z)*0.45) / 1.0966;
                let cross = (f64::from(z) - f64::from(x)*0.45) / 1.0966;
                let crack = (a*9. + r*0.055).sin().abs()*r < 1.0 && u>0.24;
                let ridge = (1. - cross.abs()/4.0).max(0.) * ((along+15.)/40.).clamp(0.,1.);
                if ridge>0.02 && along<35. { fill=Some((cy as f64 + ridge*24. - 7., "minecraft:obsidian")); }
                if fill.is_none() {
                    let mut splinter=0.0_f64;
                    for (long,side,height) in [(15.,7.,24.),(4.,-8.,20.),(-6.,10.,16.)] {
                        let fin=(1.-(cross-side).abs()/1.7).max(0.)
                            *(1.-(along-long).abs()/12.).max(0.);
                        splinter=splinter.max(fin*height);
                    }
                    if splinter>1. {fill=Some((cy as f64-15.+splinter,"minecraft:obsidian"));}
                }
                let hot = (cross.abs()<1.2 && along> -18. && along<34.) || crack || r<5.;
                (step(32.*(1.-u*u),4.) + if crack {5.}else{0.},
                 if (x+18)*(x+18)+(z+8)*(z+8)<12 {"minecraft:lava"}
                 else if hot {"minecraft:magma_block"} else {rock(0,x,z,cy-12)})
            },
            1 => {
                let phase = (a + r*0.115).rem_euclid(TAU)/TAU;
                let shelf = (phase*3.).floor();
                let channel = phase<0.07 || (phase-0.34).abs()<0.035 || (phase-0.68).abs()<0.035;
                (step((1.-u)*12.,3.) + shelf*7. + if channel {5.} else {0.},
                 if channel {"minecraft:ochre_froglight"} else if (phase*3.).fract()>0.92 {"minecraft:calcite"}
                 else if noise(x.div_euclid(10),z.div_euclid(10),712)<0.2 {"minecraft:sandstone"}
                 else {"minecraft:yellow_terracotta"})
            },
            2 => {
                let crack = (a*5.).sin().abs()*r < 1.6 && u>0.2;
                // Five flat tilted plates: height follows their length, never a round hill profile.
                let axis=(a*5./TAU).round()*TAU/5.;
                let along=r*(a-axis).cos();let across=r*(a-axis).sin();
                if along>18. && across.abs()<(along-14.)*0.32 {
                    fill=Some((cy as f64 - 9. + step((along-18.)*0.86,2.),"minecraft:red_sandstone"));
                }
                if r<6. && rough>0.1 {fill=Some((cy as f64 + 13.-r*1.7,"minecraft:blackstone"));}
                (step(25.*(1.-(u/edge).powi(2)),3.) + if crack {8.} else {0.},
                 if crack {"minecraft:magma_block"} else {rock(2,x,z,cy-9)})
            },
            3 => {
                let branch = (a*7. + (r*0.2).sin()*0.6).sin().abs()*r < 1.0;
                if r<6. {fill=Some((cy as f64 + 35.*(1.-r/6.).max(0.).powf(1.4),"minecraft:blackstone"));}
                for i in 0..7 {
                    let b=i as f64*TAU/7.+0.2;
                    let d=((f64::from(x)-b.cos()*22.).powi(2)+(f64::from(z)-b.sin()*22.).powi(2)).sqrt();
                    if d<3.5 {fill=Some((cy as f64 + 11.*(1.-d/3.5),"minecraft:basalt"));}
                }
                (step(49.*(1.-u.powf(0.55)),5.)+if branch {6.}else{0.},
                 if branch && (x+z).rem_euclid(5)==0 {"minecraft:sea_lantern"}
                 else if branch {"minecraft:calcite"} else {rock(3,x,z,cy-17)})
            },
            4 => {
                let nearest=[0.32_f64,0.61,0.88].into_iter().map(|v|(u-v).abs()).fold(1.0_f64,f64::min);
                let trough=(1.-nearest/0.085).max(0.);
                let bridge=angle_delta(a,0.35+u*0.9).abs()<0.035
                    || (u>0.45 && angle_delta(a,3.7-u*0.6).abs()<0.03);
                if u<0.23 {fill=Some((cy as f64 + step((1.-u/0.23)*19.,4.),"minecraft:calcite"));}
                if nearest>0.09 {
                    let mut crystal=0.0_f64;
                    for i in 0..10 {
                        let ring=if i<5 {0.46} else {0.75};
                        let b=i as f64*TAU/5.+if i<5 {0.2}else{0.8};
                        let d=((x as f64-b.cos()*radius as f64*ring).powi(2)
                            +(z as f64-b.sin()*radius as f64*ring).powi(2)).sqrt();
                        crystal=crystal.max((1.-d/3.2).max(0.)*(9.+(i%3) as f64*2.));
                    }
                    if crystal>0. {fill=Some((cy as f64+crystal,"minecraft:amethyst_block"));}
                }
                (if bridge {1.}else{2.+step(trough*29.,3.)},
                 if trough>0.8 && (x-z).rem_euclid(11)<2 {"minecraft:glowstone"}
                 else if trough>0.8 {"minecraft:amethyst_block"} else {rock(4,x,z,cy-6)})
            },
            5 => {
                let fracture=(a*6.+r*0.035).sin().abs()*r<1.2;
                (step(57.*(1.-u.powf(1.3)),6.)+if fracture {4.}else{0.},
                 if fracture {"minecraft:sea_lantern"} else if rough>0.82 {"minecraft:snow_block"}
                 else if rough<0.22 {"minecraft:packed_ice"} else {"minecraft:blue_ice"})
            },
            _=>unreachable!(),
        };
        let floor=(cy-depth.max(1.).round() as i32).clamp(LOWEST_FLOOR,HIGHEST_BLOCK-1);
        let feature=fill.and_then(|(end,b)| {
            let end=(end.round() as i32).clamp(LOWEST_FLOOR,HIGHEST_BLOCK);
            (end>floor).then_some((floor+1,end,b))
        });
        heights[index(x,z)]=feature.map_or(floor,|f|f.1);
        columns.push(Column{x:cx+x,z:cz+z,floor,top:(cy+12).min(HIGHEST_BLOCK).max(floor+1),
            lining:material,feature,solids:Vec::new()});
    }}
    for c in &mut columns {
        let x=c.x-cx;let z=c.z-cz;
        let surface=heights[index(x,z)];
        let neighbor=[(x-1,z),(x+1,z),(x,z-1),(x,z+1)].into_iter()
            .filter(|(x,z)|x.abs()<=radius&&z.abs()<=radius)
            .map(|(x,z)|heights[index(x,z)]).min().unwrap_or(surface);
        // Skin reaches below adjacent floor so exposed walls have coherent bands.
        for y in (c.floor.min(neighbor)-2).max(LOWEST_FLOOR)..=surface {
            let r=f64::from(x*x+z*z).sqrt();
            let feature_rock=match planet {
                2 if r<6. => Some(if (x+z+y).rem_euclid(7)<2 {"minecraft:basalt"} else {"minecraft:blackstone"}),
                3 => c.feature.map(|_|if (x-z).rem_euclid(11)==0 {"minecraft:amethyst_block"}
                    else if y.rem_euclid(13)<2 {"minecraft:deepslate"} else {"minecraft:basalt"}),
                4 if c.feature.is_some_and(|f|f.2=="minecraft:amethyst_block") => Some("minecraft:amethyst_block"),
                _ => None,
            };
            let block=if let Some(b)=feature_rock {b} else if y==surface {
                if c.feature.is_some(){rock(planet,x,z,y)}else{c.lining}
            } else {rock(planet,x,z,y)};
            add_run(&mut c.solids,y,y,block);
        }
        if planet==0 {
            let cross=(f64::from(z)-f64::from(x)*0.45)/1.0966;
            if cross.abs()<1.1 && c.feature.is_some() {
                add_run(&mut c.solids,surface,surface,"minecraft:magma_block");
            }
        }
        if planet==3 && c.feature.is_some() && (x-z).rem_euclid(7)==0 {
            add_run(&mut c.solids,surface-1,surface,"minecraft:amethyst_block");
        }
        if planet==5 {
            // Slanted tapering volumes: roots on excavated shelves, tips inward.
            for i in 0..6 {
                let angle=i as f64*TAU/6.+PI/12.;
                let length=[56.,46.,61.,49.,58.,43.][i];
                let radial=radius as f64*0.73;
                let base_y=cy-22;
                for y in base_y..=(base_y+length as i32).min(HIGHEST_BLOCK) {
                    let t=(y-base_y) as f64/length;
                    let rr=radial-t*15.;
                    let sx=angle.cos()*rr;let sz=angle.sin()*rr;
                    let thick=6.2*(1.-t).powf(0.72)+0.45;
                    let d=((x as f64-sx).powi(2)+(z as f64-sz).powi(2)).sqrt();
                    if d<thick && y>c.floor {
                        let block=if t>0.85 || (x+z).rem_euclid(5)==0 {"minecraft:snow_block"}
                            else if d>thick*0.67 {"minecraft:packed_ice"} else {"minecraft:blue_ice"};
                        add_run(&mut c.solids,y,y,block);
                    }
                }
            }
        }
    }
    columns
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn six_concepts_have_rich_strata_and_bounded_work() {
        use std::collections::BTreeSet;
        let mut signatures=BTreeSet::new();
        for planet in 0..6 {
            let p=plan(planet,[0,80,0]);
            assert_eq!(p,plan(planet,[0,80,0]));
            let materials:BTreeSet<_>=p.iter().flat_map(|c|c.solids.iter().map(|r|r.2)).collect();
            assert!(materials.len()>=6,"planet {planet}: {materials:?}");
            let cost:i64=p.iter().map(|c|i64::from(c.top-c.floor+1)+c.feature.map_or(0,|s|i64::from(s.1-s.0+1))
                +c.solids.iter().map(|s|i64::from(s.1-s.0+1)).sum::<i64>()).sum();
            let runs:usize=p.iter().map(|c|2+usize::from(c.feature.is_some())+c.solids.len()).sum();
            assert!(cost<1_500_000,"planet {planet} cost {cost}");
            assert!(runs<150_000,"planet {planet} runs {runs}");
            assert!(signatures.insert((p.len(),cost,runs)));
            eprintln!("planet {planet}: {} columns, {cost} blocks, {runs} runs, {} materials",p.len(),materials.len());
            for surface in [50,80,120,319] {
                let surveyed:i64=p.iter().cloned().map(|mut c|{
                    c.fit_surface(surface);
                    i64::from(c.top-c.floor+1)+c.feature.map_or(0,|s|i64::from(s.1-s.0+1))
                        +c.solids.iter().map(|s|i64::from(s.1-s.0+1)).sum::<i64>()
                }).sum();
                eprintln!("planet {planet}, surveyed uniform y={surface}: {surveyed} block writes");
            }
        }
    }
    #[test]
    fn bounds_survive_surveying_and_build_limits() {
        for y in [-58,0,80,318,319] { for planet in 0..6 {
            for mut c in plan(planet,[100,y,-200]) {
                c.fit_surface(y.saturating_sub(30));
                assert!((LOWEST_FLOOR..HIGHEST_BLOCK).contains(&c.floor));
                assert!(c.top>c.floor&&c.top<=HIGHEST_BLOCK);
                for (lo,hi,_) in c.solids.iter().copied().chain(c.feature) {
                    assert!(lo>=LOWEST_FLOOR&&hi>=lo&&hi<=HIGHEST_BLOCK);
                }
            }
        }}
        assert!(plan(0,[i32::MAX,80,0]).is_empty());
        assert!(plan(6,[0,80,0]).is_empty());
        assert!(plan(0,[0,-60,0]).is_empty());
    }
    #[test]
    fn concepts_have_real_ridges_rings_well_and_leaning_ice() {
        let at=|p:usize,x,z|plan(p,[0,80,0]).into_iter().find(|c|c.x==x&&c.z==z).unwrap();
        assert!(at(0,20,9).feature.is_some());
        assert!(at(2,48,0).feature.unwrap().1>90);
        assert!(at(3,0,0).feature.unwrap().1>=114);
        assert!(at(4,0,0).feature.unwrap().1>=99);
        assert!(at(4,22,0).floor+12<at(4,31,0).floor);
        assert!(at(5,0,0).floor<=23);
        let ice=plan(5,[0,80,0]);
        for i in 0..6 {
            let a=i as f64*TAU/6.+PI/12.;
            let x=(a.cos()*(54.*0.73-12.)).round() as i32;
            let z=(a.sin()*(54.*0.73-12.)).round() as i32;
            let c=ice.iter().find(|c|c.x==x&&c.z==z).unwrap();
            assert!(c.solids.iter().any(|r|r.0>c.floor+8&&r.1>85),"missing leaning spire {i}");
        }
    }
}
