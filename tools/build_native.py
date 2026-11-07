"""Regenerate the native engine and pack the unpacked native mod at repository root."""
from pathlib import Path
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    engine = ROOT / 'mixins/cosmic/engine'
    (engine / 'src').mkdir(parents=True, exist_ok=True)
    (engine / 'data').mkdir(exist_ok=True)
    source = (ROOT / 'mod/src/lib.rs').read_text(encoding='utf-8')
    source = source.replace('include_str!("../shaders/cosmic.wgsl")', 'include_str!("../data/cosmic.wgsl")')
    prelude = '#![allow(hidden_glob_reexports)]\nextern crate self as horizon_mod_sdk;\npub mod horizon_sdk;\npub use horizon_sdk::*;\n'
    (engine / 'src/lib.rs').write_text(prelude + source, encoding='utf-8')
    shutil.copy2(ROOT / 'mod/shaders/cosmic.wgsl', engine / 'data/cosmic.wgsl')
    # Content-only manifest: native code is supplied by the mixin engine, not mod.wasm.
    (ROOT / 'horizon-mod.toml').write_text('''id = "cosmic"
name = "Cosmic Cataclysm"
version = "0.1.1"
description = "Six planetary strikes with cinematic space graphics."
authors = ["Cosmic Cataclysm"]
api = "0.2"
side = "both"
capabilities = ["registries"]
''', encoding='utf-8')
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
