//! Smoke checks against the real native SDK shim; no live game, saves or user settings are read.
use super::*;
use super::horizon_sdk::__host as host;
use std::sync::{Arc, atomic::{AtomicU64, Ordering}};

static NEXT:AtomicU64=AtomicU64::new(0);
struct IsolatedHost {dir:std::path::PathBuf}
impl IsolatedHost {
    fn new()->Self {
        let stamp=std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
        let dir=std::env::temp_dir().join(format!("cosmic-native-smoke-{}-{stamp}-{}",std::process::id(),NEXT.fetch_add(1,Ordering::Relaxed)));
        // create_dir, rather than create_dir_all, guarantees this test owns a fresh directory.
        std::fs::create_dir(&dir).unwrap();
        host::with(|s| {
            *s=host::State::default();s.data_dir=dir.clone();s.id="cosmic".into();s.name="Cosmic test".into();
            s.snapshot.player=Some(game::Player{x:0.,y:70.,z:0.,dimension:"minecraft:overworld".into(),..Default::default()});
            s.snapshot.clock=Some(game::Clock{game_time:1000,day_time:6000});
            s.snapshot.view_hit=Some((100.,world::Hit{block_x:100,block_y:70,block_z:0,x:100.,y:70.,z:0.,block:"minecraft:grass_block".into()}));
            s.atlas=Some(host::Atlas {
                blocks:Arc::new(|names|names.iter().map(|_|{
                    let face=super::horizon_sdk::atlas::Face {
                        sprite:super::horizon_sdk::atlas::Sprite{array:0,layer:0,animated:false,cutout:false},
                        rect:(0.,0.,1.,1.),inset:0.,uv:(0.,0.,1.,0.,0.,1.),
                        tint:super::horizon_sdk::atlas::Tint::None,translucent:false,
                    };
                    Some(super::horizon_sdk::atlas::BlockFaces{sides:vec![vec![face];6],particle:None,cube:true})
                }).collect()),
                textures:Arc::new(|names|names.iter().map(|_|None).collect()),version:1,
            });
        });
        Self{dir}
    }
}
impl Drop for IsolatedHost {
    fn drop(&mut self){host::with(|s|*s=host::State::default());std::fs::remove_dir_all(&self.dir).unwrap();}
}

/// Return queued output for assertions and answer asynchronous reads as a loaded flat test world.
fn answer_world()->Vec<host::Output> {
    let out=host::with(|s|std::mem::take(&mut s.out));
    for output in &out {match output {
        host::Output::Surface{tag,columns,..}=>host::with(|s|s.surface.push(world::SurfaceHeights{tag:*tag,heights:vec![Some(71);columns.len()]})),
        host::Output::Columns{tag,columns,below,above,..}=> {
            let span=(*below+*above) as usize;
            let blocks=(0..columns.len()*span).map(|i|{
                let y=i%span;
                if y+1<*below as usize {1} else if y<*below as usize {2} else {0}
            }).collect();
            host::with(|s|s.columns.push(world::ColumnBlocks{
                tag:*tag,palette:vec!["minecraft:air".into(),"minecraft:stone".into(),"minecraft:grass_block".into()],
                bases:vec![Some(71);columns.len()],blocks,tints:vec![0x80A060;columns.len()*3],
            }));
        },_=>{}
    }}
    out
}
fn initialize()->Cosmic {Cosmic::init().unwrap().0}
fn command(s:&mut Cosmic,c:&str){s.command("cosmic",c).unwrap();}

#[test]
fn fresh_install_registers_z_and_migrates_old_visual_only_settings() {
    let _host=IsolatedHost::new();
    storage::set("settings",b"5 1 0 0").unwrap();
    let mut cosmic=initialize();
    assert!(cosmic.terrain,"old visual-only settings must not silently disable the requested craters");
    host::with(|s|assert!(s.keys.iter().any(|k|k.name=="arsenal"&&k.key=="key.keyboard.z")));
    command(&mut cosmic,"terrain off");
    drop(cosmic);
    assert!(!initialize().terrain,"an explicit v2 terrain-off choice must be preserved");
}

