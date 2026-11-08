#![allow(hidden_glob_reexports)]
extern crate self as horizon_mod_sdk;
pub mod horizon_sdk;
pub use horizon_sdk::*;
use horizon_mod_sdk::{Mod, Registration, game, hud, input, render, storage, ui, world};
use std::collections::VecDeque;
mod terrain;
mod debris;

const CONTROL: &str = "cosmic:control";
const SHADER: &str = include_str!("../data/cosmic.wgsl");
const NAMES: [&str; 6] = ["MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "NEPTUNE"];
const KEYS: [&str; 6] = ["mercury", "venus", "mars", "jupiter", "saturn", "neptune"];
const SUB: [&str; 6] = ["IRON LANCE / MOLTEN RUPTURE", "SULFUR VORTEX / ACID BASIN", "TECTONIC HEART / FRACTURE", "STORM REACTOR / THUNDER WELL", "RING BLADE / ANNULAR SCAR", "DARK DIAMOND / ICE IMPLOSION"];
const COLORS: [u32; 6] = [0xFFAE65, 0xD9ED64, 0xFF6749, 0xCCABFF, 0xF9DC9C, 0x56C9FF];
const PITCH: [f32;6] = [0.8,0.68,0.9,0.55,1.2,0.65];

struct Strike {
    tick: u32, target: [f64;3], dimension:String, planet:usize, terrain:bool, cinema:bool,
    columns:Vec<terrain::Column>, ready:bool, waiting:u32, tag:u32, surveyed:bool, sampled:bool,
    capture:Option<debris::Capture>, removals:Option<world::BlockEdit>,
}
struct Cosmic {
    planet:usize, cinema:bool, terrain:bool, fast:bool, menu:bool, hover:Option<usize>,
    strike:Option<Strike>, edits:VecDeque<world::BlockEdit>, survey_tag:u32, ticks:u64,
}
fn on(v:bool)-> &'static str {if v {"ON"} else {"OFF"}}
fn fill(x:f32,y:f32,w:f32,h:f32,c:u32)->ui::Draw {ui::Draw::Fill((ui::Rect{x,y,w,h},c))}
fn text(t:&str,x:f32,y:f32,c:u32)->ui::Draw {ui::Draw::Text((t.into(),ui::Point{x,y},c,true))}
fn polar(a:f32,r:f32)->ui::Point {ui::Point{x:a.cos()*r,y:a.sin()*r}}
fn sector(x:f32,y:f32)->Option<usize> {
    let r=x.hypot(y); if !(33.0..=94.0).contains(&r) {return None}
    let a=(y.atan2(x)+std::f32::consts::FRAC_PI_2+std::f32::consts::PI/6.).rem_euclid(std::f32::consts::TAU);
    Some((a/(std::f32::consts::TAU/6.)).floor() as usize %6)
}
impl Cosmic {
    fn save(&self) { let _=storage::set("settings-v2",format!("{} {} {} {}",self.planet,self.cinema as u8,self.terrain as u8,self.fast as u8).as_bytes()); }
    fn stop(&mut self) {self.strike=None;self.edits.clear();self.menu=false;self.hover=None;ui::close();render::clear_post();hud::clear();}
    fn draw_menu(&self) {
        let mut d=vec![fill(-160.,-120.,320.,240.,0xE807111F),text("COSMIC / SIX PLANET ARSENAL",0.,-112.,0xDCEEFF)];
        for i in 0..6 {
            let mid=-std::f32::consts::FRAC_PI_2+i as f32*std::f32::consts::TAU/6.;
            let bright=self.hover==Some(i)||self.planet==i;
            for j in 0..10 {
                let a=mid-std::f32::consts::PI/6.+0.028+j as f32*(std::f32::consts::PI/3.-0.056)/10.;
                let b=a+(std::f32::consts::PI/3.-0.056)/10.;
                d.push(ui::Draw::Quad((vec![polar(a,36.),polar(a,91.),polar(b,91.),polar(b,36.)],if bright {0xDD233F55}else{0xCC142435})));
                d.push(ui::Draw::Quad((vec![polar(a,89.),polar(a,91.),polar(b,91.),polar(b,89.)],0xFF000000|COLORS[i])));
            }
            let p=polar(mid,57.);
            d.push(ui::Draw::Item(("minecraft:paper".into(),format!("cosmic:{}",KEYS[i]),ui::Point{x:p.x-12.,y:p.y-12.},1.5)));
            let p=polar(mid,78.);d.push(text(NAMES[i],p.x,p.y-3.,if bright {COLORS[i]}else{0xA7BACD}));
        }
        d.push(text("EARTH",0.,-10.,0x8EDBFF));
        d.push(text(&format!("TERRAIN {}",on(self.terrain)),0.,3.,if self.terrain {0xFFC07A}else{0x8AA0B2}));
        d.push(text("click centre",0.,17.,0x748DA3));
        let show=self.hover.unwrap_or(self.planet);
        d.push(text(SUB[show],0.,96.,COLORS[show]));
        d.push(text(&format!("Z close / right-click: cinema {} / X abort",on(self.cinema)),0.,110.,0x8DA5BB));
        ui::show(&d);
    }
    fn open(&mut self) {self.menu=!self.menu;self.hover=None;if self.menu {self.draw_menu()}else{ui::close()}}
    fn fire(&mut self)->Result<(),String> {
        if self.strike.is_some(){return Err("Strike already running. X or /cosmic stop to abort.".into())}
        let p=game::get_player().ok_or("Enter a world first")?;
        if self.terrain && p.dimension!="minecraft:overworld" {return Err("Terrain mode supports the Overworld. /cosmic terrain off for other dimensions.".into())}
        let h=world::raycast(512.).ok_or("Aim at solid ground within 512 blocks")?;
        let target=[h.x,h.y,h.z];
        let mut columns=if self.terrain {terrain::plan(self.planet,target.map(|v|v.floor() as i32))}else{Vec::new()};
        if self.terrain && columns.is_empty(){return Err("This target cannot support a crater above bedrock.".into())}
        columns.sort_by_key(|c|{let dx=i64::from(c.x)-i64::from(h.block_x);let dz=i64::from(c.z)-i64::from(h.block_z);dx*dx+dz*dz});
        self.survey_tag=self.survey_tag.wrapping_add(1);
        let ready=!self.terrain;
        let capture:Option<debris::Capture>=None;
        if !ready {world::surface_height(self.survey_tag,&columns.iter().map(|c|(c.x,c.z)).collect::<Vec<_>>(),world::Heightmap::WorldSurface);}
        self.strike=Some(Strike{tick:0,target,dimension:p.dimension,planet:self.planet,terrain:self.terrain,cinema:self.cinema,columns,ready,waiting:0,tag:self.survey_tag,surveyed:ready,sampled:ready,capture,removals:None});
        ui::close();self.menu=false;
        if ready {self.activate()}
        Ok(())
    }
    fn activate(&self) {
        render::set_post(SHADER);
        if let Some(s)=&self.strike {if let Some(c)=&s.capture{c.upload()}else{render::set_data(&[0]);}world::play_sound("cosmic:charge",None,0.8,PITCH[s.planet]);}self.params();
    }
    fn params(&self) {if let Some(s)=&self.strike {if s.ready {render::set_params(&[s.target[0] as f32,s.target[1] as f32,s.target[2] as f32,s.tick as f32/20.,s.planet as f32,s.cinema as u8 as f32,s.terrain as u8 as f32,(!self.fast) as u8 as f32]);}}}
    fn collect_survey(&mut self) {
        let mut activated=false;
        for reply in world::poll_surface_heights() {
            if let Some(s)=&mut self.strike {if !s.surveyed && reply.tag==s.tag && reply.heights.len()==s.columns.len() && reply.heights.iter().all(Option::is_some) {
                let mut sources=s.columns.clone();
                for ((c,source),h) in s.columns.iter_mut().zip(sources.iter_mut()).zip(reply.heights) {let surface=h.unwrap()-1;c.fit_surface(surface);source.top=surface;}
                s.capture=Some(debris::capture(s.planet,s.target,&sources));
                if let Some(c)=&s.capture {world::read_columns(s.tag,&c.positions(),world::Heightmap::WorldSurface,debris::BELOW,0);}
                s.surveyed=true;
            }}
        }
        for reply in world::poll_columns() {
            if let Some(s)=&mut self.strike {if !s.sampled && reply.tag==s.tag {
                if let Some(c)=&mut s.capture {s.removals=c.finish(&reply);}
                s.sampled=true;
            }}
        }
        if let Some(s)=&mut self.strike {if !s.ready && s.surveyed && s.sampled{s.ready=true;activated=true;}}
        if activated {self.activate()}
    }
    fn carve(&mut self) {
        let Some(s)=&mut self.strike else{return};
        // Remove exactly the sampled source blocks before showing those same blocks in flight.
        if let Some(edit)=s.removals.take(){world::edit_blocks(&edit)}
        let mut edit=world::BlockEdit::default();let mut cost=0_u32;
        let mut columns=std::mem::take(&mut s.columns);
        let center_x=(s.target[0].floor() as i32).div_euclid(16);
        let center_z=(s.target[2].floor() as i32).div_euclid(16);
        // Finish nearby chunks together, avoiding repeated remesh/relight of the entire crater.
        columns.sort_by_key(|c|{
            let x=c.x.div_euclid(16);let z=c.z.div_euclid(16);
            let dx=i64::from(x)-i64::from(center_x);let dz=i64::from(z)-i64::from(center_z);
            (dx*dx+dz*dz,x,z,c.x,c.z)
        });
        for c in columns {
            let lining=palette(&mut edit.palette,c.lining);
            let air=palette(&mut edit.palette,"minecraft:air");
            if c.top>c.floor {let n=(c.top-c.floor) as u32;edit.runs.push(run(c.x,c.z,c.floor+1,n,air));cost+=n;}
            edit.runs.push(run(c.x,c.z,c.floor,1,lining));cost+=1;
            if let Some((y0,y1,b))=c.feature {let b=palette(&mut edit.palette,b);let n=(y1-y0+1).max(0) as u32;if n>0 {edit.runs.push(run(c.x,c.z,y0,n,b));cost+=n;}}
            // Geological skins and sliced spires are real blocks, including their exposed sides.
            for (y0,y1,b) in c.solids {
                let b=palette(&mut edit.palette,b);let n=(y1-y0+1).max(0) as u32;
                if n>0 {edit.runs.push(run(c.x,c.z,y0,n,b));cost+=n;}
            }
            if cost>=8000 {self.edits.push_back(std::mem::take(&mut edit));cost=0;}
        }
        if !edit.runs.is_empty(){self.edits.push_back(edit)}
    }
    fn panel(&self) {
        let selected=self.strike.as_ref().map_or(self.planet,|s|s.planet);
        let mut lines=vec![hud::Line{text:format!("COSMIC / {}",NAMES[selected]),color:COLORS[selected]}];
        if let Some(s)=&self.strike {
            let phase=if !s.ready {"SURVEYING TERRAIN"}else{match s.tick {0..=59=>"ASCENT",60..=159=>"PLANET CHARGE",160..=299=>"PROJECTILE CHASE",300..=339=>"RETURN TO EARTH",_=>"IMPACT / AFTERMATH"}};
            lines.push(hud::Line{text:phase.into(),color:0xD1E4F2});
            if !self.edits.is_empty(){lines.push(hud::Line{text:format!("Terrain batches: {}",self.edits.len()),color:0xFFC07A});}
        }
        lines.push(hud::Line{text:format!("Z: SIX ATTACKS | terrain {} | X: stop",on(self.terrain)),color:0x91A9BC});
        hud::set_panel(hud::Corner::TopLeft,&lines);
    }
}
fn palette(p:&mut Vec<String>,b:&str)->u32 {if let Some(i)=p.iter().position(|v|v==b){i as u32}else{p.push(b.into());(p.len()-1) as u32}}
fn run(x:i32,z:i32,y:i32,height:u32,block:u32)->world::BlockRun {world::BlockRun{x,z,y,height,surface:None,block,only:None}}
impl Mod for Cosmic {
    fn init()->Result<(Self,Registration),String>{
        input::claim_items(&[CONTROL.into()]);
        // A new ID migrates old R bindings; opening the six-choice wheel does not require holding the remote.
        input::register_key("arsenal","Choose one of six planetary attacks","key.keyboard.z");
        input::register_key("abort","Abort cosmic strike","key.keyboard.x");
        let mut s=Self{planet:0,cinema:true,terrain:true,fast:false,menu:false,hover:None,strike:None,edits:VecDeque::new(),survey_tag:0,ticks:0};
        if let Some(b)=storage::get("settings-v2"){let text=String::from_utf8_lossy(&b);let v:Vec<_>=text.split_whitespace().collect();if v.len()==4{s.planet=v[0].parse::<usize>().unwrap_or(0).min(5);s.cinema=v[1]=="1";s.terrain=v[2]=="1";s.fast=v[3]=="1";}}
        s.save();
        Ok((s,Registration::new().command("cosmic").on_tick().on_frame()))
    }
    fn command(&mut self,_:&str,args:&str)->Result<Option<String>,String>{
        let a:Vec<_>=args.split_whitespace().collect();
        match a.as_slice(){
            ["control"]|["give"]=>world::run_commands(&[format!("give @s {CONTROL}")]),
            ["menu"]|["wheel"]=>self.open(),["fire"]=>self.fire()?,["stop"]|["left-world"]=>self.stop(),
            ["planet",k]=>{self.planet=KEYS.iter().position(|n|n==k).ok_or("mercury | venus | mars | jupiter | saturn | neptune")?;self.save();},
            [kind,v] if ["cinema","terrain","quality"].contains(kind)=>{
                if *kind=="quality"{self.fast=match *v{"fast"=>true,"full"=>false,_=>return Err("quality fast|full".into())};}
                else{let b=match *v{"on"=>true,"off"=>false,_=>return Err("Use on|off".into())};if *kind=="cinema"{self.cinema=b}else{self.terrain=b}}self.save();
            },
            _=>return Ok(Some("/cosmic control | menu (Z) | planet NAME | fire | stop | cinema on/off | terrain on/off | quality full/fast".into()))
        }
        Ok(Some(format!("{} selected / terrain {} / Z opens all six",NAMES[self.planet],on(self.terrain))))
    }
    fn tick(&mut self,_:u64){
        self.ticks+=1;
        if game::get_player().is_none(){if self.strike.is_some(){self.stop()}return}
        if self.strike.as_ref().is_some_and(|s|game::get_player().is_some_and(|p|p.dimension!=s.dimension)){self.stop()}
        for e in input::poll(){match e{
            input::Event::KeyDown(k) if k=="abort"=>self.stop(),
            input::Event::KeyDown(k) if k=="arsenal"=>self.open(),
            input::Event::UseStart(u) if u.item.id==CONTROL=>{if let Err(e)=self.fire(){horizon_mod_sdk::chat::show(&e)}},
            input::Event::ScreenClosed=>self.menu=false,
            input::Event::ScreenClick(c) if self.menu=>{
                if c.button==1{self.cinema=!self.cinema;self.save();self.draw_menu()}
                else if c.button==0 {if c.x.hypot(c.y)<32. {self.terrain=!self.terrain;self.save();self.draw_menu()}else if let Some(i)=sector(c.x,c.y){self.planet=i;self.save();self.menu=false;ui::close();world::play_sound("minecraft:ui.button.click",None,0.6,1.);}}
            },_=>{}
        }}
        self.collect_survey();
        let mut impact=false;let mut timed_out=false;
        if let Some(s)=&mut self.strike{
            if !s.ready {s.waiting+=1;if s.waiting>=120 {timed_out=true}else if s.waiting%30==0{
                if !s.surveyed {world::surface_height(s.tag,&s.columns.iter().map(|c|(c.x,c.z)).collect::<Vec<_>>(),world::Heightmap::WorldSurface);}
                if !s.sampled {if let Some(c)=&s.capture{world::read_columns(s.tag,&c.positions(),world::Heightmap::WorldSurface,debris::BELOW,0);}}
            }}
            else{s.tick+=1;if s.tick==160{world::play_sound("cosmic:launch",None,0.9,PITCH[s.planet]);}
                if s.tick==340{impact=s.terrain;world::play_sound("cosmic:impact",Some((s.target[0],s.target[1],s.target[2])),4.,PITCH[s.planet]);render::shake(0.65,2.4);}
            }
        }
        if timed_out{self.stop();horizon_mod_sdk::chat::show("Terrain not loaded or server permission missing. Move closer to the target, or /cosmic terrain off for a visual strike.");}
        if impact{self.carve()}
        for _ in 0..2{if let Some(edit)=self.edits.pop_front(){world::edit_blocks(&edit)}else{break}}
        if self.strike.as_ref().is_some_and(|s|s.ready&&s.tick>=900)&&self.edits.is_empty(){self.stop()}
        if self.ticks%10==0{self.panel()}
    }
    fn frame(&mut self,_:f32){
        if self.strike.as_ref().is_some_and(|s|game::get_player().is_none_or(|p|p.dimension!=s.dimension)){self.stop()}
        self.params();
        if self.menu{let h=ui::cursor().and_then(|p|sector(p.x,p.y));if h!=self.hover{self.hover=h;self.draw_menu()}}
    }
}
horizon_mod_sdk::export_mod!(Cosmic);

#[cfg(test)]
mod native_tests;
