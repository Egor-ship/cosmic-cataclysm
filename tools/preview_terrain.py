"""Draw actual Rust terrain::plan output as six synthetic voxel geometry previews.

Requires Pillow; Rust is only used to emit the real plan, never a Python recreation.
python tools/preview_terrain.py [--rustc PATH] [--out previews/v3/terrain-scars.jpg]
"""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['MERCURY / IRON RAIN', 'VENUS / ACID CYCLONE', 'MARS / RED TEMPEST',
         'JUPITER / THUNDER COLOSSUS', 'SATURN / RINGFALL', 'NEPTUNE / SINGULARITY TIDE']
SUBTITLES = ['Molten lance ridge + layered impact terraces', 'Sulfur spiral shelves + ochre / calcite strata',
             'Five tectonic wedges + branched red fractures', 'Layered storm well + central fulgurite spire',
             'Three ring trenches + stepped central island', 'Frozen terraced abyss + six leaning ice blades']
COLORS = {'obsidian': (40,35,51), 'magma_block': (241,100,28), 'polished_basalt': (77,80,85),
          'green_stained_glass': (89,157,55), 'yellow_terracotta': (181,150,62), 'packed_mud': (107,95,61),
          'red_sandstone': (182,91,52), 'terracotta': (144,73,54), 'granite': (160,120,110),
          'cyan_stained_glass': (76,190,201), 'polished_blackstone': (56,56,66), 'blackstone': (43,44,56),
          'blue_ice': (86,157,218), 'calcite': (218,217,205), 'packed_ice': (143,191,226),
          'polished_deepslate': (57,66,79), 'ground': (92,127,66),
          'stone': (113,115,118), 'dirt': (117,83,57), 'grass_block': (92,127,66),
          'basalt': (72,73,78), 'deepslate': (57,58,63), 'tuff': (106,111,102),
          'iron_ore': (151,132,114), 'deepslate_iron_ore': (123,102,91),
          'lava': (255,117,15), 'gold_block': (234,193,51), 'raw_gold_block': (215,169,49),
          'gold_ore': (165,149,95), 'deepslate_gold_ore': (128,111,62),
          'sandstone': (210,195,141), 'smooth_sandstone': (215,201,149),
          'yellow_concrete': (241,175,22), 'yellow_stained_glass': (230,205,62),
          'lime_stained_glass': (149,190,57), 'honey_block': (231,158,34),
          'copper_block': (181,102,75), 'raw_copper_block': (150,106,72),
          'oxidized_copper': (76,151,122), 'oxidized_cut_copper': (77,151,122),
          'cut_copper': (180,100,74), 'exposed_copper': (161,125,96),
          'orange_terracotta': (162,84,38), 'red_terracotta': (143,61,47),
          'brown_terracotta': (101,66,46), 'coarse_dirt': (113,81,54),
          'red_sand': (188,103,33), 'end_stone': (218,221,161),
          'amethyst_block': (147,104,190), 'budding_amethyst': (133,96,176),
          'quartz_block': (233,230,222), 'diorite': (191,191,185),
          'snow_block': (234,242,246), 'cyan_terracotta': (87,92,92),
          'dark_prismarine': (48,86,74), 'prismarine': (99,160,143),
          'sea_lantern': (189,222,214), 'glowstone': (205,166,82),
          'crying_obsidian': (66,35,92), 'light_blue_stained_glass': (98,164,206),
          'blue_stained_glass': (51,68,154), 'ice': (128,174,231),
          'ochre_froglight': (236,219,154)}


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
            let mut runs=vec![format!("[{}, {}, \\\"{}\\\"]",c.floor,c.floor,c.lining)];
            if material!="-" {runs.push(format!("[{}, {}, \\\"{}\\\"]",a,b,material));}
            for (low,high,block) in c.solids {runs.push(format!("[{}, {}, \\\"{}\\\"]",low,high,block));}
            println!("[{}, {}, {}, {}, [{}]]",planet,c.x,c.z,c.floor,runs.join(","));
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
    (scratch/'terrain-columns.jsonl').write_text(output, encoding='utf-8')
    planets = [[] for _ in range(6)]
    for line in output.splitlines():
        planet,x,z,floor,runs = json.loads(line)
        planets[planet].append((x,z,floor,runs))
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


