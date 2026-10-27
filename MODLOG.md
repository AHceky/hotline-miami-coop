# Hotline Miami 1 - ghost co-op mod (MODLOG)

## Goal
Option 1 "ghost co-op": each player runs their own game; position/rotation/sprite/weapon of the
partner is streamed over UDP and drawn as a ghost in your level. Later: kill sync.

## Install facts
- Steam appid 219150, `C:\Program Files (x86)\Steam\steamapps\common\hotline_miami`
- `HotlineMiami.exe` (544 KB launcher), `HotlineGL.exe` (Abstraction C++ port, 8 MB),
  `HotlineMiami_Original.exe` (20.6 MB, **GameMaker 7.0** runner + gamedata) <- we mod this one.
- Extension DLLs called via external_define: GMXInput.dll, Steamworks.dll, AlienInMiami.dll, bgm.dll.
- Work copies/decomp outside repo: `C:\Users\RobotComp\hm-decomp`, tools in `C:\Users\RobotComp\hm-tools`.

## GM7 exe format (as found, HM 1.1 Original exe)
- No SteamStub. Delphi PE, overlay starts at 1967616.
- Header at **1980000**: magic 1234321, version 700, debug=0, settings ver 702 + raw settings dwords
  (custom load image present, zlib).
- Pas-string "D3DX8.dll" + u32 len + zlib dll.
- Then u32 len + **one zlib stream** (to EOF) = gamedata (21.2 MB inflated).
- Inflated: u32 g1, u32 g2, g1 dwords garbage, u32 **seed** (7907), g2 dwords garbage, then data at
  offset P. Data byte 0 is plain; byte i>0: `plain = rev[enc] - (abs_offset & 0xFF)` where table is
  GM6/7 seed table (a=6+seed%250, b=seed/250, 10000 swaps j=1+((i*a+b)%254)).
- Plain: pro/flag dword, game id, 16-byte guid, extensions(ver 700, count 0), sounds(ver 400, 71)...
  assets are inline (no per-asset zlib), each prefixed with u32 exists flag.
- Player object: `objPlayer`; draw script `scrDrawPlayer`.

## GM8Decompiler
- v2.2.0 fails: "unknown format" (GM7 not supported). Wrote own parser instead.

## More format facts (verified by byte-exact round trip)
- Asset sections: ext(700) sounds(400) sprites(400, sprite ver 542, frames ver 540 + zlib)
  backgrounds(400, ver 543) paths(420) scripts(400) fonts(540) timelines(500) objects(400, obj ver
  430, 11 event lists, event ver 400, action ver 440) rooms(420)... rest kept raw.
- Script code = zlib( subst_table(seed **12345**)( u32 len + text ) ). Runner: `mov edx,0x3039`
  before calling the substitution routine. Object action code (id 603) is plain text.
- Raw settings dword #22 (after 702) = freeze-on-lose-focus (HM ships with 1). #1 = fullscreen.
- Game reads keys with keyboard_check_direct (73 calls) = global async state -> background
  instance reacts to keys. Fix: reroute to scrCoopKeyDirect + io_clear in begin step when unfocused.
- Saves are written to working_directory (game folder).
- Drawing with alpha < 1 into HM's render surface makes sprites dark -> ghost drawn with alpha 1
  plus the same bm_add light circle the player draws.

## Mod (v0.1, ghost co-op)
- objCoopNet (persistent, created from objTitle/objPlayerMouse create via scrCoopInit).
- hmnet.dll: UDP, 32 doubles/packet, 60 Hz, host learns client address, hmnet_log.txt diag.
- Verified: echo-peer test, two instances on one PC (host+client) see each other, independent input.
- Not verified: fullscreen build, Steamworks=YES, two real PCs over Radmin.
- Dist: hm-coop/dist/HotlineMiami-Coop (+zip). install.bat -> tools/install.py -> build_mod.py.

