"""Patch the user's own HotlineMiami_Original.exe into the co-op build.

usage: py -3 build_mod.py <HotlineMiami_Original.exe> <out.exe> [--windowed] [--hm2 <hlm2_data_desktop.wad>]

With --hm2 (or HM2 found in the default Steam folder) the Beard skin sprites are taken from the
user's own Hotline Miami 2 install and embedded; without it the Beard skin is simply unavailable.
"""
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # bundled Python ignores the script dir
from gm7 import EV_ALARM, EV_CREATE, EV_DRAW, EV_OTHER, EV_STEP, Action, Game, decode_code, encode_code

HERE = os.path.dirname(os.path.abspath(__file__))
GML = os.path.join(HERE, '..', 'gml')
DEFAULT_HM2 = os.path.join(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)'),
                           'Steam', 'steamapps', 'common', 'Hotline Miami 2', 'hlm2_data_desktop.wad')

SCRIPTS = ['scrCoopInit', 'scrCoopKeyDirect', 'scrCoopSkin', 'scrCoopSkin1', 'scrCoopTrack', 'scrCoopTag',
           'scrCoopCorpse', 'scrCoopVanDelete', 'scrCoopTrackAdd', 'scrCoopKill', 'scrCoopApplyDead',
           'scrCoopFollow', 'scrCoopPuppet', 'scrCoopWithFamily', 'scrCoopEnemies', 'scrCoopTakeAll',
           'scrCoopFollowState', 'scrCoopMorph', 'scrCoopHandoff', 'scrCoopSendEnemies', 'scrCoopAddState',
           'scrCoopUidAlive', 'scrCoopUidAliveOne', 'scrCoopTakeOne', 'scrCoopGiveOne', 'scrCoopYieldOne',
           'scrCoopMaskInit', 'scrCoopCarReady', 'scrCoopSkinMasked',
           'scrCoopDoors', 'scrCoopDialog', 'scrCoopSkinName', 'scrCoopSaveSkin', 'scrCoopSkinMenu',
           'scrCoopSkinMenuDraw', 'scrCoopDebugTalk', 'scrCoopSpawned', 'scrCoopDebugSpawn',
           'scrCoopWeaponTaken', 'scrCoopWeaponThrown', 'scrCoopReadCfg', 'scrCoopSaveCfg', 'scrCoopRevive',
           'scrCoopReviveCheck', 'scrCoopShotInit', 'scrCoopShotStep', 'scrCoopPeers']

# HM1 player sprite -> HM2 Beard ("Nicke") sprite. Beard has fewer animations than Jacket, so
# guns share the M16/shotgun/M60 sets and every melee weapon uses the knife set.
_MELEE = ('Pipe', 'Bat', 'Club', 'Crowbar', 'Axe', 'Sword', 'NightStick', 'Drill', 'Machete', 'SledgeHammer',
          'Pan', 'Pot', 'BoilingPot', 'Trophy', 'Pool', 'PoolBroke', 'Taser', 'Bag', 'Bossgun')
