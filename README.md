# Hotline Miami — Co-op mod

[Русская версия](README.ru.md)

Online co-op for **2–4 players** in **Hotline Miami 1** (Steam, the GameMaker 7 `HotlineMiami_Original.exe`).
Each player runs their own game; the mod links the games over UDP (Radmin VPN, ZeroTier or a LAN)
and keeps the world in sync.

The mod ships **no game files**. The installer patches your own copy of the game into a new
`HotlineMiami_Coop.exe`; the original files stay untouched. Extra characters are taken from your own
copy of Hotline Miami 2 at install time.

## Features

- **Up to 4 players**: everyone connects to everyone directly; you only need to enter one other
  player's IP, the rest are found automatically.
- **The others on your screen**: position, aim, weapon, mask, name above the head.
- **Shared enemies**: every enemy is simulated by one player - the one it can see (closer than 240
  pixels, no wall in between), or the closer one if it sees several or nobody - and mirrored for the
  others. So an enemy reacts to whichever of you it spots, not only to its "owner". Enemy bullets fly
  on every screen; melee enemies kill anyone they touch. Enemies the game spawns at runtime (metro
  train, SWAT, the dumpster hobo) are shared too.
- **Kills and floors**: a kill counts for everyone (the mod knows exactly which enemy died, from the
  game's own death code), a cleared floor is cleared for everyone. A hostage taken as a human shield
  counts as dead at once. Taking an exit
  arrow or an elevator takes the partner along. A boss beaten by one goes down for the other.
- **Level end**: the car leaves only when everyone in the level sits in it (Enter in the car: leave alone).
- **Weapons**: weapons on the floor are the same for both; a pickup removes it for the partner,
  thrown and dropped weapons fly and land on both screens. The partner's bullets are drawn too.
- **Revive**: when another player dies, stand on the body and press **E**. While you lie dead, a
  living player runs your enemies.
- **R (restart the floor)**: with other players on the floor you come back at the checkpoint and the
  floor stays as they have it (the dead stay dead). Alone on the floor, it starts over as in the normal
  game, and it will be fresh for the others too when they get there.
- **Doors and dialogs**: a door you push swings for the partner; conversation boxes advance and close
  for both.
- **Characters**: Jacket, plus (from your HM2) Beard, Richter, Corey, Jake, Son, Writer (Evan),
  Pardo and the Henchman. HM2 walk/attack/death animations are used as they are; ground executions,
  human shields etc. are Jacket's animations recoloured into the character's palette.
- **Version check**: if the partner runs another mod version, it is shown in red at the top.

## Requirements

- Hotline Miami (Steam) for **each** player (2 to 4 players).
- Hotline Miami 2 (Steam) for the HM2 characters (optional: without it you are Jacket).
- A shared network: [Radmin VPN](https://www.radmin-vpn.com/) (recommended), ZeroTier or a LAN.
- Both players on the **same mod version**.

## Install (every player)

**Easiest:** download `HotlineMiami-Coop-Setup-vX.exe` from Releases and run it. It finds the game,
asks for your name, the other players' IPs and a character, builds the co-op game and adds an
uninstaller to Windows "Apps". (Windows SmartScreen may warn about an unknown publisher: "More info"
→ "Run anyway".)

**Or by hand:**

1. Download the release zip and unpack it **completely** anywhere (not "Code → Download ZIP").
2. Run `install.bat`. It finds the games in Steam, builds `HotlineMiami_Coop.exe` next to the game and
   asks for your name, the other players' Radmin IPs (look like `26.x.x.x`, comma separated —
   one is enough) and a character.
   Python is bundled (official embeddable build from python.org) — nothing to install.
3. Uninstall: `uninstall.bat`.

## Play

1. Both start `HotlineMiami_Coop.exe` from the game folder (Steam running). If the game asks
   "Enable Steamworks?", answer **No**.
2. Top left of the menu: `CO-OP: connected to <name>` — you are linked.
3. Main menu keys: **C** character (Shift+C back), **N** your name, **I** other players' IPs. Your
   own Radmin / LAN address is shown there — tell it to the others.
4. Pick the same chapter. When you are on the same floor you see each other.

The game keeps running when its window is not focused (otherwise the partner would freeze), but it
ignores keys and mouse until you click back into it.

### If you can't connect

`hmnet_log.txt` next to the game is refreshed every 2 seconds:

- `sent` grows, `received` = 0 → packets don't arrive: check the IP, that both are in the same Radmin
  network, allow `HotlineMiami_Coop.exe` in the Windows firewall.
- `a player has mod vX, you have vY` → install the same version on every PC.
- `connection too slow: game events were lost` → the link was so bad that the games may differ now:
  restart the floor.
- `port 7777 busy` → set another `port=` in `hmcoop.txt` (and tell the partner).

## Not synced (yet) / known limits

- Cutscenes other than dialogs; each player fights a boss in their own game (only the result is
  shared); score and combo are per player.
- An enemy sees one player at a time, the one simulating it. If an enemy that is closer to your
  partner and sees them also sees you, it won't turn to you until you are clearly closer.
- No lobby: pick the same chapter by hand; whoever enters a floor first runs all its enemies at first.
- Tested with several game copies on one PC, including 15% artificial packet loss, but little across
  real PCs over the internet - if something drifts apart, send everyone's `hmnet_log.txt`.
- The mod does not check who connects to you: play in your own (closed) Radmin network, not a public one.

## How it works

`HotlineMiami_Original.exe` is a GameMaker 7 game. `tools/gm7.py` reads and writes its data
(encrypted, zlib-packed asset sections — byte-exact round trip). `tools/build_mod.py` adds an
`objCoopNet` object and the `scrCoop*` scripts from `gml/`, hooks the game's own code (enemy AI guard,
pickups, car, spawners, …) and embeds the skins. `tools/hm2_extract.py` reads HM2's
`hlm2_data_desktop.wad` atlases. `net/hmnet.c` is the network DLL: player state 60×/s, a reliable
ordered event channel (kills, transitions, pickups, …) and an enemy-state channel.

Technical journal: [MODLOG.md](MODLOG.md). Notes for continuing the work: [CONTINUE.md](CONTINUE.md).

### Build from source

A whole release (DLL, protocol test, the `dist` folder, the zip and the exe installer):
`py -3 tools/make_release.py --game "<game>/HotlineMiami_Original.exe"` (needs zig and Inno Setup 6).
The version comes from `MOD_VERSION` in `net/hmnet.c`.

Step by step:

```
zig cc -target x86-windows-gnu -shared -O2 -s -o hmnet.dll net/hmnet.c -lws2_32
zig cc -target x86-windows-gnu -O2 -o test_hmnet.exe net/test_hmnet.c -lws2_32 && test_hmnet.exe <folder with hmnet.dll> 20
py -3 tools/check_gml.py "<game>/HotlineMiami_Original.exe"
py -3 tools/build_mod.py "<game>/HotlineMiami_Original.exe" "<game>/HotlineMiami_Coop.exe" [--windowed] [--debug] [--hm2 <hlm2_data_desktop.wad>]
py -3 tools/fix_bgm.py "<game>/bgm.dll" "<game>/hmbgm.dll"
```

`--debug` adds test hotkeys and an overlay (see CONTINUE.md). `HMNET_LOSS=15` in the environment makes
the DLL drop 15% of outgoing packets (to try a bad connection).

## Credits

Authors: [AHceky](https://github.com/AHceky), [MoestroSWAGa](https://github.com/MoestroSWAGa).
