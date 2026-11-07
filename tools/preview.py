"""Render the actual mod shader on a synthetic world. pip install wgpu numpy pillow.
The included Horizon post prelude is from Orbital Laser (Stink-O, MIT),
see PRELUDE-LICENSE.txt. No game assets or Minecraft installation are required.
"""
from pathlib import Path
import argparse
import math
import numpy as np
from PIL import Image, ImageDraw
import wgpu
from wgpu.utils import get_default_device

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Neptune']

def uniforms(width, height, planet, seconds):
    eye = np.array([110., 60., 160.], dtype=np.float32)
    forward = -eye / np.linalg.norm(eye)
    right = np.cross(forward, [0., 1., 0.]); right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    inverse_view = np.eye(4, dtype=np.float32)
    inverse_view[:3, :3] = np.stack([right, up, -forward], axis=1)
    view = inverse_view.T
    near, far, fov = .1, 10000., 1.1
    cot = 1. / math.tan(fov / 2.)
    proj = np.zeros((4, 4), dtype=np.float32)
    proj[0, 0] = cot / (width / height); proj[1, 1] = cot
    proj[2, 2] = near / (far-near); proj[2, 3] = near*far/(far-near)
    proj[3, 2] = -1.
    vectors = [*eye, 0, width, height, 1/width, 1/height,
               seconds, 0, .25, 0, -.6, .8, .2, 0,
               .12, .24, .38, 0, .14, .2, .3, 0,
               near, far, 512, fov,
               0, 0, 0, seconds, planet, 1, 0, 1, *([0]*8),
               0, 0, 0, 0]
    parts = [view.T.ravel(), proj.T.ravel(), inverse_view.T.ravel(),
             np.linalg.inv(proj).T.ravel(), vectors,
             view.T.ravel(), proj.T.ravel(), [*eye, 0]]
    data = np.concatenate(parts).astype(np.float32).tobytes()
    assert len(data) == 592
    return data