_SMALL_GUNS = ('M16', 'Uzi', 'SilencedUzi', 'Silencer', 'Magnum', 'Scorpion')
BEARD_MAP = {
    'sprPWalkUnarmed': 'sprNickeWalkUnarmed', 'sprPWalkUnarmed2': 'sprNickeWalkUnarmed',
    'sprPWalkHospital': 'sprNickeWalkUnarmed',
    'sprPWalkKnife': 'sprNickeWalkKnife', 'sprPAttackKnife': 'sprNickeAttackKnife',
    'sprPAttackPunch': 'sprNickeAttackKnife',
    'sprPWalkShotgun': 'sprNickeWalkShotgun', 'sprPAttackShotgun': 'sprNickeAttackShotgun',
    'sprPWalkDoubleBarrel': 'sprNickeWalkShotgun', 'sprPAttackDoubleBarrel1': 'sprNickeAttackShotgun',
    'sprPAttackDoubleBarrel2': 'sprNickeAttackShotgun',
    'sprPWalkMP5': 'sprNickeWalkHeavy', 'sprPAttackMP5': 'sprNickeAttackHeavy',
    'sprLegs': 'sprNickeLegs', 'sprLegsStairs': 'sprNickeLegs', 'sprLegsLimp': 'sprNickeLegs',
    'sprLegsHospital': 'sprNickeLegs',
    'sprPBackShotgun': 'sprNickeDeadShotgun', 'sprPFrontShotgun': 'sprNickeDeadShotgun',
    'sprPBackShotgun2': 'sprNickeDeadShotgun', 'sprPFrontShotgun2': 'sprNickeDeadShotgun',
    'sprPBackMachinegun': 'sprNickeDeadMachinegun', 'sprPFrontMachinegun': 'sprNickeDeadMachinegun',
    'sprPBackMachinegun2': 'sprNickeDeadMachinegun', 'sprPFrontMachinegun2': 'sprNickeDeadMachinegun',
    'sprPBackCut': 'sprNickeDeadCut', 'sprPBackCut2': 'sprNickeDeadCut',
    'sprPBackBlunt': 'sprNickeDeadCut', 'sprPFrontBlunt': 'sprNickeDeadCut',
    'sprPBackBlunt2': 'sprNickeDeadCut', 'sprPFrontBlunt2': 'sprNickeDeadCut',
    'sprPBackEaten': 'sprNickeDeadMachinegun', 'sprPBackEaten2': 'sprNickeDeadMachinegun',
    'sprPBackElectrified': 'sprNickeDeadMachinegun', 'sprPBackElectrified2': 'sprNickeDeadMachinegun',
    'sprPDeadExploded': 'sprNickeDeadMachinegun', 'sprPBackCar': 'sprNickeDeadMachinegun',
    'sprPBackNinjaKnife': 'sprNickeDeadCut',
    'sprPKnifeKill': 'sprNickeKillKnife', 'sprPAttackSnap': 'sprNickeKillNeck',
    'sprPAttackThroat': 'sprNickeKillNeck', 'sprPTakePhone': 'sprNickeStoreAnswerPhone',
    'sprPTakePhone2': 'sprNickeStoreAnswerPhone',
}
for _g in _SMALL_GUNS:
    BEARD_MAP['sprPWalk' + _g] = 'sprNickeWalkMachinegun'
    BEARD_MAP['sprPAttack' + _g] = 'sprNickeAttackMachinegun'
for _m in _MELEE:
    BEARD_MAP.setdefault('sprPWalk' + _m, 'sprNickeWalkKnife')
    BEARD_MAP.setdefault('sprPAttack' + _m, 'sprNickeAttackKnife')


def gml(name):
    # GameMaker wants CRLF line endings
    text = open(os.path.join(GML, name), encoding='latin-1').read()
    return text.replace('\r\n', '\n').replace('\n', '\r\n')


def crlf(text):
    return text.replace('\r\n', '\n').replace('\n', '\r\n')


def append_code(obj, etype, code, template, sub=0):
    ev = obj.event(etype, sub)
    if ev is None:
        obj.events[etype].append([sub, 400, [Action.code(code, template)]])
    else:
        ev[2].append(Action.code(code, template))


def all_code(g):
    """Yield (getter, setter) pairs for every script and execute-code action."""
    for s in g.scripts:
        if s:
            yield s.name.decode(), (lambda s=s: decode_code(s.code)), (lambda t, s=s: setattr(s, 'code', encode_code(t)))
    for o in g.objects:
        if not o:
            continue
        for lst in o.events:
            for _sub, _ver, acts in lst:
                for a in acts:
                    if a.id == 603:
                        yield o.name.decode(), (lambda a=a: a.args[0]), (lambda t, a=a: a.args.__setitem__(0, t))


def reroute_direct_keys(g):
    """keyboard_check_direct( -> scrCoopKeyDirect( in every script and code action."""
    old, new = b'keyboard_check_direct(', b'scrCoopKeyDirect('
    n = 0
    for _name, get, put in all_code(g):
        t = get()
        if old in t:
            n += t.count(old)
            put(t.replace(old, new))
    print(f'rerouted {n} keyboard_check_direct calls')


def player_object_names(g):
    names = {o.name.decode(): o for o in g.objects if o}
    parent_of = {o.name.decode(): (g.objects[o.parent].name.decode() if o.parent >= 0 else None)
                 for o in g.objects if o}
    out = set()
    for n in names:
        p = n
        while p:
            if p == 'objPlayer':
                out.add(n)
                break
            p = parent_of.get(p)
    return out