def exposed_faces(columns):
    """Apply Rust runs in order to a flat stone world, then expose actual cube faces.

    Byte columns keep voxel memory bounded; no hidden geometry is invented by the preview.
    Material changes and overhanging run gaps survive the projection.
    """
    materials = ['air', 'stone', 'dirt', 'grass_block']
    for _, _, _, runs in columns:
        for _, _, material in runs:
            material = material.removeprefix('minecraft:')
            if material not in materials:
                materials.append(material)
    unknown = set(materials[1:]) - COLORS.keys()
    if unknown:
        raise ValueError(f'Add real material colors for {sorted(unknown)}')
    minimum = min(c[2] for c in columns)
    highest = max(high for _, _, _, runs in columns for _, high, _ in runs)
    bottom = min(minimum - 3, min(low for _, _, _, runs in columns for low, _, _ in runs), 64)
    ceiling = max(highest, 70) + 1
    edge = max(max(abs(x), abs(z)) for x, z, _, _ in columns) + 5
    height = ceiling - bottom + 1
    cells = {}
    base = bytes([1]) * max(0, 68-bottom) + bytes([2, 2, 3])
    for x in range(-edge, edge+1):
        for z in range(-edge, edge+1):
            data = bytearray(height)
            data[:len(base)] = base
            cells[x,z] = data
    for x,z,floor,runs in columns:
        data = cells[x,z]
        data[floor+1-bottom:] = bytes(ceiling-floor)
        for low,high,material in runs:
            block = materials.index(material.removeprefix('minecraft:'))
            data[low-bottom:high+1-bottom] = bytes([block]) * (high-low+1)
    empty = bytes(height)
    faces = []
    for (x,z),data in cells.items():
        east = cells.get((x+1,z),empty)
        south = cells.get((x,z+1),empty)
        for yi,block in enumerate(data):
            if not block:
                continue
            y = yi+bottom
            # Faces at the synthetic preview's square boundary are omitted.
            if x < edge and not east[yi]:
                faces.append((x,z,y,0,block))
            if z < edge and not south[yi]:
                faces.append((x,z,y,1,block))
            if yi+1 == height or not data[yi+1]:
                faces.append((x,z,y,2,block))
    # Dot product with view direction: handles staggered and suspended solids.
    faces.sort(key=lambda f: f[0]+f[1]+f[2]*1.5+(.5 if f[3]<2 else .75))
    return faces, materials, minimum, highest, edge


def render_card(planet, columns, width=1500, height=980):
    faces,materials,minimum,highest,edge = exposed_faces(columns)
    image = Image.new('RGB',(width,height),(12,18,29))
    draw = ImageDraw.Draw(image)
    draw.text((28,18),NAMES[planet],font=font(28,True),fill=(225,235,249))
    draw.text((28,58),SUBTITLES[planet],font=font(19),fill=(147,169,195))
    # Fit the real geometry in the frame without clipping the low abyss or high peaks.
    projected_y = [(x+z)*.75-(y-70) for x,z,y,_,_ in faces]
    low,high = min(projected_y)-2,max(projected_y)+2
    scale = min((width-90)/(4*edge+2),(height-215)/(high-low))
    middle_y = (low+high)/2
    def project(x,y,z):
        return (width/2+(x-z)*scale,
                (height+20)/2+((x+z)*.75-(y-70)-middle_y)*scale)
    for x,z,y,side,block in faces:
        color = COLORS[materials[block]]
        color = shade(color, .95+((x*31+z*17+y*7)&15)/160.)
        if side == 0:
            points = [project(x+.5,y-.5,z-.5),project(x+.5,y-.5,z+.5),
                      project(x+.5,y+.5,z+.5),project(x+.5,y+.5,z-.5)]
            color = shade(color,.66)
        elif side == 1:
            points = [project(x-.5,y-.5,z+.5),project(x+.5,y-.5,z+.5),
                      project(x+.5,y+.5,z+.5),project(x-.5,y+.5,z+.5)]
            color = shade(color,.80)
        else:
            points = [project(x-.5,y+.5,z-.5),project(x+.5,y+.5,z-.5),
                      project(x+.5,y+.5,z+.5),project(x-.5,y+.5,z+.5)]
        draw.polygon(points,fill=color)
    draw.rectangle((18,height-74,width-18,height-14),fill=(15,23,37))
    draw.text((28,height-66),f'{len(columns):,} real Rust columns | depth {70-minimum} | peak {highest-70:+} blocks | {len(materials)-1} materials',font=font(18),fill=(180,205,231))
    draw.text((28,height-40),'GEOMETRY PREVIEW / FLAT TEST GROUND / NOT GAME FOOTAGE',font=font(16),fill=(113,146,178))
    return image


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rustc',type=Path)
    parser.add_argument('--out',type=Path,default=ROOT/'previews/v3/terrain-scars.jpg')
    parser.add_argument('--work',type=Path,default=ROOT.parents[1]/'work/terrain-preview')
    args=parser.parse_args()
    plans=geometry(rust_compiler(args.rustc),args.work.resolve())
    result=Image.new('RGB',(1800,1780),(7,11,19));draw=ImageDraw.Draw(result)
    draw.text((28,19),'GEOMETRY PREVIEW / NOT GAME FOOTAGE',font=font(25,True),fill=(225,235,249))
    draw.text((28,53),'Actual terrain::plan output at [0,70,0] on flat synthetic ground. Original untextured block colors.',font=font(15),fill=(140,164,191))
    args.out.parent.mkdir(parents=True,exist_ok=True)
    for planet,columns in enumerate(plans):
        card=render_card(planet,columns)
        name=NAMES[planet].split(' / ')[0].lower()
        card.save(args.out.parent/f'{planet+1:02}-{name}.png')
        result.paste(card.resize((900,560),Image.Resampling.LANCZOS),(planet%2*900,100+planet//2*560))
    result.save(args.out,quality=95)
    print(args.out)


if __name__=='__main__': main()