## v0.2 (skins, enemy + transition sync) - verified with two instances (host Jacket, client Beard)
- Protocol HMC2: state + reliable ordered events (ids, acks, 8 per packet, session id resets on restart).
- Enemy identity: coop_uid = room-placed instance id, carried through transforms by adopting the
  nearest vanished uid (<48 px). Death = new objDeadBody/objDeadBurning within 56 px of a vanished uid.
  Event 1 (room, uid). Receiver: scrCoopKill (corpse, no score). Dead list re-applied every 10 steps
  (survives game_load), cleared in rooms without objEffector or with objEffectorHouse.
  Verified: host F9 killed 6 in rmApartment1Upstairs -> client 0 enemies, both "CHAPTER DONE".
- Transitions: objTransitioner/objTeleporter set objEffector.next/fade/nextroom + objPlayer.persistent.
  Event 2 (from, to); partner teleports to the matching arrow and triggers the same.
  Verified: host F10 Entrance->Upstairs, client followed (even from the mask menu).
- Beard = HM2 "Nicke" (Atlases/Player_Nicke). hm2_extract.py (AGAR wad, AGTEXTUREPACKER meta,
  GL/hlm2_sprites.bin origins). 16 sprites embedded via Game.add_sprite (BGRX + key colour
  00 80 40, 1 px border), 93 HM1 sprites mapped. Player draw calls wrapped in scrCoopSkin1; objPlayer
  got a draw event so default-drawn children (executions) are skinned; scrDrawMask skipped for Beard.
- GM7 gotchas: menus map the mouse from the SCREEN centre (display_mouse_get_x), so off-centre
  windows click the wrong item; GetForegroundWindow can be NULL after a click -> net_focused falls back
  to WindowFromPoint(cursor); jumping into a level straight from the menu errors (globals unset).
- Debug build (--debug): F8/F9 kill, F10 exit arrow, F11 chapter 1 (+event 99 drags the partner), overlay.
- Not verified: two real PCs, fullscreen, KO->get-up adoption in live combat, executions, game_load
  restart path, bosses/elevators/car.

## Installer (v0.2.3)
- A C# WinForms installer (installer/*.cs, built with the .NET Framework csc.exe, C# 5) produced a
  byte-identical game but Defender flags it as Trojan:MSIL/NjRAT.SPTP!MTB (ML false positive), even with
  no embedded resources and no COM. Not shipped; kept as source only.
- Shipped instead: official python.org embeddable 3.13.6 amd64 (PSF-signed) trimmed to python.exe,
  python3.dll, python313.dll/.zip, vcruntime140*.dll in dist/python. Embeddable Python ignores the
  script dir (._pth), so build_mod.py inserts its own folder into sys.path before importing gm7.
- Defender scan of dist and of the built game: no threats.
- v0.2.1: remote kills drop the enemy's gun and the metro briefcase (objESubwayStatic +
  sprESubwayBriefcase); before, the metro level could not be finished when the partner killed him.
- v0.2.2: HM2 search via registry SteamPath, all libraries, HM1's library, common drive paths, manual prompt.

## v0.3 enemy simulation sync (protocol HMC3 + enemy packets HME3)
- Ownership per enemy identity (coop_own). Owner runs the real AI; the other side's copy is a puppet:
  "if scrCoopPuppet() exit" prepended to every code action of step/alarm/animation-end of objEnemy
  descendants + objEHideM16/objESubwayStatic (32 objects, 62 blocks; children never call event_inherited).
  Knocked-out objects are NOT guarded (their step holds the "hit while down" + get-up logic), only
  position/type synced.
- Owner sends up to 48 enemies (uid, object, x, y, facing, sprite, frame, alert) every 2nd step.
  Puppet lerps, copies sprite/frame; different object -> scrCoopMorph (set angle/direction/image_angle,
  the game sets angle after creating KO objects or their draw errors "Unknown variable angle").