def skin_player_drawing(g):
    """Route the player's own sprite/leg drawing through the skin lookup."""
    targets = player_object_names(g) | {'objPlayerDead', 'scrDrawPlayer'}
    reps = [(b'draw_sprite_ext(sprite_index,', b'draw_sprite_ext(scrCoopSkin1(sprite_index),'),
            (b'draw_sprite_ext(legsprite,', b'draw_sprite_ext(scrCoopSkin1(legsprite),')]
    n = 0
    for name, get, put in all_code(g):
        if name not in targets:
            continue
        t = get()
        t2 = t
        for a, b in reps:
            t2 = t2.replace(a, b)
        if t2 != t:
            n += 1
            put(t2)
    # Richter and Corey wear their own masks: no HM1 mask on top
    i, s = g.script('scrDrawMask')
    s.code = encode_code(b'if variable_global_exists("coop_skin") {if !scrCoopSkinMasked(global.coop_skin) exit}'
                         + bytes((13, 10)) + decode_code(s.code))
    print(f'skinned drawing in {n} code blocks')


def car_waits_for_partner(g):
    """The level-end car drives off only when both players sit in it (scrCoopCarReady)."""
    old = b'if image_index<12 image_index+=0.2 else {'
    new = b'if image_index<12 image_index+=0.2 else if scrCoopCarReady() {'
    n = 0
    for name, get, put in all_code(g):
        if name == 'objPlayerCarEnter':
            t = get()
            if old in t:
                n += t.count(old)
                put(t.replace(old, new))
    assert n == 4, n
    print(f'car waits for the partner ({n} exits)')


def tag_spawned_enemies(g):
    """Enemies the game creates at runtime (train doors, SWAT spawn and van, the dumpster hobo) get a
    co-op identity from their spawner (scrCoopSpawned), the same in both games."""
    pat = re.compile(rb'(my_id=instance_create\([^;\r\n]*?,obj(?:EnemyMelee|Swat|Hobo)\))')
    spawners = ('objSubwayDoor', 'objSwatSpawn', 'objSwatVan', 'objDumpster')
    n = 0
    for name, get, put in all_code(g):
        if name in spawners:
            t = get()
            t2, k = pat.subn(rb'\1 scrCoopSpawned(my_id)', t)
            if k:
                n += k
                put(t2)
    assert n == 8, n
    print(f'spawned enemies get shared identities ({n} spawn points)')


def sync_weapons(g):
    """Weapons: a pickup removes the partner's copy (scrCoopWeaponTaken, event 9); a throw / drop flies on
    the partner's side too (scrCoopWeaponThrown, event 10) as a coop_ghost objWeaponThrow that knocks
    nobody out there and lands as a normal objWeapon."""
    n = 0
    for name, get, put in all_code(g):
        t = get()
        t2 = t
        if name in ('scrPlayerPickUp', 'scrPlayerPickUp2'):
            t2 = t2.replace(b'sound_play(sndPickupWeapon)', b'sound_play(sndPickupWeapon) scrCoopWeaponTaken()')
        if name == 'scrPlayerPickUp':
            # cases 0/1 set image_index last; the throwable case (lastweapon-27) is left alone
            t2 = re.sub(rb'my_id\.image_index=lastweapon(\r?\n)', rb'my_id.image_index=lastweapon scrCoopWeaponThrown(my_id)\1', t2)
        if name == 'scrPlayerPickUp2':
            t2 = t2.replace(b'my_id.ammo=lastammo', b'my_id.ammo=lastammo scrCoopWeaponThrown(my_id)')
        if name == 'objWeaponThrow':
            t2 = t2.replace(b'if speed>2.5 {', b'if speed>2.5 and !variable_local_exists("coop_ghost") {')
        if t2 != t:
            n += t2.count(b'scrCoopWeapon') - t.count(b'scrCoopWeapon') + t2.count(b'coop_ghost') - t.count(b'coop_ghost')
            put(t2)
    assert n == 6, n
    print(f'weapon pickups / throws synced ({n} hooks)')


def descendants(g, root):
    names = [o.name.decode() if o else None for o in g.objects]
    out = []
    for i, o in enumerate(g.objects):
        p = i
        while p >= 0 and g.objects[p]:
            if names[p] == root:
                out.append(o)
                break
            p = g.objects[p].parent
    return out


def guard_enemy_ai(g):
    """Puppet enemies (simulated by the partner) must not run their own AI: guard every code block of
    their step, alarm and animation-end events. Collisions stay live so local bullets still kill them."""
    guard = b'if scrCoopPuppet() exit' + bytes((13, 10))
    objs = descendants(g, 'objEnemy') + [g.obj('objEHideM16')[1], g.obj('objESubwayStatic')[1]]
    n = 0
    for o in objs:
        for et, subs in ((EV_STEP, None), (EV_ALARM, None), (EV_OTHER, (7,))):
            for sub, _ver, acts in o.events[et]:
                if subs is not None and sub not in subs:
                    continue
                for a in acts:
                    if a.id == 603:
                        a.args[0] = guard + a.args[0]
                        n += 1
    print(f'enemy AI guarded in {len(objs)} objects ({n} code blocks)')