#[test]
fn z_opens_all_six_sectors_without_holding_the_remote() {
    let _host=IsolatedHost::new();let mut cosmic=initialize();
    host::with(|s|{s.snapshot.held=None;s.events.push(input::Event::KeyDown("arsenal".into()));});
    cosmic.tick(1);assert!(cosmic.menu);
    host::with(|s|{
        let draws=s.screen.as_ref().expect("Z must open the menu");
        for key in KEYS {assert!(draws.iter().any(|d|matches!(d,ui::Draw::Item((_,model,_,_)) if model==&format!("cosmic:{key}"))),"missing {key} from wheel");}
    });
    assert_eq!(sector(0.,0.),None);assert_eq!(sector(0.,100.),None);
    for i in 0..6 {
        let a=-std::f32::consts::FRAC_PI_2+i as f32*std::f32::consts::TAU/6.;
        assert_eq!(sector(a.cos()*60.,a.sin()*60.),Some(i));
    }
    for (i,key) in KEYS.iter().enumerate(){command(&mut cosmic,&format!("planet {key}"));assert_eq!(cosmic.planet,i);}
    assert!(cosmic.command("cosmic","planet pluto").is_err());
}

#[test]
fn loaded_terrain_survey_leads_to_real_air_and_lining_block_edits() {
    let _host=IsolatedHost::new();let mut cosmic=initialize();
    command(&mut cosmic,"planet saturn");command(&mut cosmic,"fire");
    assert!(host::with(|s|s.out.iter().any(|o|matches!(o,host::Output::Surface{columns,..} if !columns.is_empty()))));
    assert!(!cosmic.strike.as_ref().unwrap().ready);
    assert!(host::with(|s|s.post_source.is_none()),"do not start cinematic before survey reply");
    let pending=cosmic.strike.as_ref().unwrap();
    host::with(|s|s.surface.push(world::SurfaceHeights{tag:pending.tag.wrapping_add(1),heights:vec![Some(71);pending.columns.len()]}));
    cosmic.tick(0);
    assert!(!cosmic.strike.as_ref().unwrap().ready,"a stale reply for another strike cannot unlock this strike");
    let mut observed=Vec::new();
    for tick in 1..=420 {
        observed.extend(answer_world());cosmic.tick(tick);
        if cosmic.strike.as_ref().is_some_and(|s|s.tick>=345) && cosmic.edits.is_empty(){break;}
    }
    observed.extend(answer_world());
    let edits:Vec<_>=observed.iter().filter_map(|o|match o{host::Output::Edit{edit}=>Some(edit),_=>None}).collect();
    assert!(!edits.is_empty(),"a real terrain-on strike must emit native block edits");
    assert!(edits.iter().any(|e|e.runs.iter().any(|r|e.palette[r.block as usize]=="minecraft:air"&&r.height>1)),"crater must remove actual world blocks");
    assert!(edits.iter().any(|e|e.palette.iter().any(|b|b=="minecraft:blue_ice"||b=="minecraft:packed_ice")),"Saturn must leave its distinct material");
    assert!(edits.iter().any(|e|e.runs.iter().any(|r|r.only.is_some()&&r.height==1)),"flying debris must remove guarded samples of actual source blocks");
    host::with(|s|{
        let (words,_)=s.post_data.as_ref().expect("real captured block geometry must be uploaded to the renderer");
        assert!(words.len()>4&&words[1]>0,"a loaded stone/grass world must produce actual block debris");
    });
    assert!(edits.iter().flat_map(|e|&e.runs).all(|r|r.y>=terrain::LOWEST_FLOOR && r.y+r.height as i32-1<=terrain::HIGHEST_BLOCK));
    assert!(!observed.iter().any(|o|matches!(o,host::Output::Commands{commands} if commands.iter().any(|c|c.starts_with("fill ")))),"terrain uses bounded direct edits, not silent failed fill commands");
}

#[test]
fn stop_and_world_exit_remove_the_post_effect_and_queued_edits() {
    let _host=IsolatedHost::new();let mut cosmic=initialize();
    command(&mut cosmic,"terrain off");command(&mut cosmic,"fire");
    assert!(host::with(|s|s.post_source.is_some()));
    command(&mut cosmic,"stop");assert!(cosmic.strike.is_none()&&cosmic.edits.is_empty());
    host::with(|s|assert!(s.post_source.is_none()&&s.post_params.is_none()&&s.panel.is_none()));
    command(&mut cosmic,"fire");host::with(|s|s.snapshot.player=None);cosmic.frame(0.016);
    assert!(cosmic.strike.is_none());assert!(host::with(|s|s.post_source.is_none()));
}

#[test]
fn absent_terrain_never_starts_cinematic_or_silently_fires_without_crater() {
    let _host=IsolatedHost::new();let mut cosmic=initialize();command(&mut cosmic,"fire");
    // Deliberately never answer the read: a distant unloaded chunk must be refused.
    for tick in 0..125 {cosmic.tick(tick);}
    assert!(cosmic.strike.is_none());assert!(host::with(|s|s.post_source.is_none()));
    host::with(|s|assert!(!s.out.iter().any(|o|matches!(o,host::Output::Edit{..}))));
}