SYNTHETIC = '''
struct SceneOut { @location(0) color: vec4<f32>, @builtin(frag_depth) depth:f32, }
@fragment fn synthetic(v:StageIn)->SceneOut {
    let rd=normalize(world_offset(v.uv,0.00001));
    let eye=frame.camera_position.xyz;
    var out:SceneOut;
    out.color=vec4<f32>(mix(vec3<f32>(0.05,0.13,0.25),vec3<f32>(0.28,0.42,0.53),1.0-v.uv.y),1);
    out.depth=0;
    if(rd.y<0.0){
        let distance=-eye.y/rd.y; let p=eye+rd*distance;
        let clip=frame.projection*frame.view*vec4<f32>(rd*distance,1);
        out.depth=clip.z/clip.w;
        let checker=f32((i32(floor(p.x/8.0))+i32(floor(p.z/8.0))) & 1);
        let grid=select(0.82,1.0,fract(p.x)>0.025 && fract(p.z)>0.025);
        let rock=vec3<f32>(0.17,0.23,0.10)*(0.8+checker*0.2)*grid;
        let fog=1.0-exp(-distance*0.0012);
        out.color=vec4<f32>(mix(rock,vec3<f32>(0.28,0.40,0.45),fog),1);
    }
    return out;
}
'''

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--width', type=int, default=768)
    ap.add_argument('--height', type=int, default=432)
    ap.add_argument('--out', type=Path, default=ROOT/'previews')
    args=ap.parse_args()
    width,height=args.width,args.height
    device=get_default_device()
    print(dict(device.adapter.info))
    prelude=(ROOT/'tools/horizon-prelude.wgsl').read_text(encoding='utf-8-sig')
    shader=(ROOT/'mod/shaders/cosmic.wgsl').read_text(encoding='utf-8-sig')
    module=device.create_shader_module(code=prelude+shader)
    scene_module=device.create_shader_module(code=prelude+SYNTHETIC)
    pipeline=device.create_render_pipeline(layout='auto',vertex={'module':module,'entry_point':'horizon_mod_post_vertex'},fragment={'module':module,'entry_point':'fs_main','targets':[{'format':'rgba8unorm'}]})
    scene_pipeline=device.create_render_pipeline(layout='auto',vertex={'module':scene_module,'entry_point':'horizon_mod_post_vertex'},fragment={'module':scene_module,'entry_point':'synthetic','targets':[{'format':'rgba8unorm'}]},depth_stencil={'format':'depth32float','depth_write_enabled':True,'depth_compare':'always'})
    usage=wgpu.TextureUsage
    scene=device.create_texture(size=(width,height,1),format='rgba8unorm',usage=usage.RENDER_ATTACHMENT|usage.TEXTURE_BINDING)
    depth=device.create_texture(size=(width,height,1),format='depth32float',usage=usage.RENDER_ATTACHMENT|usage.TEXTURE_BINDING)
    result=device.create_texture(size=(width,height,1),format='rgba8unorm',usage=usage.RENDER_ATTACHMENT|usage.COPY_SRC)
    uniform=device.create_buffer(size=592,usage=wgpu.BufferUsage.UNIFORM|wgpu.BufferUsage.COPY_DST)
    data=device.create_buffer_with_data(data=bytes(4),usage=wgpu.BufferUsage.STORAGE)
    linear=device.create_sampler(min_filter='linear',mag_filter='linear')
    nearest=device.create_sampler(min_filter='nearest',mag_filter='nearest')
    scene_bind=device.create_bind_group(layout=scene_pipeline.get_bind_group_layout(0),entries=[{'binding':4,'resource':{'buffer':uniform}}])
    bind=device.create_bind_group(layout=pipeline.get_bind_group_layout(0),entries=[{'binding':0,'resource':scene.create_view()},{'binding':1,'resource':depth.create_view()},{'binding':2,'resource':linear},{'binding':3,'resource':nearest},{'binding':4,'resource':{'buffer':uniform}}])
    args.out.mkdir(parents=True,exist_ok=True)
    contact=Image.new('RGB',(width*3,(height+32)*6),'#070c16')
    draw=ImageDraw.Draw(contact)
    for planet,name in enumerate(NAMES):
        for column,seconds in enumerate([6.0,11.0,18.8]):
            device.queue.write_buffer(uniform,0,uniforms(width,height,planet,seconds))
            encoder=device.create_command_encoder()
            attachment={'view':scene.create_view(),'load_op':'clear','store_op':'store','clear_value':(0,0,0,1)}
            render=encoder.begin_render_pass(color_attachments=[attachment],depth_stencil_attachment={'view':depth.create_view(),'depth_clear_value':0.,'depth_load_op':'clear','depth_store_op':'store'})
            render.set_pipeline(scene_pipeline);render.set_bind_group(0,scene_bind);render.draw(3);render.end()
            render=encoder.begin_render_pass(color_attachments=[{'view':result.create_view(),'load_op':'clear','store_op':'store','clear_value':(0,0,0,1)}])
            render.set_pipeline(pipeline);render.set_bind_group(0,bind);render.draw(3);render.end()
            device.queue.submit([encoder.finish()])
            stride=((width*4+255)//256)*256
            pixels=device.queue.read_texture({'texture':result,'mip_level':0,'origin':(0,0,0)},{'offset':0,'bytes_per_row':stride,'rows_per_image':height},(width,height,1))
            rgb=np.frombuffer(pixels,np.uint8).reshape(height,stride)[:,:width*4].reshape(height,width,4)
            image=Image.fromarray(rgb,'RGBA').convert('RGB')
            image.save(args.out/f'{name.lower()}-{seconds:04.1f}.png')
            contact.paste(image,(column*width,planet*(height+32)+32))
            draw.text((column*width+12,planet*(height+32)+8),f'{name.upper()} / {seconds:.1f}s',fill='#dce9ff')
            print(name,seconds)
    contact.save(args.out/'contact-sheet.jpg',quality=92)
    print(args.out/'contact-sheet.jpg')

if __name__=='__main__': main()