- Conflicts (both own): later arrival on the floor (field 16 frames-on-floor) yields, else net_rank
  (session id compare). coop_lock (60 frames) after a handoff/claim beats the tie-break.
- Handoff every 10 steps: partner closer by 64 px -> event 3 (room, uid, x*10000+y, alert).
- Local transform of a puppet (we hit it) adopts its identity with own=0 -> claim: own=1 + event 5.
- New objEBullet instances -> event 4 (room, x*10000+y, dir, speed), spawned on the other side.
- Corpse near a vanished identity only counts as a death if no live instance still carries the uid.
- Verified with two instances (debug F4 shot, F5 knock-out, F6 give-all, overlay counters): positions
  identical within a few px in one capture, rank/seniority split, proximity handoff 0->2/3 owned,
  bullet replicated (rxbullets 1), KO mirrored (enemies 5 ko 1 on both).
- Not verified: real combat (melee on partner, door bashes, executions of puppets), two real PCs.

## v0.3.1 launch failure (2026-10-02)
- Symptom: "Error defining an external function" in objDevolver create (bgm_Init), then a crash in bgm.dll
  +0x5250 (malloc thunk). The unmodified game failed the same way, so it was not the mod.
- Cause: bgm.dll (MinGW, preferred base 0x6D740000) has its base-relocation directory listed twice
  (size 0xEE0 = 2 x 0x770, 1828 entries, 914 unique). It works only at its preferred base. When it is
  relocated, every fixup is applied twice and DllMain fails (ERROR_DLL_INIT_FAILED 1114). After a reboot,
  ASLR put winspool.drv at 0x6D6C0000-0x6D74A000, which overlaps that base. Reproduced by reserving
  0x6D740000 before LoadLibrary.
- Fix: tools/fix_bgm.py writes hmbgm.dll (reloc dir size halved, only if both halves are identical).
  build_mod.use_fixed_bgm rewrites the 2 code references to the DLL path. install.py creates hmbgm.dll, and
  uninstall removes it. Verified: hmbgm.dll loads relocated (0x077A0000), no error, in the real game folder.

## v0.3.2 Beard invisible (2026-10-02)
- Beard players were drawn invisible (the user reported "nobody sees the skin"). GM7 sprite frames are BGRA:
  the game's own opaque pixels have alpha 255 and key pixels 0. gm7.add_sprite wrote alpha 0 for every pixel,
  so the sprite drew nothing. Fixed: alpha 255 for opaque pixels. Verified in labs: the local Beard and the
  Beard ghost are both visible. The debug overlay has a third line: skin, has_beard, map size, sprite -> mapped.

## v0.3.3 Beard executions (2026-10-02)
- HM2 Nicke only has KillKnife/KillNeck. The other 60 Jacket player-only sprites (executions, human shields,
  climbing, sneaking...) are recoloured at build time (tools/beard_recolor.py): Jacket-only colours (jacket
  c0c000/808000, hair golds) map to Nicke's greens/browns. White/grey sleeves share the mobster suit colour,
  so a white blob is recoloured only if >=60% of it lies within 5 px of Jacket-only pixels. Victims baked into
  the sprite (bash, hammer...) stay white.
- gm7.Game.sprite_frames(names) reads the game's own frames (BGRA). The skin map grows to 153 entries.
- Debug: F7 moves the player onto the nearest objKnockedOut. F11/F12 and events 98/99 run scrInitScore +
  scrResetScore when global.combo is missing (the old "Unknown variable combo" error after a jump from the menu).
- Verified in labs: Beard bash execution drawn green (sprPAttackBash 145 -> 1491).

