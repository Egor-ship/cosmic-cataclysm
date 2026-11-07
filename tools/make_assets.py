"""Rebuild original textures and synthesized Ogg sounds. Python 3; soundfile for audio.

No Minecraft art or audio is included. Run from any directory.
"""
import json
import math
import random
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'mod'
ART = ROOT / 'assets' / 'cosmic'
PLANETS = [('mercury', (247, 144, 61)), ('venus', (213, 238, 77)),
           ('mars', (244, 74, 48)), ('jupiter', (171, 121, 242)),
           ('saturn', (245, 207, 136)), ('neptune', (50, 185, 255))]


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def png(path, size, pixel):
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = b''.join(b'\0' + bytes(c for x in range(size) for c in pixel(x, y)) for y in range(size))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', size, size, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def remote(x, y):
    # A faceted graphite handheld instrument, cyan screen and six illuminated keys.
    if not (16 <= x <= 47 and 5 <= y <= 59):
        if 21 <= x <= 24 and 0 <= y < 5:
            return (108, 186, 215, 255)
        return (0, 0, 0, 0)
    if min(x-16, 47-x, y-5, 59-y) < 2:
        return (86, 123, 151, 255)
    if x < 20 or x > 44:
        return (27, 38, 58, 255)
    if 21 <= x <= 42 and 10 <= y <= 29:
        if y in (10, 29) or x in (21, 42):
            return (64, 199, 230, 255)
        dx, dy = x-32, y-20
        if 28 <= dx*dx + dy*dy <= 42 or x == 32 and 16 <= y <= 24:
            return (123, 246, 255, 255)
        return (8, 30 + y//2, 53, 255)
    for i, (_, col) in enumerate(PLANETS):
        bx, by = 22 + (i % 3)*8, 35 + (i//3)*9
        if bx <= x <= bx+4 and by <= y <= by+4:
            return (*col, 255)
    if 25 <= x <= 39 and 54 <= y <= 55:
        return (70, 230, 216, 255)
    return (38 + (x+y)%3, 51 + (x+y)%3, 72 + (x+y)%3, 255)


def planet_pixel(index, color, x, y):
    dx, dy = (x-31.5)/22, (y-31.5)/22
    r2 = dx*dx+dy*dy
    ring = abs(math.sqrt(dx*dx+(dy*3.3)**2)-1.27) < .09
    if index == 4 and ring and (dy > 0 or r2 > 1):
        return (220, 197, 144, 255)
    if r2 > 1:
        return (0, 0, 0, 0)
    z = math.sqrt(1-r2)
    light = max(.16, -.48*dx-.35*dy+.7*z)
    bands = .83 + .17*math.sin(dy*18 + math.sin(dx*7)*(.7 if index > 2 else 2))
    if index == 0:
        bands *= .75+.25*math.sin(x*1.4+y*.7)**2
    if index == 2:
        bands *= .7+.3*math.sin(dx*6+dy*9)**2
    if index == 5:
        bands = .8+.2*math.sin(dy*13+dx*2)
    return (*(min(255, int(c*light*bands+12*z)) for c in color), 255)


def textures():
    png(ART/'textures/item/control.png', 64, remote)
    names = ['control']
    for i, (name, col) in enumerate(PLANETS):
        png(ART/f'textures/item/{name}.png', 64, lambda x, y, i=i, c=col: planet_pixel(i,c,x,y))
        names.append(name)
    for name in names:
        write_json(ART/f'models/item/{name}.json', {'parent':'minecraft:item/generated', 'textures':{'layer0':f'cosmic:item/{name}'}})
        write_json(ART/f'items/{name}.json', {'model':{'type':'minecraft:model','model':f'cosmic:item/{name}'}})
        write_json(ROOT/f'data/cosmic/horizon/item/{name}.json', {'template':'minecraft:spyglass','max_stack_size':1,'rarity':'epic'})
    en = {'item.cosmic.control':'Cosmic Control', **{f'item.cosmic.{n}':n.title() for n,_ in PLANETS},
          'subtitles.cosmic.charge':'Planetary core charging', 'subtitles.cosmic.launch':'Orbital projectile launched',
          'subtitles.cosmic.impact':'Planetary impact'}
    ru = {'item.cosmic.control':'Космический пульт', **dict(zip((f'item.cosmic.{n}' for n,_ in PLANETS),
          ['Меркурий','Венера','Марс','Юпитер','Сатурн','Нептун'])),
          'subtitles.cosmic.charge':'Планета накапливает энергию', 'subtitles.cosmic.launch':'Космический снаряд запущен',
          'subtitles.cosmic.impact':'Планетарный удар'}
    write_json(ART/'lang/en_us.json', en)
    write_json(ART/'lang/ru_ru.json', ru)


def sounds():
    import soundfile
    rate = 24000
    rng = random.Random(61071)
    events = {}
    for name, duration in [('charge',5), ('launch',7), ('impact',10)]:
        samples = []
        low = 0.0
        phase = 0.0
        for i in range(int(rate*duration)):
            t = i/rate
            u = t/duration
            n = rng.uniform(-1,1)
            low += .028*(n-low)
            if name == 'charge':
                phase += 2*math.pi*(45+170*u*u)/rate
                env = min(1,t*2)*min(1,(duration-t)*3)*(.2+.8*u)
                v = env*(.3*math.sin(phase)+.17*math.sin(phase*1.503)+low*1.3)
            elif name == 'launch':
                env = min(1,t*9)*math.exp(-t*.45)
                v = env*(low*3.4 + n*.12 + .18*math.sin(2*math.pi*(85*t-3*t*t)))
            else:
                env = min(1,t*80)*math.exp(-t*.55)
                v = env*(low*4.8 + .38*math.sin(2*math.pi*38*t)*math.exp(-t*2)+n*.25*math.exp(-t*5))
            v = math.tanh(v*1.4)*.78
            samples.append((v, v*.97 + low*.02))
        dest = ART/f'sounds/{name}.ogg'
        dest.parent.mkdir(parents=True, exist_ok=True)
        soundfile.write(dest, samples, rate, format='OGG', subtype='VORBIS')
        events[name] = {'sounds':[{'name':f'cosmic:{name}','attenuation_distance':512}], 'subtitle':f'subtitles.cosmic.{name}'}
    write_json(ART/'sounds.json', events)


if __name__ == '__main__':
    textures()
    sounds()
    print('Generated original Cosmic Control assets and three Ogg soundscapes.')