def use_fixed_bgm(g):
    """Load the music DLL from hmbgm.dll (made by the installer) instead of bgm.dll.

    The game's bgm.dll lists every base relocation twice, so it only works at its preferred base
    0x6D740000; when Windows' ASLR puts a system DLL there (winspool.drv was seen), it is relocated
    twice and fails to load ("Error defining an external function", then a crash in bgm.dll).
    hmbgm.dll is the user's own bgm.dll with the relocation directory size halved."""
    bs = bytes([92])
    old, new = bs + b'bgm.dll"', bs + b'hmbgm.dll"'
    n = 0
    for _name, get, put in all_code(g):
        t = get()
        if old in t:
            n += t.count(old)
            put(t.replace(old, new))
    print(f'music DLL redirected to hmbgm.dll ({n} references)')


# Playable skins: id (field 15 / skin= in hmcoop.txt), name, HM2 sprite prefix, HM1 masks drawn on top.
# Richter and Corey wear their own masks (part of their HM2 sprites).
SKINS = [(1, 'beard', 'sprNicke', True), (2, 'richter', 'sprRat', False), (3, 'corey', 'sprZebra', False),
         (4, 'jake', 'sprCobra', True), (5, 'son', 'sprSon', True), (6, 'writer', 'sprWriter', True),
         (7, 'pardo', 'sprCop', True), (8, 'henchman', 'sprHenchman', True)]
_GUNS = {'M16': ('M16', 'Kalashnikov'), 'MP5': ('MP5', 'Uzi', 'M16'), 'Uzi': ('Uzi', 'SilencedUzi', 'MP5', 'M16'),
         'SilencedUzi': ('SilencedUzi', 'Uzi', 'M16'), 'Silencer': ('Silencer', '9mm', 'Magnum'),
         'Magnum': ('Magnum', 'Silencer', '9mm'), 'Scorpion': ('Uzi', 'Silencer', 'M16'),
         'Shotgun': ('Shotgun', 'DoubleBarrel'), 'DoubleBarrel': ('DoubleBarrel', 'Shotgun'), 'Bossgun': ('Shotgun',)}
_MELEE_ALIAS = {'Knife': ('Knife',), 'Pipe': ('Pipe',), 'Bat': ('Bat',), 'Club': ('Club', 'Bat'),
                'Axe': ('Axe', 'Club', 'Bat'), 'Sword': ('Sword', 'Machette', 'Machete', 'Knife'),
                'Machete': ('Machette', 'Machete', 'Knife'), 'Crowbar': ('Pipe',), 'NightStick': ('Stick', 'Pipe'),
                'Drill': ('Drill', 'Pipe'), 'SledgeHammer': ('Hammer', 'Club', 'Bat'), 'Taser': ('Taser', 'Stick', 'Pipe')}
_DEATHS = {'Blunt': ('DeadBlunt', 'DeadMelee'), 'Cut': ('DeadCut', 'DeadMelee'), 'NinjaKnife': ('DeadCut', 'DeadMelee'),
           'Shotgun': ('DeadShotgun', 'DeadShot'), 'Machinegun': ('DeadMachinegun', 'DeadShot'),
           'Eaten': ('DeadMachinegun', 'DeadShot'), 'Electrified': ('DeadMachinegun', 'DeadShot'),
           'Car': ('DeadMachinegun', 'DeadShot')}


