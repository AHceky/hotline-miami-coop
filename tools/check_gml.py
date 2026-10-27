"""Check the mod's GML against the game: every obj* / spr* / scr* name it uses must exist
(GameMaker 7 only finds out when that line runs: "Unknown variable" in the middle of a level).

usage: py -3 tools/check_gml.py <HotlineMiami_Original.exe>
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gm7 import Game  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
GML = os.path.join(HERE, '..', 'gml')
# made by the installer, not files in gml/
MADE = {'scrCoopSkinInit', 'objCoopNet', 'objCoopShot'}


def main(exe):
    g = Game(exe)
    known = set(MADE)
    known |= {o.name.decode() for o in g.objects if o}
    known |= {s.name.decode() for s in g.scripts if s}
    known |= set(g.sprite_names())
    known |= {n[:-4] for n in os.listdir(GML) if n.startswith('scr')}
    for kind in ('sounds', 'rooms', 'backgrounds', 'fonts'):
        for n in getattr(g, kind + '_names', lambda: [])():
            known.add(n)
    bad = 0
    for f in sorted(os.listdir(GML)):
        text = open(os.path.join(GML, f), encoding='latin-1').read()
        code = re.sub(r'//[^\n]*|"[^"\n]*"', '', text)
        for name in sorted(set(re.findall(r'\b((?:obj|spr|scr)[A-Z]\w*)', code))):
            if name not in known:
                print(f'{f}: unknown {name}')
                bad += 1
    print('ok' if not bad else f'{bad} unknown names')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
