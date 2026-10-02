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
- **Shared enemies**: every enemy is simulated by the player closer to it and mirrored on the other
  side, so enemies walk, shoot, get knocked down and die the same way for both. Enemy bullets fly on
  both screens; enemies the partner controls can still kill you in melee. Enemies the game spawns at
  runtime (metro train, SWAT, the dumpster hobo) are shared too.
- **Kills and floors**: a kill counts for both, a cleared floor is cleared for both. Taking an exit
  arrow or an elevator takes the partner along. A boss beaten by one goes down for the other.
- **Level end**: the car leaves only when everyone in the level sits in it (Enter in the car: leave alone).
- **Weapons**: weapons on the floor are the same for both; a pickup removes it for the partner,
  thrown and dropped weapons fly and land on both screens. The partner's bullets are drawn too.
- **Revive**: when another player dies, stand on the body and press **E**. While you lie dead, a
  living player runs your enemies; **R** restarts the floor as usual.
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

## Install (both players)

1. Download the release zip and unpack it **completely** anywhere.
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
- `partner has mod vX, you have vY` → install the same version on both PCs.
- `port 7777 busy` → set another `port=` in `hmcoop.txt` (and tell the partner).

## Not synced (yet)

Cutscenes other than dialogs; each player fights a boss in their own game (only the result is shared);
scores are per player.

## How it works

`HotlineMiami_Original.exe` is a GameMaker 7 game. `tools/gm7.py` reads and writes its data
(encrypted, zlib-packed asset sections — byte-exact round trip). `tools/build_mod.py` adds an
`objCoopNet` object and the `scrCoop*` scripts from `gml/`, hooks the game's own code (enemy AI guard,
pickups, car, spawners, …) and embeds the skins. `tools/hm2_extract.py` reads HM2's
`hlm2_data_desktop.wad` atlases. `net/hmnet.c` is the network DLL: player state 60×/s, a reliable
ordered event channel (kills, transitions, pickups, …) and an enemy-state channel.

Technical journal: [MODLOG.md](MODLOG.md). Notes for continuing the work: [CONTINUE.md](CONTINUE.md).

### Build from source

```
zig cc -target x86-windows-gnu -shared -O2 -s -o hmnet.dll net/hmnet.c -lws2_32
py -3 tools/build_mod.py "<game>/HotlineMiami_Original.exe" "<game>/HotlineMiami_Coop.exe" [--windowed] [--debug] [--hm2 <hlm2_data_desktop.wad>]
py -3 tools/fix_bgm.py "<game>/bgm.dll" "<game>/hmbgm.dll"
```

`--debug` adds test hotkeys and an overlay (see CONTINUE.md).

## Credits

Authors: [AHceky](https://github.com/AHceky), [MoestroSWAGa](https://github.com/MoestroSWAGa).
Made with Claude (Anthropic). Hotline Miami and Hotline Miami 2 © Dennaton Games / Devolver Digital.
This is a fan project; it contains no game files and needs your own copies of the games.
