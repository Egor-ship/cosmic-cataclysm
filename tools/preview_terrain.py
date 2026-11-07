"""Draw actual Rust terrain::plan output as six synthetic voxel geometry previews.

Requires Pillow; Rust is only used to emit the real plan, never a Python recreation.
python tools/preview_terrain.py [--rustc PATH] [--out previews/v2/terrain-scars.jpg]
"""
from pathlib import Path
import argparse
import csv
import io
import json
import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['MERCURY / IRON RAIN', 'VENUS / ACID CYCLONE', 'MARS / RED TEMPEST',
         'JUPITER / THUNDER COLOSSUS', 'SATURN / RINGFALL', 'NEPTUNE / SINGULARITY TIDE']
SUBTITLES = ['Terraced impact bowl + nine molten fissures', 'Three spiral channels in an asymmetric basin',
             'Five-lobed tectonic scar + raised broken rim', 'Deep central well + branching fulgurite ridges',
             'Three real concentric trenches + central obelisk', 'Deep stepped basin + six ice spires']
COLORS = {'obsidian': (40,35,51), 'magma_block': (241,100,28), 'polished_basalt': (77,80,85),
          'green_stained_glass': (89,157,55), 'yellow_terracotta': (181,150,62), 'packed_mud': (107,95,61),
          'red_sandstone': (182,91,52), 'terracotta': (144,73,54), 'granite': (160,120,110),
          'cyan_stained_glass': (76,190,201), 'polished_blackstone': (56,56,66), 'blackstone': (43,44,56),
          'blue_ice': (86,157,218), 'calcite': (218,217,205), 'packed_ice': (143,191,226),
          'polished_deepslate': (57,66,79), 'ground': (129,132,116)}


def rust_compiler(explicit):
    if explicit:
        return Path(explicit).resolve()
    found = shutil.which('rustc')
    if found:
        return Path(found)
    # Horizon brings a portable compiler. Reading this location changes no launcher settings.
    directory = Path(os.environ.get('APPDATA', '')) / 'horizon-launcher/rust'
    candidates = sorted(directory.glob('*/bin/rustc.exe'))
    if candidates:
        return candidates[-1]
    raise RuntimeError('Rust compiler not found. Pass --rustc PATH.')


def geometry(rustc, scratch):
    scratch.mkdir(parents=True, exist_ok=True)
    src = scratch / 'emit-terrain.rs'
    executable = scratch / ('emit-terrain.exe' if os.name == 'nt' else 'emit-terrain')
    module = (ROOT / 'mod/src/terrain.rs').resolve().as_posix()
    src.write_text('''#[path = ''' + json.dumps(module) + '''] mod terrain;
fn main() {
    for planet in 0..6 {
        for c in terrain::plan(planet, [0,70,0]) {
            let (a,b,material)=c.feature.unwrap_or((c.floor,c.floor,"-"));
            println!("{},{},{},{},{},{},{},{},{}",planet,c.x,c.z,c.floor,c.top,c.lining,a,b,material);
        }
    }
}
''', encoding='utf-8')
    environment = os.environ.copy()
    paths = [str(rustc.parent)]
    gcc = rustc.parent.parent / 'mingw64/bin/gcc.exe'
    command = [str(rustc), '--edition=2024', '-Awarnings', '-O', str(src), '-o', str(executable)]
    if gcc.is_file():
        paths.append(str(gcc.parent))
        command.extend(['-C', 'linker=' + str(gcc)])
    environment['PATH'] = os.pathsep.join(paths + [environment.get('PATH', '')])
    subprocess.run(command, env=environment, check=True)
    output = subprocess.check_output([str(executable)], env=environment, text=True)
    (scratch/'terrain-columns.csv').write_text(output, encoding='utf-8')
    planets = [[] for _ in range(6)]
    for row in csv.reader(io.StringIO(output)):
        planet,x,z,floor,top,lining,start,end,material = row
        planets[int(planet)].append((int(x),int(z),int(floor),int(top),lining,int(start),int(end),material))
    assert all(planets), 'Rust terrain::plan returned an empty world.'
    return planets


def shade(color, factor):
    return tuple(max(0,min(255,round(c*factor))) for c in color)