## v0.3.4 masks (2026-10-02)
- Removed the "Beard skips scrDrawMask" patch: Beard wears the chosen mask (sits fine on the Nicke head too).
- The ghost draws the partner's mask (fields 13 maskon, 14 maskindex) when state=1: objCoopNet keeps its own
  maskaddx/maskaddy tables (scrCoopMaskInit zeroes 100 frames, scrUpdateMaskPos(partner's HM1 sprite) on
  sprite change) and draws sprMasks like scrDrawMask with the ghost's angle/scales. Verified in labs: local
  Beard, Beard ghost and Jacket ghost all show the rooster mask.

## v0.4 car sync + HM2 skins (2026-10-02)
- Car: objPlayerCarEnter's 4 "image_index<12 ... else {" exits become "else if scrCoopCarReady() {". The car
  waits (global.coop_incar, state field 17) until the partner sits in a car in the same room (field 17 + field 1),
  or Enter, or no partner connection. Departing sets global.coop_cargo (kept until the room changes) and sends
  event 6 (room) so a waiting partner leaves too. Messages at the bottom of the view.
  Verified in labs: the first player waits with the message, the partner sees "... IS WAITING IN THE CAR".
  Verified: the second player got in and both drove off together (both reached objScoreStats; its
  "Unknown variable title" error there is only because the debug F11 jump skips level select).
- Skins: SKINS = beard(sprNicke), richter(sprRat), corey(sprZebra), jake(sprCobra). skin_map() maps HM1 walk/attack
  per weapon (aliases + fallbacks), legs, deaths by name; Beard keeps BEARD_MAP. Everything else player-only is
  recoloured per palette (beard_recolor.PALETTES), except story/boss sprites (_NO_RECOLOR). Skin map key =
  skin*100000 + HM1 sprite; global.coop_skin_ok[], global.coop_skin_mask[] (Richter/Corey: no HM1 mask,
  scrDrawMask exits via scrCoopSkinMasked; ghost mask too). hmnet: skin= jacket|beard|richter|corey|jake|random(-1)|N.
- Memory: the 32-bit runner peaked at ~2.09 GB with all skins -> "Unexpected error occured when running the game"
  while loading. build_mod sets IMAGE_FILE_LARGE_ADDRESS_AWARE on the output exe. Both labs load and reach the title.
- Verified in labs (Richter + Jake): own sprites drawn, Richter without HM1 mask, Jake and the Jake ghost with it.

## v0.5 doors, dialogs, character menu (2026-10-02)
- Doors (objDoorV + children): scrCoopDoors sends event 7 (room, door id, swingspeed) when a door with swinger=1
  (pushed by our player) gains >1 of |swingspeed| in a step. The receiver sets the same room-editor id's swingspeed
  with swinger=2 (no door slams on the receiving side, no echo). Verified: lab1 door -> 132 deg, lab2 same door 124.
- Dialogs (objPhoneConversation, drawn only by objEffectorHouse/Hospital, i.e. story scenes): scrCoopDialog sends
  event 8 (room, current line or -1 closed, messages); the receiver with the same number of lines jumps forward /
  closes (answering machine inactive for sprPhone). Verified on the tutorial: clicks in one window advanced and
  finally closed the Beard tutorial in both.
- Title character menu: C / Shift+C cycles available skins (Tab is eaten by the Delphi form), scrCoopSaveSkin rewrites
  the skin= line of hmcoop.txt; preview drawn bottom-left by scrCoopSkinMenuDraw. Verified (jake -> jacket saved).
- Clicking a lab window on the title screen selects the highlighted menu item; the last launched window has focus.
- Debug: F2 test conversation on both (event 97), B push the nearest door, overlay line 4 = door angles.

## v0.5.1 runtime-spawned enemies (2026-10-02)
- Report: chapter 1 metro, enemies leaving the train: 1 on one side, 2 on the other, level could not be finished.
- Cause: enemies created at runtime got coop_uid = their own instance id (differs between the games), or
  adopted a nearby vanished (possibly dead) identity, so kills never matched.
- Fix: tag_spawned_enemies patches the 8 spawn points (objSubwayDoor, objSwatSpawn x2, objSwatVan x4, objDumpster):
  "my_id=instance_create(...)" + scrCoopSpawned(my_id) -> coop_uid = 8000000 + (spawner id mod 100000)*64 + n.
- Verified in labs with a door-spawned enemy (debug M on both): same uid 8125889 on both, F9 on one side -> 0 on both.

## v0.6 (2026-10-02): weapons, bullets, partner enemies, revive, elevators/bosses, menu, version, internet, 4 skins
- Weapons: floor weapons are objWeapon (type = image_index, random per side at room start!), flying ones
  objWeaponThrow. sync_weapons hooks scrPlayerPickUp/2: pickup -> event 9 (room, pos, type), the partner removes
  the NEAREST objWeapon/objWeaponThrow within 64 px (any type). Throws/drops -> event 10 (pos, dir*64+speed*2,
  type*1000+ammo) -> partner spawns objWeaponThrow with coop_ghost (objWeaponThrow step "speed>2.5" KO block skipped).
  When both are on a floor the rank-1 side sends its objWeapon list (event 15) and the other copies the types.
  Verified: types equal after sync; pickup removed the partner's copy; a thrown bat landed at 79,60 / 81,61.
- Bullets: new objBullet (not coop_seen) -> event 12 -> partner creates objCoopShot (sprite of objBullet, no hits,
  dies on objSolid / 90 frames). Verified: double barrel shot = 16 events received.
- Partner's enemies: scrCoopPuppet also runs the objEnemyMelee contact kill (alert=1, 8 px) for puppets.
  Seen: both players killed in the kitchen of room 17.
- Revive: dead side sends state 2; the alive side within 28 px of the body presses E -> event 13 -> scrCoopRevive
  creates objPlayerMouse at the corpse (unarmed, same mask), destroys objPlayerDead/objMaskDrop. While dead our
  enemies are handed to the partner. Verified: X (die) on lab2, E on lab1 -> lab2 alive.
- Elevators: scrCoopFollow also looks for objElevator with the target nextroom (movex/movey copied). Bosses: when a
  floor that had objBoss reaches global.done=1, event 14 -> partner turns its objBoss instances into corpses.
  NOT verified in game (needs real boss/elevator floors).
- Menu (title): C skin, N name (get_string, net_set_name live, saved), I peer (net_set_peer live, saved),
  P copy public address. Verified: N -> partner showed the new name at once, hmcoop.txt updated.
- Version: packets carry modver (HMC4); a different version shows "partner has mod vX, you have vY" in red.
  Verified with a DLL built as v0.59.
- Internet without VPN: STUN binding request to stun.l.google.com:19302 from the game socket -> public ip:port shown
  in the menu (verified: address received). Hole punching itself NOT verified (needs two real networks).
- Skins 5-8: son (sprSon), writer (sprWriter), pardo (sprCop), henchman (sprHenchman); preload=0 for all added
  sprites keeps memory at 1.37 GB.

## v0.6.1 (2026-10-02): internet play removed (user request)
- The user wanted Radmin only. STUN query, net_public and the P (copy address) key are gone; the menu shows
  "YOUR RADMIN / LAN IP" (net_local: 26.x first, 172.16/12 and link-local skipped). MOD_VERSION stays 60, so 0.6
  and 0.6.1 play together. Verified: labs connect, menu shows the 26.x Radmin address.

## v0.7 (2026-10-02): 2-4 players
- hmnet.c rewritten for a full mesh: MAXP=3 peer slots (configured "peer=a,b,c", learned from unknown senders, and
  gossiped every 2 s with an HMP4 packet listing the other live peers, so one known IP is enough). Per peer: state,
  its own reliable event stream (outq/acks), enemy-state packet, session, version. Broadcast net_event/net_event4,
  directed net_event4_to(slot,...) for handoffs (3) and revive (13). GML selects the peer it reads with net_sel(slot);
  net_ev_get(5) = sender slot; net_es_get(uid,7) = slot of the peer that sends that enemy. MOD_VERSION 70.
- GML: scrCoopPeers snapshots every slot after net_poll (pok/pst/proom/px/py/prt/pcar/prank/pname/pin + counts).
  Ghost drawing loops over slots (gx/gy/gfirst arrays). Handoff goes to the closest peer on the floor; ownership
  conflicts are resolved against the peer that sends the enemy; a puppet nobody sends for 1.5 s is adopted. Car waits
  for every connected peer in a level; revive is sent to the dead peer's slot; dead players hand their enemies to an
  alive one; the most senior player on a floor sends the weapon list whenever someone arrives.
- Gotcha: global.coop_np was already the debug overlay's puppet counter -> renamed to global.coop_npeers.
- Verified with 4 labs (hm-lab1..4, ports 7787-7790, each configured with ONE other address): all four found each
  other, "connected to A, B, C" everywhere; F11/F10 moved all four; one owner per enemy; F9 in one lab -> 0 enemies
  in all four; lab3 died, lab1 pressed E -> lab3 revived.

## Exe installer (2026-10-10)
- A friend ran install.bat from "Code -> Download ZIP" of the repo: no build_mod.py next to install.py, no Python, no
  hmnet.dll. install.py now falls back to <repo>/tools, hmnet.dll is tracked in git, missing files are reported first.
- setup/HotlineMiamiCoop.iss (Inno Setup 6.7.3, installed via winget; ISCC at %LOCALAPPDATA%\Programs\Inno Setup 6):
  per-user install to %LOCALAPPDATA%\HotlineMiamiCoop (no admin), pages: game folder (SteamPath registry +
  libraryfolders.vdf detection), name + IPs (prefilled from the game's hmcoop.txt), character + windowed; then runs
  python install.py <game> --batch --name --peer --skin [--windowed] --log install_log.txt (UTF-8 BOM for Inno).
  Uninstaller runs install.py --uninstall --batch on the remembered game folder (installer.ini).
  C# installer was flagged by Defender (NjRAT ML); the Inno one scanned clean.
- Verified: GUI run against hm-lab4 (detected the real Steam folder first, prefilled FOURTH/peer/Son), build OK,
  "Apps" entry; silent uninstall removed the mod files from the game folder and the app folder, kept hmcoop.txt.

- Shortcuts (2026-10-10): after a successful build the installer creates "Hotline Miami Co-op.lnk" in the Start menu
  and (task "desktopicon", on by default) on the desktop, target <game>\HotlineMiami_Coop.exe, working dir = game
  folder, game icon; removed by the uninstaller. Verified install -> both links correct -> uninstall -> gone.

## v0.8 (2026-10-20): fixes from a review
- Enemies react to the player they see: scrCoopHandoff scores every player on the floor as distance, +1000 when the
  enemy cannot see them (farther than 240 or objSolid on the line; the game's scrSeePlayer uses 220), and hands the
  enemy to the best one when 64 better than us. Lock (coop_lock, 60 frames after a take) now ticks down every frame in
  scrCoopFollowState instead of in the handoff check (which only ran while we were alive on a floor with others).
- Deaths: build_mod.hook_enemy_deaths replaces the game's instance_create(x,y,objDeadBody) /
  instance_create(other.x,other.y,objDeadBody) (82 sites) with scrCoopBody(x,y,0|1), which tags the corpse with the
  dying enemy's coop_uid (self, or other for door bashes); scrCoopCorpse uses that tag and falls back to the
  nearest-vanished guess only for untagged corpses (player execution objects). A knocked-out enemy grabbed as a human
  shield (scrKillShield / scrXboxPlayerKillShield) counts as dead at once (scrCoopShieldTaken); shield corpses are
  pre-marked coop_seen.
- R: the dead list keeps the room of each uid (coop_dead_room). On game_load (detected by net_tick vs coop_tick; note
  the checkpoint is saved before scrCoopTrack sees the new room, so coop_room comes back as the previous room) with
  nobody else connected in this room: that room's dead are forgotten (full restart like solo) and event 16 (room)
  tells the others to forget them too. With someone on the floor the dead stay dead.
- Ownership: conflicts are checked against every slot that sends the uid (new net_es_by(uid,slot)), not only the
  first. A handoff (3) for a uid another slot claimed by hitting it (5) less than 800 ms ago is ignored (the 5 crossed
  the 3 on the way: both would simulate it). Morph targets from the network must be enemy-family objects
  (scrCoopFamilyObj). Family lists deduplicated (scrCoopTrack / scrCoopApplyDead use scrCoopWithFamily).
- Weapons list (15): sent when a player newly appears in the room (connected, any state - a revive is not an arrival)
  by whoever has been on the floor longest (rt, ties by rank), not by session rank.
- Ghost masks: offsets cached per slot (gmx/gmy 2D arrays) instead of one coop_mspr for all ghosts.
- hmnet.c (MOD_VERSION 80, enemy packets now HME5):
  - packets carry only the events they have: up to 16 reliable + 8 unreliable (40 B each) after a 296-byte head;
    idle packet 296 B instead of 616. net_uevent4 = unreliable broadcast (bullets 4 and 12; 12 only while together).
  - enqueue only to peers already heard (their first packet resets the streams anyway); overflow is counted per peer,
    net_event returns 0, net_overflow() and net_status report it; a full receive queue no longer acks the event.
  - slots: configured flag; learned addresses that never answer are freed after 15 s, learned peers silent 60 s are
    freed; when all slots are used a silent one (10 s) is taken for a new player; unanswered slots are only probed
    every 15th send; another mod version gets no slot (reported from a separate record, any packet size).
  - enemy state in pages of 48 (up to 4 = 192 enemies); a page counts while at most 4 sends old.
  - session id mixes QueryPerformanceCounter and the address of a static (4 DLL copies in one process got equal
    sessions); ports outside 1..65535 rejected; version shown as 0.8 / 0.61.
  - HMNET_LOSS=<percent> drops outgoing datagrams (test aid).
- net/test_hmnet.c: loads 4 copies of the DLL in one process on 127.0.0.1: mesh from one known address each (with a
  typo address forcing slot reuse), 1500 reliable events in order, unreliable at most once, 150 enemies readable,
  v0.7 packet reported without a slot. Passes at 0, 5, 20, 40 % loss.
- tools/check_gml.py: every obj*/spr*/scr* name in gml/ must exist in the game (caught objPlayerShieldController,
  which does not exist: GM7 only fails when the line runs). tools/make_release.py: DLL + test + fresh dist copies +
  SHA256.txt + zip + installer. tools/echo_peer.py updated to the v0.8 layout (and acks events).
- build_mod: HM2 extraction errors disable the HM2 skins instead of failing the build; patch points without a count
  check now assert; known errors end with a "not a version the mod knows" message.
- Debug builds read one command from coop_cmd.txt (any debug key name, E = revive, R = restart, N = stand next to the
  nearest enemy): labs are driven without touching the keyboard (hm-tools/shots/lab.sh: build, start N, cmd, st, stop).
- Verified in labs: 2 labs: kills from both sides via the corpse tag; R with the partner on the floor keeps 4 of 6
  alive (2 stay dead), R alone brings back all 6; an enemy bullet arrives (ebul); N next to an enemy moves it to that
  player and it attacks them. 4 labs: mesh of 4, kills in 3 different labs -> same count everywhere, revive via E,
  kill after revive. 2 labs with HMNET_LOSS=15: transitions, kills, F9 all consistent. Echo partner connects and acks.
  Lab4 lacked hmbgm.dll (made by the installer) -> "Error defining an external function" in objDevolver: lab setup,
  not the mod.
- Not verified: real PCs over Radmin, bosses/elevators, long fights with many handoffs.
