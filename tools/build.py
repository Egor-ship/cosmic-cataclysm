"""Build the Horizon component and package it with original content. No auto-install."""
import argparse
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--component', type=Path, help='Use an existing component .wasm instead of compiling')
    parser.add_argument('--standalone', action='store_true', help='Build with ordinary cargo and the included component encoder')
    parser.add_argument('--cargo-horizon-mod', type=Path, help='Path to cargo-horizon-mod executable')
    args = parser.parse_args()
    mod = ROOT / 'mod'
    if args.standalone:
        subprocess.run(['cargo', 'build', '--manifest-path', str(mod / 'Cargo.toml'), '--release', '--target', 'wasm32-unknown-unknown'], check=True)
        core = mod / 'target' / 'wasm32-unknown-unknown' / 'release' / 'cosmic_cataclysm.wasm'
        output = core.with_name('cosmic.component.wasm')
        subprocess.run(['cargo', 'run', '--release', '--manifest-path', str(ROOT / 'tools/componentize/Cargo.toml'), '--', str(core), str(output)], check=True)
        component = output.read_bytes()
    elif args.component:
        component = args.component.resolve().read_bytes()
    else:
        command = ([str(args.cargo_horizon_mod.resolve()), 'horizon-mod', 'build']
                   if args.cargo_horizon_mod else ['cargo', 'horizon-mod', 'build'])
        try:
            subprocess.run(command, cwd=mod, check=True)
        except FileNotFoundError:
            parser.error('Rust/cargo-horizon-mod not found. Install the fork toolchain or use --component FILE.wasm.')
        package = mod / 'target' / 'horizon-mod' / 'cosmic.hmod'
        if not package.is_file():
            candidates = list((mod / 'target' / 'horizon-mod').glob('*.hmod'))
            if len(candidates) != 1:
                parser.error(f'Expected built package {package}; found {len(candidates)} alternatives')
            package = candidates[0]
        with zipfile.ZipFile(package) as archive:
            component = archive.read('mod.wasm')
    if not component.startswith(b'\0asm\x0d\0\x01\0'):
        parser.error('Expected a WebAssembly component, not a core module')
    dest = ROOT / 'dist' / 'cosmic'
    # The only removed directory is this builder's fixed generated package directory.
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    (dest / 'mod.wasm').write_bytes(component)
    shutil.copy2(mod / 'horizon-mod.toml', dest / 'horizon-mod.toml')
    for name in ['assets', 'data']:
        shutil.copytree(mod / name, dest / name)
    package = ROOT / 'dist' / 'cosmic.hmod'
    with zipfile.ZipFile(package, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(dest.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(dest).as_posix())
    print(f'Built {dest}\nPackaged {package} ({package.stat().st_size:,} bytes)')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        sys.exit(f'Build failed: {error}')
