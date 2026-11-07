"""Regenerate the native engine and pack the unpacked native mod at repository root."""
from pathlib import Path
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0'

def main():
    shaders = ROOT / 'mod/shaders'
    (shaders / 'cosmic.wgsl').write_text('\n'.join((shaders/name).read_text(encoding='utf-8') for name in ['common.wgsl','space.wgsl','debris.wgsl','impact.wgsl','composite.wgsl']), encoding='utf-8')
    engine = ROOT / 'mixins/cosmic/engine'
    (engine / 'src').mkdir(parents=True, exist_ok=True)
    (engine / 'data').mkdir(exist_ok=True)
    source = (ROOT / 'mod/src/lib.rs').read_text(encoding='utf-8')
    source = source.replace('include_str!("../shaders/cosmic.wgsl")', 'include_str!("../data/cosmic.wgsl")')
    prelude = '#![allow(hidden_glob_reexports)]\nextern crate self as horizon_mod_sdk;\npub mod horizon_sdk;\npub use horizon_sdk::*;\n'
    (engine / 'src/lib.rs').write_text(prelude + source, encoding='utf-8')
    shutil.copy2(ROOT / 'mod/src/terrain.rs', engine / 'src/terrain.rs')
    shutil.copy2(ROOT / 'mod/src/debris.rs', engine / 'src/debris.rs')
    tests = ROOT / 'tools/native_tests.rs'
    if tests.is_file():
        shutil.copy2(tests, engine / 'src/native_tests.rs')
        with (engine / 'src/lib.rs').open('a', encoding='utf-8') as f:
            f.write('\n#[cfg(test)]\nmod native_tests;\n')
    shutil.copy2(ROOT / 'mod/shaders/cosmic.wgsl', engine / 'data/cosmic.wgsl')
    # Content-only manifest: native code is supplied by the mixin engine, not mod.wasm.
    (ROOT / 'horizon-mod.toml').write_text('''id = "cosmic"
name = "Cosmic Cataclysm"
version = "0.2.0"
description = "Six planetary strikes with cinematic space graphics."
authors = ["Cosmic Cataclysm"]
api = "0.2"
side = "both"
capabilities = ["registries"]
''', encoding='utf-8')
    meta = json.loads((ROOT / 'horizon-native.json').read_text(encoding='utf-8'))
    meta['version'] = VERSION
    (ROOT / 'horizon-native.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')
    for manifest in [ROOT/'mixins/cosmic/horizon-mixin.toml', engine/'Cargo.toml', ROOT/'mod/Cargo.toml', ROOT/'mod/horizon-mod.toml']:
        import re
        content = manifest.read_text(encoding='utf-8')
        content = re.sub(r'version = "0\.[0-9]+\.[0-9]+"', f'version = "{VERSION}"', content, count=1)
        manifest.write_text(content, encoding='utf-8')
    glue = ROOT/'mixins/cosmic/glue.rs'
    glue.write_text(re.sub(r'const VERSION: &str = "[^"]+";', f'const VERSION: &str = "{VERSION}";', glue.read_text(encoding='utf-8')), encoding='utf-8')
    for kind in ['assets', 'data']:
        shutil.copytree(ROOT / 'mod' / kind, ROOT / kind, dirs_exist_ok=True)
    out = ROOT / 'dist/cosmic.hnmod'
    out.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for name in ['horizon-mod.toml', 'horizon-native.json']:
            z.write(ROOT/name, name)
        for name, archive in [('LICENSE', 'LICENSE'), ('NOTICE', 'NOTICE'), ('THIRD_PARTY_LICENSES.md', 'LICENSE-THIRD-PARTY')]:
            z.write(ROOT/name, 'mixins/cosmic/' + archive)
        for name in ['mixins', 'assets', 'data']:
            for p in sorted((ROOT/name).rglob('*')):
                if p.is_file() and 'target' not in p.relative_to(ROOT/name).parts and p.name != 'Cargo.lock':
                    z.write(p, p.relative_to(ROOT).as_posix())
    print(f'Native package: {out} ({out.stat().st_size:,} bytes)')

if __name__ == '__main__':
    main()