def skin_map(prefix, hm2_names, hm1_names):
    """HM1 player sprite -> the HM2 character's sprite, by animation and weapon (with fallbacks)."""
    def pick(*cands):
        for c in cands:
            if prefix + c in hm2_names:
                return prefix + c
        return None
    m = {}

    def put(k, v):
        if k in hm1_names and v:
            m[k] = v
    for k in ('sprPWalkUnarmed', 'sprPWalkUnarmed2', 'sprPWalkHospital'):
        put(k, pick('WalkUnarmed', 'Walk'))
    put('sprPAttackPunch', pick('AttackPunch'))
    for k in ('sprLegs', 'sprLegsStairs', 'sprLegsLimp', 'sprLegsHospital'):
        put(k, pick('Legs'))
    for w in _MELEE + tuple(_MELEE_ALIAS) + tuple(_GUNS):
        if w in _GUNS:
            al = _GUNS[w] + ('M16', 'Shotgun', 'Uzi')
        else:
            al = _MELEE_ALIAS.get(w, ('Club', 'Bat', 'Pipe')) + ('Knife', 'Pipe', 'Bat')
        put('sprPWalk' + w, pick(*('Walk' + a for a in al)))
        put('sprPAttack' + w, pick(*('Attack' + a for a in al)))
    put('sprPAttackDoubleBarrel1', pick('AttackDoubleBarrel1', 'AttackShotgun'))
    put('sprPAttackDoubleBarrel2', pick('AttackDoubleBarrel2', 'AttackShotgun'))
    for kind, cands in _DEATHS.items():
        for side in ('Back', 'Front'):
            for suf in ('', '2'):
                put(f'sprP{side}{kind}{suf}', pick(*cands))
    put('sprPDeadExploded', pick('DeadExplosion', 'DeadExplode', 'DeadMachinegun', 'DeadShot'))
    return m


# story and boss animations (cutscenes, hospital, ledges...): not worth the memory, Jacket's own are drawn
_NO_RECOLOR = {'Ending', 'StrangleAssassin', 'HeadExplode', 'Vomit', 'ClubBoss2', 'BashBoss2', 'ClimbLedge',
               'WalkLedge', 'OpenSewer', 'ThrowMask', 'RipPoliceTape', 'WalkGirlfriend', 'HospitalHeadache', 'Kneel',
               'LeaveBag', 'KeyLockOpen', 'MaskSlip', 'MaskSlip2', 'SleepHospital', 'Stomped'}


def set_large_address_aware(path):
    """Let the 32-bit runner use up to 4 GB on 64-bit Windows: the game alone peaks near 2 GB while
    loading, the skins push it over ("Unexpected error occured when running the game")."""
    with open(path, 'r+b') as f:
        b = f.read(0x400)
        pe = struct.unpack_from('<I', b, 0x3c)[0]
        ch = struct.unpack_from('<H', b, pe + 22)[0]
        f.seek(pe + 22)
        f.write(struct.pack('<H', ch | 0x20))


def add_recolors(g, lines, skin_id, skin, mapped):
    """The HM2 characters have no ground executions with the victim baked in: the rest of Jacket's
    player-only sprites (executions, human shields, climbing...) are recoloured into the skin's palette."""
    from beard_recolor import recolor
    names = {n for n in g.sprite_names() if re.match(r'sprP[A-Z]', n) and n not in mapped
             and not n.startswith(('sprPolice', 'sprPlayer', 'sprPInspector')) and n[4:] not in _NO_RECOLOR}
    added = 0
    for name, (ox, oy, frames) in sorted(g.sprite_frames(names).items()):
        out, changed = [], False
        for w, h, px in frames:
            px, c = recolor(w, h, px, skin)
            changed |= c
            # BGRA (alpha 0 = key colour) -> RGBA for add_sprite
            rgba = bytearray(len(px))
            rgba[0::4], rgba[1::4], rgba[2::4] = px[2::4], px[1::4], px[0::4]
            rgba[3::4] = bytes(255 if a else 0 for a in px[3::4])
            out.append((w, h, bytes(rgba)))
        if not changed:
            continue
        idx = g.add_sprite('sprCoop%s%s' % (skin.capitalize(), name[4:]), out, ox, oy)
        lines.append(f'ds_map_add(global.coop_skinmap,{skin_id * 100000}+{name},{idx})')
        added += 1
    return added


