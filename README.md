# Hotline Miami Co-op Mod

[Русская версия](README.ru.md)

An unofficial fan-made **mod** that adds online co-op (multiplayer) for **2-4 players** to **Hotline Miami 1**
(Steam version, the GameMaker 7 `HotlineMiami_Original.exe`). It is not a standalone game: every
player needs their own copy of Hotline Miami. Each player runs their own game, and the mod links the
games and keeps the world in sync. You can play **through Steam** with friends, with no IPs and no
VPN, or the old way over Radmin VPN, ZeroTier or a LAN.

> **Beta.** So far the networking has only been tested on one PC: several copies of the game, and
> through Steam on one account. What is tested and what is not is listed under [Status](#status-beta).
> Found a bug? [Report it](#reporting-a-bug).

The mod ships **no game files**. The installer patches your own copy of the game into a new
`HotlineMiami_Coop.exe`, and the original files stay untouched. Extra characters are taken from your
own copy of Hotline Miami 2 at install time.

The mod is not affiliated with Dennaton Games or Devolver Digital. Details in [NOTICE](NOTICE).

## Features

- **Up to 4 players**: everyone connects to everyone directly.
- **Through Steam**: give everyone the same room code and the game finds the others through a Steam
  lobby. Or skip the code and invite a friend from your Steam friends list.
- **The others on your screen**: position, aim, weapon, mask, name above the head.
- **Shared enemies**: every enemy is simulated by the player closer to it and mirrored on the other
  side, so enemies walk, shoot, get knocked down and die the same way for both. Enemy bullets fly on
  both screens, and enemies the partner controls can still kill you in melee. Enemies the game spawns
  at runtime (metro train, SWAT, the dumpster hobo) are shared too.
- **Kills and floors**: a kill counts for both, and a cleared floor is cleared for both. Taking an
  exit arrow takes the partner along. Elevators and bosses should work for both as well (the elevator
  takes the partner along, a boss beaten by one goes down for the other), but this is not tested yet.
- **Level end**: the car leaves only when everyone in the level sits in it. To leave alone, press
  Enter in the car.
- **Weapons**: weapons on the floor are the same for both. A pickup removes the weapon for the
  partner, and thrown and dropped weapons fly and land on both screens. The partner's bullets are
  drawn too.
- **Revive**: when another player dies, stand on the body and press **E**. While you lie dead, a
  living player runs your enemies. **R** restarts the floor as usual.
- **Doors and dialogs**: a door you push swings for the partner too. Conversation boxes advance and
  close for both.
- **Characters**: Jacket, plus (from your HM2) Beard, Richter, Corey, Jake, Son, Writer (Evan),
  Pardo and the Henchman. Their walk, attack and death animations come straight from HM2. Ground
  executions, human shields and the like use Jacket's animations recoloured into the character's
  palette.
- **Version check**: if the partner runs another mod version, it is shown in red at the top.

## Requirements

- Windows. Other systems are not supported.
- Hotline Miami **from Steam** for **each** player (2 to 4 players). Only the Steam version has been
  tested, and playing through Steam works only with it.
- Hotline Miami 2 (Steam) if you want the HM2 characters. Without it you play as Jacket.
- Everyone on the **same mod version**.
- Nothing else for playing through Steam. Without Steam you need a shared network:
  [Radmin VPN](https://www.radmin-vpn.com/), ZeroTier or a LAN.

## Install (every player)

**Easiest:** download `HotlineMiami-Coop-Setup-vX.exe` from Releases and run it. It finds the game,
asks for your name, a room code (or the other players' IPs for Radmin) and a character, builds the
co-op game and adds an uninstaller to Windows "Apps".

The installer is not signed, so SmartScreen or your browser may warn that the file is rarely
downloaded or comes from an unknown publisher. In SmartScreen click "More info" → "Run anyway". You
can check the files against `tools/SHA256.txt`: the DLL builds byte for byte the same, and the build
command and zig version are listed there.

**Or by hand:**

1. Download the release zip and unpack it **completely** anywhere (not "Code → Download ZIP").
2. Run `install.bat`. It finds the games in Steam, builds `HotlineMiami_Coop.exe` next to the game and
   asks for your name, the other players' IPs, a room code and a character. To play through Steam,
   just press Enter at the IP question. Python is bundled (the official embeddable build from
   python.org), so there is nothing to install.
3. To uninstall, run `uninstall.bat`.

## Play

Everyone starts `HotlineMiami_Coop.exe` from the game folder with Steam running. If the game asks
"Enable Steamworks?", answer **No**.

### Through Steam (recommended)

- **With a room code.** Everyone enters the same code (in the installer or with **K** in the game
  menu). The game finds the others through a Steam lobby, no IPs or Radmin needed. Pick an
  **unusual word** for the code: whoever types the same code joins you.
- **Without a code.** **F** in the menu opens a lobby for your Steam friends. A friend clicks
  "Join Game" in the Steam friends list. **The friend's co-op game must already be running**,
  otherwise Steam starts the normal Hotline Miami.
- The `STEAM: ...` line in the menu shows how many players are connected.

### Over Radmin VPN, ZeroTier or a LAN

- Everyone is on the same network. **I** in the menu sets the other players' IPs (they look like
  `26.x.x.x` in Radmin, comma separated). One player's IP is enough, the rest are found automatically.
- Your own Radmin or LAN address is shown in the menu: tell it to the others.
- If the top left of the menu says `CO-OP: connected to <name>`, you are linked.

### Then

- Main menu keys: **C** picks a character (Shift+C goes back), **N** sets your name, **K** the room
  code, **I** the IPs, **F** the Steam friends lobby.
- Pick the same chapter. When you are on the same floor you see each other.
- The game keeps running when its window is not focused (otherwise the partner would freeze), but it
  ignores keys and mouse until you click back into it.

### If you can't connect

`hmnet_log.txt` appears next to the game and is refreshed every 2 seconds:

- `sent` grows, `received` = 0 → packets don't arrive. Check the IP and that everyone is in the same
  Radmin network, and allow `HotlineMiami_Coop.exe` in the Windows firewall.
- `partner has mod vX, you have vY` → install the same version on every PC.
- `port 7777 busy` → set another `port=` in `hmcoop.txt` (and tell the partner).

## Status (beta)

**Not tested yet:**
- playing on two different PCs over Radmin;
- two different Steam accounts (so far only several copies of the game on one account);
- full screen (the installer defaults to a window);
- long fights and sessions, bosses, elevators.

**Known:**
- With 4 players and many HM2 characters the game gets close to the 32-bit engine's memory limit
  (about 2 GB). An "Unexpected error" crash is possible.
- When mixing Steam and Radmin with 3-4 players, everyone needs a direct link to everyone.
- Everyone must install the same mod version, otherwise the game shows a red warning.

## Not synced (yet)

Cutscenes other than dialogs. Each player fights a boss in their own game, only the result is
shared. Scores are per player.

## Reporting a bug

- Open an [issue on GitHub](../../issues/new/choose) with the "Баг / Bug report" template.
- Attach `hmnet_log.txt` from the game folder **from every player**. If the mod did not install, also
  attach `%LOCALAPPDATA%\HotlineMiamiCoop\install_log.txt`.
- `hmnet_log.txt` contains IPs and SteamIDs. If you don't want to share them, blank them out first.

## How it works

`HotlineMiami_Original.exe` is a GameMaker 7 game. `tools/gm7.py` reads and writes its data: the
asset sections are encrypted and zlib-packed, and a file read and written back matches byte for byte.
`tools/build_mod.py` adds an `objCoopNet` object and the `scrCoop*` scripts from `gml/`, hooks the
game's own code (enemy AI guard, pickups, car, spawners, …) and embeds the skins.
`tools/hm2_extract.py` reads HM2's `hlm2_data_desktop.wad` atlases. `net/hmnet.c` is the network
DLL: player state 60 times a second, a reliable ordered event channel (kills, transitions,
pickups, …) and an enemy-state channel. Packets go over UDP or through Steam (using the game's own
`steam_api.dll`).

Technical journal: [MODLOG.md](MODLOG.md). Notes for continuing the work: [CONTINUE.md](CONTINUE.md).

### Build from source

The exe installer: `ISCC.exe setup/HotlineMiamiCoop.iss` (Inno Setup 6) → `dist/HotlineMiami-Coop-Setup-v<ver>.exe`.

```
zig cc -target x86-windows-gnu -shared -O2 -s -o hmnet.dll net/hmnet.c -lws2_32
py -3 tools/build_mod.py "<game>/HotlineMiami_Original.exe" "<game>/HotlineMiami_Coop.exe" [--windowed] [--debug] [--hm2 <hlm2_data_desktop.wad>]
py -3 tools/fix_bgm.py "<game>/bgm.dll" "<game>/hmbgm.dll"
```

`--debug` adds test hotkeys and an overlay (see CONTINUE.md). `tools/make_release.py` does all the
steps at once (DLL, tests, zip, installer, hashes).

## Credits

[AHceky](https://github.com/AHceky), [MoestroSWAGa](https://github.com/MoestroSWAGa)