def font(size, bold=False):
    for path in [Path('C:/Windows/Fonts')/('consolab.ttf' if bold else 'consola.ttf'),
                 Path('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf')]:
        if path.is_file():
            return ImageFont.truetype(str(path),size)
    return ImageFont.load_default()


def render_card(planet, columns, width=900, height=560):
    image=Image.new('RGB',(width,height),(12,18,29)); draw=ImageDraw.Draw(image)
    draw.text((24,16),NAMES[planet],font=font(22,True),fill=(225,235,249))
    draw.text((24,47),SUBTITLES[planet],font=font(14),fill=(147,169,195))
    cells={(x,z):(floor,lining,end if material!='-' else floor,material)
           for x,z,floor,top,lining,start,end,material in columns}
    edge=80; scale=2.55
    def project(x,y,z):
        return (width/2+(x-z)*scale,252+(x+z)*scale*0.45-(y-70)*scale*0.88)
    def height_at(x,z):
        c=cells.get((x,z)); return c[2] if c else 70
    def rgb(material): return COLORS.get(material.removeprefix('minecraft:'),(120,120,120))
    # Painter order: far north-west columns first; only surfaces facing the camera are shown.
    coords=sorted(((x,z) for x in range(-edge,edge+1) for z in range(-edge,edge+1)),key=lambda p:p[0]+p[1])
    for x,z in coords:
        data=cells.get((x,z)); y=height_at(x,z)
        material=(data[3] if data[3]!='-' else data[1]) if data else 'ground'
        color=rgb(material)
        # A fixed coordinate dither gives tiny block variation, never changes geometry.
        color=shade(color,0.94+((x*31+z*17)&15)/130.)
        for dx,dz,factor in [(1,0,0.65),(0,1,0.79)]:
            below=height_at(x+dx,z+dz)
            if y<=below: continue
            if dx:
                points=[project(x+.5,y,z-.5),project(x+.5,y,z+.5),project(x+.5,below,z+.5),project(x+.5,below,z-.5)]
            else:
                points=[project(x-.5,y,z+.5),project(x+.5,y,z+.5),project(x+.5,below,z+.5),project(x-.5,below,z+.5)]
            wall=color if data and data[3]!='-' else (92,89,85)
            draw.polygon(points,fill=shade(wall,factor))
            # Real block-sized horizontal seams help communicate actual vertical depth.
            for h in range(below+1,y,3):
                if dx: line=[project(x+.5,h,z-.5),project(x+.5,h,z+.5)]
                else: line=[project(x-.5,h,z+.5),project(x+.5,h,z+.5)]
                draw.line(line,fill=shade(wall,factor*0.76),width=1)
        top=[project(x-.5,y,z-.5),project(x+.5,y,z-.5),project(x+.5,y,z+.5),project(x-.5,y,z+.5)]
        draw.polygon(top,fill=color)
    minimum=min(c[2] for c in columns); highest=max(max(c[2],c[6]) for c in columns)
    features=sum(c[7]!='-' for c in columns)
    draw.rectangle((18,height-66,width-18,height-16),fill=(15,23,37))
    draw.text((28,height-59),f'{len(columns):,} Rust columns | depth {70-minimum} blocks | peak {highest-70:+} blocks',font=font(15),fill=(180,205,231))
    draw.text((28,height-36),f'{features:,} columns contain raised solid geometry',font=font(13),fill=(113,146,178))
    return image


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rustc',type=Path)
    parser.add_argument('--out',type=Path,default=ROOT/'previews/v2/terrain-scars.jpg')
    parser.add_argument('--work',type=Path,default=ROOT.parents[1]/'work/terrain-preview')
    args=parser.parse_args()
    plans=geometry(rust_compiler(args.rustc),args.work.resolve())
    result=Image.new('RGB',(1800,1780),(7,11,19));draw=ImageDraw.Draw(result)
    draw.text((28,19),'GEOMETRY PREVIEW / NOT GAME FOOTAGE',font=font(25,True),fill=(225,235,249))
    draw.text((28,53),'Actual terrain::plan output at [0,70,0] on flat synthetic ground. Original untextured block colors.',font=font(15),fill=(140,164,191))
    for planet,columns in enumerate(plans):
        result.paste(render_card(planet,columns),(planet%2*900,100+planet//2*560))
    args.out.parent.mkdir(parents=True,exist_ok=True);result.save(args.out,quality=95)
    print(args.out)


if __name__=='__main__': main()