def add_skins(g, hm2_wad):
    """Embed the skins' sprites; returns GML for scrCoopSkinInit. The skin map is keyed by
    skin*100000 + HM1 sprite."""
    lines = ['global.coop_skinmap=ds_map_create()', f'global.coop_nskins={len(SKINS) + 1}']
    for sid in range(len(SKINS) + 1):
        lines.append(f'global.coop_skin_ok[{sid}]={1 if sid == 0 else 0}')
        lines.append(f'global.coop_skin_mask[{sid}]=1')
    for sid, _n, _p, masks in SKINS:
        if not masks:
            lines.append(f'global.coop_skin_mask[{sid}]=0')
    if not hm2_wad or not os.path.isfile(hm2_wad):
        print('Hotline Miami 2 not found: HM2 skins disabled')
        return '\r\n'.join(lines) + '\r\n'
    import hm2_extract
    hm1_names = g.sprite_names()
    hm2_names = set(hm2_extract.sprite_index(hm2_wad))
    maps = {}
    for sid, name, prefix, _m in SKINS:
        if name == 'beard':
            maps[sid] = {k: v for k, v in BEARD_MAP.items() if k in hm1_names}
        else:
            maps[sid] = skin_map(prefix, hm2_names, hm1_names)
    wanted = sorted({v for m in maps.values() for v in m.values()})
    got = {}
    for spr in hm2_extract.extract_sprites(hm2_wad, wanted):
        if spr['name'] in wanted and spr['name'] not in got:
            frames = [(spr['w'], spr['h'], f) for f in spr['frames']]
            got[spr['name']] = g.add_sprite('sprCoop' + spr['name'][3:], frames, spr['origin_x'], spr['origin_y'])
    for sid, name, _p, _m in SKINS:
        m = {k: v for k, v in maps[sid].items() if v in got}
        if 'sprPWalkUnarmed' not in m:
            print(f'{name}: HM2 sprites not found, skin disabled')
            continue
        for src, dst in sorted(m.items()):
            lines.append(f'ds_map_add(global.coop_skinmap,{sid * 100000}+{src},{got[dst]})')
        r = add_recolors(g, lines, sid, name, m)
        lines.append(f'global.coop_skin_ok[{sid}]=1')
        print(f'{name} skin: {len(set(m.values()))} HM2 sprites, {len(m)} HM1 sprites mapped, {r} recoloured')
    return '\r\n'.join(lines) + '\r\n'


def main(src, dst, windowed=False, unmodified=False, hm2=None, debug=False):
    g = Game(src)
    if windowed:
        g.set_fullscreen(False)
    if unmodified:
        g.save(dst)
        print(f'round-trip build (no mod) -> {dst}')
        return
    # keep running (and talking to the partner) when the window is not focused
    g.set_freeze_on_lose_focus(False)
    _, player = g.obj('objPlayerMouse')
    template = player.event(EV_CREATE)[2][0]
    assert template.lib_id == 1 and template.id == 603, 'expected an execute-code action'

    reroute_direct_keys(g)
    use_fixed_bgm(g)
    skin_player_drawing(g)
    car_waits_for_partner(g)
    tag_spawned_enemies(g)
    sync_weapons(g)
    guard_enemy_ai(g)
    for name in SCRIPTS:
        g.add_script(name, gml(name + '.gml'))
    g.add_script('scrCoopSkinInit', add_skins(g, hm2 if hm2 is not None else DEFAULT_HM2))

    idx = g.add_object('objCoopNet', template, {
        (EV_CREATE, 0): gml('objCoopNet_create.gml'),
        (EV_STEP, 1): gml('objCoopNet_beginstep.gml'),
        (EV_STEP, 0): gml('objCoopNet_step.gml') + (gml('objCoopNet_debug.gml') if debug else ''),
        (EV_STEP, 2): gml('objCoopNet_endstep.gml'),
        (EV_DRAW, 0): (gml('objCoopNet_debugdraw.gml') if debug else '') + gml('objCoopNet_draw.gml'),
    }, depth=-1, visible=1, persistent=1)

    # the partner's bullets, drawn only
    g.add_object('objCoopShot', template, {
        (EV_CREATE, 0): 'scrCoopShotInit()\r\n',
        (EV_STEP, 0): 'scrCoopShotStep()\r\n',
    }, depth=-1, visible=1, persistent=0)

    for name in ('objTitle', 'objPlayerMouse'):
        append_code(g.obj(name)[1], EV_CREATE, 'scrCoopInit()', template)
    # children of objPlayer without their own draw event (execution animations etc.) inherit this
    append_code(g.obj('objPlayer')[1], EV_DRAW,
                crlf('draw_sprite_ext(scrCoopSkin1(sprite_index),image_index,x,y,image_xscale,image_yscale,'
                     'image_angle,image_blend,image_alpha)'), template)

    g.save(dst)
    set_large_address_aware(dst)
    print(f'objCoopNet = object #{idx}; wrote {dst}')


if __name__ == '__main__':
    argv = sys.argv[1:]
    hm2 = None
    if '--hm2' in argv:
        i = argv.index('--hm2')
        hm2 = argv[i + 1]
        del argv[i:i + 2]
    if '--no-hm2' in argv:
        hm2 = ''
    args = [a for a in argv if not a.startswith('--')]
    main(args[0], args[1], windowed='--windowed' in argv, unmodified='--unmodified' in argv, hm2=hm2,
         debug='--debug' in argv)
