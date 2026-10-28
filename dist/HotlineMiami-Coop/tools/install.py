"""Hotline Miami co-op installer: builds HotlineMiami_Coop.exe from the user's own game copy and
writes hmcoop.txt. Speaks Russian on a Russian Windows, English otherwise (--lang ru|en to choose).

usage: install.py [game folder] [--uninstall] [--lang ru|en]
       install.py [game folder] --batch --name N --peer IP[,IP...] --skin S [--room CODE] [--chance 50]
                  [--windowed] [--log FILE]
         (no questions: used by the exe installer; exit code 0 ok, 1 build failed, 2 game not found,
          3 mod files missing)
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# The release archive has the build tools next to this file. A "Code -> Download ZIP" of the GitHub
# repository has them in <repo>/tools (and the GML in <repo>/gml) instead: use those.
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
TOOLS = HERE if os.path.isfile(os.path.join(HERE, 'build_mod.py')) else os.path.join(REPO, 'tools')
sys.path.insert(0, TOOLS)
STEAM = os.path.join(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)'), 'Steam')
MOD_FILES = ('HotlineMiami_Coop.exe', 'hmnet.dll', 'hmnet_log.txt', 'hmbgm.dll')
SKINS = ['jacket', 'beard', 'richter', 'corey', 'jake', 'son', 'writer', 'pardo', 'henchman', 'random']
OPTS = ('--name', '--peer', '--skin', '--room', '--chance', '--log', '--lang')   # options that take a value
BATCH = '--batch' in sys.argv


def opt(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return default


def windows_is_russian():
    try:
        import ctypes
        return ctypes.windll.kernel32.GetUserDefaultUILanguage() & 0x3FF == 0x19
    except Exception:
        return False


RU = (opt('--lang') or ('ru' if windows_is_russian() else 'en')) == 'ru'


def T(ru, en):
    return ru if RU else en


def positional():
    out, skip = [], False
    for a in sys.argv[1:]:
        if skip:
            skip = False
        elif a in OPTS:
            skip = True
        elif not a.startswith('--'):
            out.append(a)
    return out


def steam_roots():
    """Steam install folders: from the registry first, then the usual places."""
    roots = []
    try:
        import winreg
        for hive, key, val in ((winreg.HKEY_CURRENT_USER, r'Software\Valve\Steam', 'SteamPath'),
                               (winreg.HKEY_LOCAL_MACHINE, r'SOFTWARE\WOW6432Node\Valve\Steam', 'InstallPath'),
                               (winreg.HKEY_LOCAL_MACHINE, r'SOFTWARE\Valve\Steam', 'InstallPath')):
            try:
                with winreg.OpenKey(hive, key) as k:
                    roots.append(os.path.normpath(winreg.QueryValueEx(k, val)[0]))
            except OSError:
                pass
    except ImportError:
        pass
    roots.append(STEAM)
    return roots


def steam_common_dirs(extra_game=None):
    """steamapps/common of every Steam library we can find."""
    out = []
    if extra_game:  # the library HM1 lives in is the most likely place for HM2 too
        out.append(os.path.dirname(os.path.normpath(extra_game)))
    for root in steam_roots():
        out.append(os.path.join(root, 'steamapps', 'common'))
        try:
            for line in open(os.path.join(root, 'steamapps', 'libraryfolders.vdf'), encoding='utf-8', errors='replace'):
                parts = line.strip().split('"')
                if len(parts) >= 4 and parts[1].lower() == 'path':
                    out.append(os.path.join(parts[3].replace('\\\\', '\\'), 'steamapps', 'common'))
        except OSError:
            pass
    # common library folders on other drives
    for d in 'CDEFGH':
        for sub in (r'SteamLibrary\steamapps\common', r'Steam\steamapps\common', r'Games\Steam\steamapps\common'):
            out.append(f'{d}:\\{sub}')
    seen, uniq = set(), []
    for p in out:
        k = os.path.normcase(os.path.normpath(p))
        if k not in seen and os.path.isdir(p):
            seen.add(k)
            uniq.append(p)
    return uniq


def find_game(arg):
    candidates = [arg] if arg else [os.path.join(c, 'hotline_miami') for c in steam_common_dirs()]
    for c in candidates:
        if c and os.path.isfile(os.path.join(c, 'HotlineMiami_Original.exe')):
            return c
    if BATCH:
        print(T('Не нашёл Hotline Miami (нет HotlineMiami_Original.exe): ',
                'Hotline Miami not found (no HotlineMiami_Original.exe): ') + (arg or T('папки Steam', 'Steam folders')))
        sys.exit(2)
    print(T('Не нашёл Hotline Miami автоматически.', 'Could not find Hotline Miami automatically.'))
    print(T('Steam: ПКМ по игре -> Управление -> Просмотреть локальные файлы, скопируй путь.',
            'Steam: right-click the game -> Manage -> Browse local files, copy the path.'))
    while True:
        p = input(T('Путь к папке hotline_miami: ', 'Path to the hotline_miami folder: ')).strip().strip('"')
        if os.path.isfile(os.path.join(p, 'HotlineMiami_Original.exe')):
            return p
        print(T('В этой папке нет HotlineMiami_Original.exe, попробуй ещё раз.',
                'No HotlineMiami_Original.exe in that folder, try again.'))


WAD = 'hlm2_data_desktop.wad'


def _wad_in(folder):
    p = os.path.join(folder, WAD)
    return p if os.path.isfile(p) else None


def find_hm2(game):
    for c in steam_common_dirs(game):
        # usual folder name first, then anything in the library that holds the wad
        w = _wad_in(os.path.join(c, 'Hotline Miami 2'))
        if w:
            return w
        try:
            for name in os.listdir(c):
                if 'hotline' in name.lower():
                    w = _wad_in(os.path.join(c, name))
                    if w:
                        return w
        except OSError:
            pass
    if BATCH:
        return None
    print(T('Hotline Miami 2 не найдена автоматически.', 'Hotline Miami 2 not found automatically.'))
    print(T('Если она установлена: Steam -> ПКМ по Hotline Miami 2 -> Управление -> Просмотреть локальные файлы,',
            'If you have it: Steam -> right-click Hotline Miami 2 -> Manage -> Browse local files,'))
    print(T('скопируй путь из адресной строки. Enter без пути - продолжить без персонажей HM2.',
            'copy the path from the address bar. Enter alone - go on without the HM2 characters.'))
    while True:
        p = input(T('Путь к папке Hotline Miami 2: ', 'Path to the Hotline Miami 2 folder: ')).strip().strip('"')
        if not p:
            return None
        if os.path.isfile(p) and p.lower().endswith('.wad'):
            return p
        w = _wad_in(p)
        if w:
            return w
        print(T(f'В этой папке нет {WAD}, попробуй ещё раз (или Enter - пропустить).',
                f'No {WAD} in that folder, try again (or Enter to skip).'))


def read_cfg(path):
    cfg = {}
    try:
        for line in open(path, encoding='utf-8', errors='replace'):
            if '=' in line:
                k, v = line.strip().split('=', 1)
                cfg[k] = v
    except OSError:
        pass
    return cfg


def write_cfg(path, old, peer, name, skin, chance, room):
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(f'port={old.get("port", "7777")}\npeer={peer}\nname={name}\nskin={skin}\nbeard_chance={chance}\n'
                f'room={room}\nsteam={old.get("steam", "1")}\n')


def ask(prompt, default):
    v = input(f'{prompt} [{default}]: ').strip()
    return v or default


def clean_room(room):
    return re.sub(r'[^A-Za-z0-9_\-]', '', room or '')[:24]


SKIN_MENU = [('Джекет', 'Jacket'), ('Борода', 'Beard'), ('Рихтер (крыса)', 'Richter (rat)'),
             ('Кори (зебра)', 'Corey (zebra)'), ('Джейк (змея)', 'Jake (snake)'), ('Сын', 'Son'),
             ('Писатель (Эван)', 'Writer (Evan)'), ('Пардо (детектив)', 'Pardo (detective)'),
             ('Хенчмен', 'Henchman'),
             ('случайно: с шансом - один из персонажей HM2, иначе Джекет',
              'random: by chance one of the HM2 characters, otherwise Jacket')]


def configure(cfg_path, has_beard):
    old = read_cfg(cfg_path)
    print()
    print(T('--- Настройка ---', '--- Settings ---'))
    while True:
        name = ask(T('Твоё имя (латиницей, до 15 символов)', 'Your name (latin letters, up to 15)'), old.get('name', 'PLAYER'))
        name = re.sub(r'[^A-Za-z0-9_\-. ]', '', name)[:15]
        if name:
            break
        print(T('Только латинские буквы и цифры.', 'Latin letters and digits only.'))
    print(T('IP других игроков (до трёх, через запятую): в Radmin VPN это адрес вида 26.x.x.x рядом с ником.',
            "Other players' IPs (up to three, comma separated): in Radmin VPN it is the 26.x.x.x address next to the nick."))
    print(T('Достаточно вписать одного - остальных игра найдёт сама.',
            'One is enough - the game finds the others.'))
    while True:
        peer = ask(T('IP других игроков', "Other players' IPs"), old.get('peer', '') or '26.')
        parts = [x.strip() for x in re.split(r'[,; ]+', peer) if x.strip()]
        if parts and all(re.fullmatch(r'[\w.\-]+(:\d+)?', x) and x != '26.' for x in parts):
            break
        print(T('Не похоже на адрес, попробуй ещё раз (например 26.12.34.56 или 26.1.1.1, 26.2.2.2).',
                "That doesn't look like an address, try again (e.g. 26.12.34.56 or 26.1.1.1, 26.2.2.2)."))
    peer = ','.join(x if ':' in x else x + ':7777' for x in parts[:3])
    print(T('Код комнаты - одно слово, одинаковое у всех игроков (латиница и цифры). С ним к вам не подключится',
            'Room code - one word, the same for every player (latin letters and digits). With it nobody who'))
    print(T('посторонний, который не знает код. Enter без кода - без защиты.',
            "doesn't know the code can join you. Enter alone - no protection."))
    room = clean_room(ask(T('Код комнаты', 'Room code'), old.get('room', '')))
    skin, chance = 'jacket', old.get('beard_chance', '50')
    if has_beard:
        print(T('Персонаж (его можно сменить и в главном меню игры клавишей C):',
                'Character (can also be changed in the game menu with C):'))
        for i, (ru, en) in enumerate(SKIN_MENU):
            hm2 = '' if i in (0, len(SKIN_MENU) - 1) else T('   (спрайты из HM2)', '   (HM2 sprites)')
            print(f'  {i + 1:2} - {T(ru, en)}{hm2}')
        cur = str(SKINS.index(old.get('skin', 'jacket')) + 1) if old.get('skin') in SKINS else '1'
        c = ask(T('Выбор', 'Choice'), cur)
        skin = SKINS[int(c) - 1] if c.isdigit() and 1 <= int(c) <= len(SKINS) else 'jacket'
        if skin == 'random':
            chance = ask(T('Шанс персонажа HM2 в процентах', 'Chance of an HM2 character, percent'), chance)
    else:
        print(T('Hotline Miami 2 не найдена - персонажи из HM2 недоступны, будешь Джекетом.',
                'Hotline Miami 2 not found - no HM2 characters, you play as Jacket.'))
    write_cfg(cfg_path, old, peer, name, skin, chance, room)
    print(T(f'Сохранено в {cfg_path}', f'Saved to {cfg_path}'))


def clean_peer(peer):
    parts = [x.strip() for x in re.split(r'[,; ]+', peer or '') if x.strip()]
    parts = [x for x in parts if re.fullmatch(r'[\w.\-]+(:\d+)?', x)]
    return ','.join(x if ':' in x else x + ':7777' for x in parts[:3])


def configure_batch(cfg_path, has_beard):
    old = read_cfg(cfg_path)
    name = re.sub(r'[^A-Za-z0-9_\-. ]', '', opt('--name', old.get('name', 'PLAYER')))[:15] or 'PLAYER'
    peer = clean_peer(opt('--peer', old.get('peer', '')))
    room = clean_room(opt('--room', old.get('room', '')))
    skin = opt('--skin', old.get('skin', 'jacket')).lower()
    if skin not in SKINS:
        skin = 'jacket'
    if not has_beard and skin != 'jacket':
        print(T('Hotline Miami 2 не найдена - персонажи из HM2 недоступны, будешь Джекетом.',
                'Hotline Miami 2 not found - no HM2 characters, you play as Jacket.'))
    chance = opt('--chance', old.get('beard_chance', '50'))
    write_cfg(cfg_path, old, peer, name, skin, chance, room)
    print(T('Сохранено в', 'Saved to') + f' {cfg_path}: name={name} peer={peer} skin={skin} room={room or "-"}')


def missing_files():
    need = [os.path.join(TOOLS, f) for f in ('build_mod.py', 'gm7.py', 'hm2_extract.py', 'beard_recolor.py', 'fix_bgm.py')]
    need.append(os.path.join(ROOT, 'hmnet.dll'))
    return [f for f in need if not os.path.isfile(f)]


def main():
    log = opt('--log')
    if log:
        sys.stdout = sys.stderr = open(log, 'w', encoding='utf-8-sig', buffering=1)  # BOM: the exe installer reads it
    if '--uninstall' not in sys.argv and missing_files():
        print(T('Не хватает файлов мода:', 'Mod files are missing:'))
        for f in missing_files():
            print('  ' + f)
        print()
        print(T('Скорее всего скачаны исходники ("Code -> Download ZIP") или архив распакован не целиком.',
                'Probably the source code was downloaded ("Code -> Download ZIP") or the archive was not fully unpacked.'))
        print(T('Скачай готовый архив HotlineMiami-Coop-vX.zip из раздела Releases на GitHub,',
                'Download the ready archive HotlineMiami-Coop-vX.zip from Releases on GitHub,'))
        print(T('распакуй его ЦЕЛИКОМ и запусти install.bat оттуда.', 'unpack ALL of it and run install.bat from there.'))
        return 3
    args = positional()
    game = find_game(args[0] if args else None)
    print(T('Игра: ', 'Game: ') + game)

    if '--uninstall' in sys.argv:
        for f in MOD_FILES:
            p = os.path.join(game, f)
            if os.path.exists(p):
                os.remove(p)
        # steam_appid.txt only if the installer made it (the marker says so)
        mark = os.path.join(game, 'hmcoop_appid.txt')
        if os.path.exists(mark):
            os.remove(mark)
            if os.path.exists(os.path.join(game, 'steam_appid.txt')):
                os.remove(os.path.join(game, 'steam_appid.txt'))
        print(T('Мод удалён (hmcoop.txt оставлен). Файлы оригинальной игры не менялись.',
                'Mod removed (hmcoop.txt kept). The original game files were not changed.'))
        return 0

    hm2 = find_hm2(game)
    print('Hotline Miami 2: ' + (hm2 or T('не найдена (персонажи HM2 будут недоступны)', 'not found (no HM2 characters)')))
    ans = ('y' if '--windowed' in sys.argv else 'n') if BATCH else input(
        T('Запускать в окне, а не на весь экран? (y/N): ', 'Run in a window instead of fullscreen? (y/N): ')).strip().lower()
    cmd = [sys.executable, os.path.join(TOOLS, 'build_mod.py'),
           os.path.join(game, 'HotlineMiami_Original.exe'), os.path.join(game, 'HotlineMiami_Coop.exe')]
    cmd += ['--hm2', hm2] if hm2 else ['--no-hm2']
    if ans in ('y', 'yes', 'д', 'да'):
        cmd.append('--windowed')
    print(T('Собираю HotlineMiami_Coop.exe из твоей копии игры...', 'Building HotlineMiami_Coop.exe from your copy of the game...'),
          flush=True)
    if subprocess.call(cmd, stdout=sys.stdout, stderr=sys.stderr) != 0:
        print(T('Ошибка сборки. Оригинальные файлы игры не тронуты.', 'Build failed. The original game files are untouched.'))
        return 1
    shutil.copyfile(os.path.join(ROOT, 'hmnet.dll'), os.path.join(game, 'hmnet.dll'))
    # the game's bgm.dll breaks whenever Windows loads it at another address (duplicated relocations);
    # the co-op exe loads this fixed copy instead, the original file stays untouched
    from fix_bgm import fix_bgm
    fix_bgm(os.path.join(game, 'bgm.dll'), os.path.join(game, 'hmbgm.dll'))
    # play through Steam: steam_api.dll starts outside Steam only with the game's AppID next to the exe
    appid = os.path.join(game, 'steam_appid.txt')
    if os.path.isfile(os.path.join(game, 'steam_api.dll')) and not os.path.isfile(appid):
        with open(appid, 'w') as f:
            f.write('219150')
        with open(os.path.join(game, 'hmcoop_appid.txt'), 'w') as f:
            f.write('steam_appid.txt was made by the co-op installer; the uninstaller removes both.\n')
    cfg = os.path.join(game, 'hmcoop.txt')
    if BATCH:
        configure_batch(cfg, bool(hm2))
    else:
        configure(cfg, bool(hm2))
    print()
    print(T('Готово. В папке игры: HotlineMiami_Coop.exe, hmnet.dll, hmcoop.txt',
            'Done. In the game folder: HotlineMiami_Coop.exe, hmnet.dll, hmcoop.txt'))
    print(T('Запуск: ', 'Start: ') + os.path.join(game, 'HotlineMiami_Coop.exe'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
