"""Build a release from the sources: hmnet.dll (zig), the protocol test, dist/HotlineMiami-Coop (tools and
GML copied fresh), the zip and the exe installer (Inno Setup).

usage: py -3 tools/make_release.py [--game <HotlineMiami_Original.exe>] [--no-installer]

The version comes from MOD_VERSION in net/hmnet.c (80 -> "0.8"). With --game the GML is checked
against that game (tools/check_gml.py) first.
"""
import glob
import hashlib
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
DIST = os.path.join(ROOT, 'dist', 'HotlineMiami-Coop')
TOOLS = ('beard_recolor.py', 'build_mod.py', 'fix_bgm.py', 'gm7.py', 'hm2_extract.py')
BUILD = os.path.join(os.environ['USERPROFILE'], 'hm-tools', 'build')
ISCC = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Inno Setup 6', 'ISCC.exe')


def version():
    v = int(re.search(r'#define MOD_VERSION (\d+)', open(os.path.join(ROOT, 'net', 'hmnet.c')).read()).group(1))
    return f'{v // 100}.{v % 100:02d}' if v % 10 else f'{v // 100}.{v % 100 // 10}'


def zig():
    z = glob.glob(os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Microsoft', 'WinGet', 'Packages', 'zig.zig_*',
                               'zig-*', 'zig.exe'))
    return z[0] if z else shutil.which('zig')


def run(cmd, **kw):
    print('>', ' '.join(cmd))
    subprocess.run(cmd, check=True, **kw)


def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def main(argv):
    ver = version()
    print(f'release v{ver}')
    if '--game' in argv:
        run([sys.executable, os.path.join(ROOT, 'tools', 'check_gml.py'), argv[argv.index('--game') + 1]])

    # the DLL, from net/hmnet.c, and its protocol test
    z = zig()
    assert z, 'zig not found'
    os.makedirs(BUILD, exist_ok=True)
    for f in ('hmnet.c', 'test_hmnet.c'):
        shutil.copy(os.path.join(ROOT, 'net', f), BUILD)
    run([z, 'cc', '-target', 'x86-windows-gnu', '-shared', '-O2', '-s', '-Wall', '-o', 'hmnet.dll', 'hmnet.c',
         '-lws2_32'], cwd=BUILD)
    run([z, 'cc', '-target', 'x86-windows-gnu', '-O2', '-o', 'test_hmnet.exe', 'test_hmnet.c', '-lws2_32'], cwd=BUILD)
    run([os.path.join(BUILD, 'test_hmnet.exe'), BUILD, '20'], cwd=BUILD)

    # dist folder: tools and GML replaced by fresh copies of the sources
    shutil.copy(os.path.join(BUILD, 'hmnet.dll'), DIST)
    for f in glob.glob(os.path.join(DIST, 'gml', '*.gml')):
        os.remove(f)
    for f in glob.glob(os.path.join(ROOT, 'gml', '*.gml')):
        shutil.copy(f, os.path.join(DIST, 'gml'))
    for f in TOOLS:
        shutil.copy(os.path.join(ROOT, 'tools', f), os.path.join(DIST, 'tools'))
    shutil.copy(os.path.join(ROOT, 'net', 'hmnet.c'), os.path.join(DIST, 'tools'))
    with open(os.path.join(DIST, 'tools', 'SHA256.txt'), 'w', newline='\r\n') as f:
        f.write(f'hmnet.dll {sha(os.path.join(DIST, "hmnet.dll"))}\n'
                f'(built from tools/hmnet.c {sha(os.path.join(DIST, "tools", "hmnet.c"))} with '
                f'"zig cc -target x86-windows-gnu -shared -O2 -s -o hmnet.dll hmnet.c -lws2_32")\n')
    shutil.rmtree(os.path.join(DIST, 'tools', '__pycache__'), ignore_errors=True)

    # zip
    out = os.path.join(ROOT, 'dist', f'HotlineMiami-Coop-v{ver}.zip')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
        for dirpath, dirs, files in os.walk(DIST):
            dirs[:] = [d for d in dirs if d != '__pycache__']
            for f in files:
                if f in ('hmnet_log.txt',):
                    continue
                p = os.path.join(dirpath, f)
                zf.write(p, os.path.relpath(p, os.path.dirname(DIST)))
    print(f'wrote {out} ({os.path.getsize(out) // 1024} KB)')

    # installer
    if '--no-installer' not in argv:
        iss = os.path.join(ROOT, 'setup', 'HotlineMiamiCoop.iss')
        text = open(iss, encoding='utf-8-sig').read()
        text2 = re.sub(r'#define AppVer "[^"]*"', f'#define AppVer "{ver}"', text)
        if text2 != text:
            open(iss, 'w', encoding='utf-8-sig').write(text2)
        assert os.path.isfile(ISCC), 'Inno Setup not found: ' + ISCC
        run([ISCC, '/Q', iss])
        print('wrote', os.path.join(ROOT, 'dist', f'HotlineMiami-Coop-Setup-v{ver}.exe'))


if __name__ == '__main__':
    main(sys.argv[1:])
