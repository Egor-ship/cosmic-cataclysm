#![allow(hidden_glob_reexports)]
extern crate self as horizon_mod_sdk;
pub mod horizon_sdk;
pub use horizon_sdk::*;
use horizon_mod_sdk::{Mod, Registration, game, hud, input, render, storage, ui, world};
use std::collections::VecDeque;

const CONTROL: &str = "cosmic:control";
const SHADER: &str = include_str!("../data/cosmic.wgsl");
const NAMES: [&str; 6] = ["MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "NEPTUNE"];
const KEYS: [&str; 6] = ["mercury", "venus", "mars", "jupiter", "saturn", "neptune"];
const SUB: [&str; 6] = ["IRON RAIN", "ACID CYCLONE", "RED TEMPEST", "THUNDER COLOSSUS", "RINGFALL", "SINGULARITY TIDE"];
const COLORS: [u32; 6] = [0xFFAE65, 0xD9ED64, 0xFF6749, 0xCCABFF, 0xF9DC9C, 0x56C9FF];
const LINING: [&str; 6] = ["obsidian", "yellow_stained_glass", "red_sandstone", "blackstone", "packed_ice", "blue_ice"];

struct Strike { tick: u32, target: [f64; 3], dimension: String, planet: usize, terrain: bool, cinema: bool }
struct Cosmic { planet: usize, cinema: bool, terrain: bool, fast: bool, menu: bool, strike: Option<Strike>, edits: VecDeque<String> }

impl Cosmic {
    fn save(&self) { let _ = storage::set("settings", format!("{} {} {} {}", self.planet, self.cinema as u8, self.terrain as u8, self.fast as u8).as_bytes()); }
    fn stop(&mut self) { self.strike = None; self.edits.clear(); render::clear_post(); hud::clear(); }
    fn open(&mut self) {
        self.menu = true;
        let mut d = vec![fill(-154.,-113.,308.,226.,0xF20B101C), text("COSMIC / PLANETARY CONTROL",-140.,-100.,0xDCEEFF), text("Select planet. Right-click the world to fire.",-140.,-86.,0x8192AA)];
        for i in 0..6 {
            let x = -140. + (i%2) as f32*145.; let y = -65. + (i/2) as f32*43.;
            d.push(fill(x,y,135.,36.,if i==self.planet {0xFF243C53} else {0xFF131F30}));
            d.push(fill(x,y,3.,36.,0xFF000000|COLORS[i]));
            d.push(text(NAMES[i],x+9.,y+7.,COLORS[i])); d.push(text(SUB[i],x+9.,y+21.,0x9CAFC6));
        }
        d.push(text(&format!("CINEMA {}    TERRAIN {}",on(self.cinema),on(self.terrain)),-140.,75.,0xA2BACF));
        d.push(text("Click left: cinema / right: terrain",-140.,88.,0x8192AA));
        d.push(text("R menu / X abort / Esc close",-140.,101.,0x8192AA));
        ui::show(&d);
    }
    fn fire(&mut self) -> Result<(),String> {
        if self.strike.is_some() { return Err("A strike is already running. /cosmic stop to abort.".into()); }
        let p=game::get_player().ok_or("Enter a world first")?;
        if self.terrain && p.dimension!="minecraft:overworld" {return Err("Terrain mode currently supports the Overworld only.".into());}
        let h=world::raycast(512.).ok_or("Aim at terrain within 512 blocks")?;
        if ((h.x-p.x).powi(2)+(h.z-p.z).powi(2)).sqrt()<45. {return Err("Aim at least 45 blocks away to see the blast.".into());}
        ui::close(); self.menu=false; self.edits.clear();
        render::set_post(SHADER);
        world::play_sound("cosmic:charge",None,0.8,1.);
        self.strike=Some(Strike {tick:0,target:[h.x,h.y,h.z],dimension:p.dimension,planet:self.planet,terrain:self.terrain,cinema:self.cinema});
        self.params(); Ok(())
    }
    fn params(&self) {
        if let Some(s)=&self.strike { render::set_params(&[s.target[0] as f32,s.target[1] as f32,s.target[2] as f32,s.tick as f32/20.,s.planet as f32,s.cinema as u8 as f32,s.terrain as u8 as f32,(!self.fast) as u8 as f32]); }
    }
    fn crater(&mut self) {
        let Some(s)=&self.strike else{return};
        let [x,y,z]=s.target.map(|v|v.floor() as i32);
        let top=(y+8).min(319);
        // Narrow columns keep every fill below the command block cap; 32 columns per tick.
        // Only a bounded bowl under the target is edited; no world-wide entity selectors.
        for dx in -34_i32..=34 {for dz in -34_i32..=34 {
            let r2=dx*dx+dz*dz; if r2>34*34 {continue}
            let dep=(18.*(1.-r2 as f32/(34.*34.))).round() as i32;
            if dep<1 {continue}
            let floor=(y-dep).max(-63);
            if floor>=top {continue}
            self.edits.push_back(format!("fill {} {} {} {} {} {} air replace",x+dx,floor+1,z+dz,x+dx,top,z+dz));
            self.edits.push_back(format!("setblock {} {} {} minecraft:{}",x+dx,floor,z+dz,LINING[s.planet]));
        }}
    }
}
fn on(v:bool)-> &'static str {if v {"ON"}else{"OFF"}}
fn fill(x:f32,y:f32,w:f32,h:f32,c:u32)->ui::Draw {ui::Draw::Fill((ui::Rect{x,y,w,h},c))}
fn text(t:&str,x:f32,y:f32,c:u32)->ui::Draw {ui::Draw::Text((t.into(),ui::Point{x,y},c,false))}

impl Mod for Cosmic {
    fn init()->Result<(Self,Registration),String>{
        input::claim_items(&[CONTROL.into()]); input::register_key("control","Planetary control","key.keyboard.r"); input::register_key("abort","Abort cosmic strike","key.keyboard.x");
        let mut s=Self{planet:0,cinema:true,terrain:false,fast:false,menu:false,strike:None,edits:VecDeque::new()};
        if let Some(b)=storage::get("settings") {let txt=String::from_utf8_lossy(&b);let v:Vec<_>=txt.split_whitespace().collect();if v.len()==4 {s.planet=v[0].parse::<usize>().unwrap_or(0).min(5);s.cinema=v[1]=="1";s.terrain=v[2]=="1";s.fast=v[3]=="1";}}
        Ok((s,Registration::new().command("cosmic").on_tick().on_frame()))
    }
    fn command(&mut self,_:&str,args:&str)->Result<Option<String>,String>{
        let a:Vec<_>=args.split_whitespace().collect();
        match a.as_slice() {
            ["control"]=>{world::run_commands(&[format!("give @s {CONTROL}")]);},
            ["menu"]=>self.open(), ["fire"]=>self.fire()?, ["stop"] | ["left-world"]=>self.stop(),
            ["planet",k]=>{self.planet=KEYS.iter().position(|n|n==k).ok_or("mercury | venus | mars | jupiter | saturn | neptune")?;self.save();},
            [kind,v] if ["cinema","terrain","quality"].contains(kind)=>{
                if *kind=="quality" {self.fast=match *v {"fast"=>true,"full"=>false,_=>return Err("quality fast|full".into())};}
                else {let b=match *v {"on"=>true,"off"=>false,_=>return Err("Use on|off".into())};if *kind=="cinema" {self.cinema=b;}else{self.terrain=b;}} self.save();
            },
            _=>return Ok(Some("/cosmic control | menu | planet NAME | fire | stop | cinema on/off | terrain on/off | quality full/fast".into()))
        } Ok(Some(format!("{} / cinema {} / terrain {}",NAMES[self.planet],on(self.cinema),on(self.terrain))))
    }
    fn tick(&mut self,_:u64){
        if self.strike.as_ref().is_some_and(|s|game::get_player().is_none_or(|p|p.dimension!=s.dimension)){self.stop();}
        for e in input::poll(){match e {
            input::Event::KeyDown(k) if k=="abort"=>self.stop(),
            input::Event::KeyDown(k) if k=="control" && input::held().is_some_and(|h|h.id==CONTROL)=>self.open(),
            input::Event::UseStart(u) if u.item.id==CONTROL=>{if let Err(e)=self.fire(){horizon_mod_sdk::chat::show(&e);}},
            input::Event::ScreenClosed=>self.menu=false,
            input::Event::ScreenClick(c) if self.menu && c.button==0=>{
                if c.y>= -65. && c.y<64. && c.x>= -140. && c.x<140. {
                    let col=usize::from(c.x>=5.);let row=((c.y+65.)/43.) as usize;
                    self.planet=(row*2+col).min(5);self.save();self.open();
                } else if c.y>=72. && c.y<=98. {if c.x<0. {self.cinema=!self.cinema;}else{self.terrain=!self.terrain;}self.save();self.open();}
            }, _=>{}
        }}
        let mut impact=false;
        if let Some(s)=&mut self.strike {
            s.tick+=1;
            if s.tick==160 {world::play_sound("cosmic:launch",None,0.9,1.);}
            if s.tick==340 {impact=true;world::play_sound("cosmic:impact",Some((s.target[0],s.target[1],s.target[2])),4.,1.);render::shake(0.65,2.4);}
            let phase=match s.tick {0..=59=>"ASCENT",60..=159=>"PLANET CHARGE",160..=299=>"PROJECTILE CHASE",300..=339=>"RETURN TO EARTH",_=>"IMPACT"};
            hud::set_panel(hud::Corner::TopLeft,&[hud::Line{text:format!("{} / {}",NAMES[s.planet],phase),color:COLORS[s.planet]},hud::Line{text:"X abort | /cosmic stop".into(),color:0x9CB1CA}]);
        }
        if impact && self.strike.as_ref().is_some_and(|s|s.terrain){self.crater();}
        let batch:Vec<_>=(0..64).filter_map(|_|self.edits.pop_front()).collect();if !batch.is_empty(){world::run_commands(&batch);}
        if self.strike.as_ref().is_some_and(|s|s.tick>=700) && self.edits.is_empty(){self.stop();}
    }
    fn frame(&mut self,_:f32){
        if self.strike.as_ref().is_some_and(|s|game::get_player().is_none_or(|p|p.dimension!=s.dimension)){self.stop();}
        self.params();
    }
}
horizon_mod_sdk::export_mod!(Cosmic);
