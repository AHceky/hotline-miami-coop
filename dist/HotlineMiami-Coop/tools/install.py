"""Hotline Miami co-op installer: builds HotlineMiami_Coop.exe from the user's own game copy and
writes hmcoop.txt.

usage: install.py [game folder] [--uninstall] [--no-notepad]
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(HERE)
STEAM = os.path.join(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)'), 'Steam')
MOD_FILES = ('HotlineMiami_Coop.exe', 'hmnet.dll', 'hmnet_log.txt', 'hmbgm.dll')


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
    print('Не нашёл Hotline Miami автоматически.')
    print('Steam: ПКМ по игре -> Управление -> Просмотреть локальные файлы, скопируй путь.')
    while True:
        p = input('Путь к папке hotline_miami: ').strip().strip('"')
        if os.path.isfile(os.path.join(p, 'HotlineMiami_Original.exe')):
            return p
        print('В этой папке нет HotlineMiami_Original.exe, попробуй ещё раз.')


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
    print('Hotline Miami 2 не найдена автоматически.')
    print('Если она установлена: Steam -> ПКМ по Hotline Miami 2 -> Управление -> Просмотреть локальные файлы,')
    print('скопируй путь из адресной строки. Enter без пути - продолжить без скина Бороды.')
    while True:
        p = input('Путь к папке Hotline Miami 2: ').strip().strip('"')
        if not p:
            return None
        if os.path.isfile(p) and p.lower().endswith('.wad'):
            return p
        w = _wad_in(p)
        if w:
            return w
        print(f'В этой папке нет {WAD}, попробуй ещё раз (или Enter - пропустить).')


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


def ask(prompt, default):
    v = input(f'{prompt} [{default}]: ').strip()
    return v or default


def configure(cfg_path, has_beard):
    old = read_cfg(cfg_path)
    print()
    print('--- Настройка ---')
    while True:
        name = ask('Твоё имя (латиницей, до 15 символов)', old.get('name', 'PLAYER'))
        name = re.sub(r'[^A-Za-z0-9_\-. ]', '', name)[:15]
        if name:
            break
        print('Только латинские буквы и цифры.')
    print('IP напарника: в Radmin VPN это адрес вида 26.x.x.x рядом с его ником.')
    while True:
        peer = ask('IP напарника', old.get('peer', '') or '26.')
        if re.fullmatch(r'[\w.\-]+(:\d+)?', peer) and peer not in ('26.', ''):
            break
        print('Не похоже на адрес, попробуй ещё раз (например 26.12.34.56).')
    if ':' not in peer:
        peer += ':7777'
    skin, chance = 'jacket', old.get('beard_chance', '50')
    if has_beard:
        skins = ['jacket', 'beard', 'richter', 'corey', 'jake', 'son', 'writer', 'pardo', 'henchman', 'random']
        print('Скин (персонажа можно сменить и в главном меню игры клавишей C):')
        print('  1 - Джекет')
        print('  2 - Борода      (спрайты из HM2)')
        print('  3 - Рихтер      (крыса, спрайты из HM2)')
        print('  4 - Кори        (зебра, спрайты из HM2)')
        print('  5 - Джейк       (змея, спрайты из HM2)')
        print('  6 - Сын         (спрайты из HM2)')
        print('  7 - Писатель    (Эван, спрайты из HM2)')
        print('  8 - Пардо       (детектив, спрайты из HM2)')
        print('  9 - Хенчмен     (спрайты из HM2)')
        print(' 10 - случайно: с шансом - один из персонажей HM2, иначе Джекет')
        cur = str(skins.index(old.get('skin', 'jacket')) + 1) if old.get('skin') in skins else '1'
        c = ask('Выбор', cur)
        skin = skins[int(c) - 1] if c.isdigit() and 1 <= int(c) <= len(skins) else 'jacket'
        if skin == 'random':
            chance = ask('Шанс персонажа HM2 в процентах', chance)
    else:
        print('Hotline Miami 2 не найдена - скины из HM2 недоступны, будешь Джекетом.')
    with open(cfg_path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(f'port={old.get("port", "7777")}\npeer={peer}\nname={name}\nskin={skin}\nbeard_chance={chance}\n')
    print(f'Сохранено в {cfg_path}')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    game = find_game(args[0] if args else None)
    print(f'Игра: {game}')

    if '--uninstall' in sys.argv:
        for f in MOD_FILES:
            p = os.path.join(game, f)
            if os.path.exists(p):
                os.remove(p)
        print('Мод удалён (hmcoop.txt оставлен). Оригинальная игра не менялась.')
        return 0

    hm2 = find_hm2(game)
    print(f'Hotline Miami 2: {hm2 or "не найдена (скин Бороды будет недоступен)"}')
    ans = input('Запускать в окне, а не на весь экран? (y/N): ').strip().lower()
    cmd = [sys.executable, os.path.join(HERE, 'build_mod.py'),
           os.path.join(game, 'HotlineMiami_Original.exe'), os.path.join(game, 'HotlineMiami_Coop.exe')]
    cmd += ['--hm2', hm2] if hm2 else ['--no-hm2']
    if ans in ('y', 'yes', 'д', 'да'):
        cmd.append('--windowed')
    print('Собираю HotlineMiami_Coop.exe из твоей копии игры...', flush=True)
    if subprocess.call(cmd) != 0:
        print('Ошибка сборки. Оригинальные файлы игры не тронуты.')
        return 1
    shutil.copyfile(os.path.join(ROOT, 'hmnet.dll'), os.path.join(game, 'hmnet.dll'))
    # the game's bgm.dll breaks whenever Windows loads it at another address (duplicated relocations);
    # the co-op exe loads this fixed copy instead, the original file stays untouched
    from fix_bgm import fix_bgm
    fix_bgm(os.path.join(game, 'bgm.dll'), os.path.join(game, 'hmbgm.dll'))
    cfg = os.path.join(game, 'hmcoop.txt')
    configure(cfg, bool(hm2))
    print()
    print('Готово. В папке игры: HotlineMiami_Coop.exe, hmnet.dll, hmcoop.txt')
    print(f'Запуск: {os.path.join(game, "HotlineMiami_Coop.exe")}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
