# Hotline Miami 1 co-op mod - handoff for a new chat

Current release: **v1.1** (`dist/HotlineMiami-Coop-v1.1.zip`, built by `tools/make_release.py`). Full technical journal: `MODLOG.md` (read it first).

Repo: https://github.com/AHceky/hotline-miami-coop (public). Release zips go to GitHub Releases
(`gh release create vX dist/HotlineMiami-Coop-vX.zip`); gh is at "C:\Program Files\GitHub CLI\gh.exe".

## What the mod does
- Patches the user's own `HotlineMiami_Original.exe` (GameMaker 7) into `HotlineMiami_Coop.exe`.
- Partner shown as a named ghost; skins Jacket / Beard (HM2 "Nicke" sprites from the user's HM2 install).
- Kill sync, floor-transition sync, full enemy simulation sync (ownership by proximity, puppets,
  bullet replication, knock-down mirroring). UDP via `hmnet.dll`, works over Radmin VPN.

## Layout (this folder)
- `tools/gm7.py` - GM7 exe reader/writer (byte-exact round trip). `tools/build_mod.py` - the patcher.
  `tools/hm2_extract.py` - HM2 wad/atlas reader. `tools/echo_peer.py` - fake partner for solo tests.
- `gml/*.gml` - all injected GML (objCoopNet events, scrCoop* scripts). `objCoopNet_debug*.gml` only with `--debug`.
- `net/hmnet.c` - the DLL source (protocol HMC4 v0.8 + enemy pages HME5), `net/test_hmnet.c` - its protocol test.
- `installer/*.cs` - C# WinForms installer: works, but Defender flags it (NjRAT ML false positive) - NOT shipped.
- `dist/HotlineMiami-Coop/` - what users get: `install.bat` (bundled embeddable Python 3.13.6 in `python/`),
  `tools/`, `gml/`, `hmnet.dll`, README.txt (Russian). Zip it to release.

## Outside this folder (persist on their own)
- `C:\Users\RobotComp\hm-decomp\` - decrypted gamedata (`plain.bin`), dumped GML sources (`src/`), HM2 export (`hm2/`).
- `C:\Users\RobotComp\hm-tools\build\` - `hmnet.dll` build dir; zig at
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\zig.zig_*\zig-x86_64-windows-0.16.0\zig.exe`;
  OpenGMK source; `pyembed/` (python.org embeddable zip).
- `C:\Users\RobotComp\hm-lab1`, `hm-lab2`, `hm-lab3`, `hm-lab4` - lab copies of the game (ports 7787-7790); hm-tools/shots/labs4.sh N starts N of them, grid.py lays them out 2x2
  (ports 7787/7788 in their hmcoop.txt). The user's real game: `C:\Program Files (x86)\Steam\steamapps\common\hotline_miami`.

## Build / test
```
zig cc -target x86-windows-gnu -shared -O2 -s -o hmnet.dll hmnet.c -lws2_32
py -3 tools/build_mod.py "<...>\HotlineMiami_Original.exe" C:\Users\RobotComp\hm-lab1\HM_coop.exe --windowed --debug
```
Copy exe + hmnet.dll to both labs, start lab1 then lab2, place windows side by side (950x608 at x=0 / x=960).
Debug keys (host window): F11 jump both to chapter 1 (start the client's game first so globals exist),
F10 take exit arrow, F9 kill all, F8 kill nearest, F6 give my enemies, F5 knock out nearest, F4 enemy shot,
F12 jump both to the metro briefcase room, B push the nearest door, M spawn an enemy from a door on both, J metro entrance with done=1 (fragile), K pick up nearest weapon, X die, G go to partner, E revive (real key); F2 test conversation on both, F7 move onto the nearest knocked-out enemy (then Space = execution), F3 level done + sit in the car. Overlay shows enemies/ko/own/puppet/together/rank/rxbullets.

## Driving the labs without the keyboard
Debug builds read one command from `coop_cmd.txt` next to the exe (a debug key name like F8, or E / R / N) and
write their state to `coop_dbg.txt`. `. hm-tools/shots/lab.sh` then `build`, `start 2`, `cmd 1 F11 8`, `cmd 1 F10 8`,
`st 1 2`, `stop`. `export HMNET_LOSS=15` before `start` simulates a bad link. Every lab needs hmbgm.dll.

## Gotchas learned
- Debug builds write coop_dbg.txt next to the exe twice a second (room, player, weapons with type@pos, partner
  state, name, peer, public address): read it from bash instead of squinting at the overlay.
- GML evaluates every operand of "and": guard globals with a nested if (e.g. global.done on the title).
- Memory: the 32-bit runner breaks (Unexpected error) past ~2.1 GB even with LARGE_ADDRESS_AWARE; added sprites
  use preload=0 (texture made on first draw). 8 skins: 1.37 GB private, 2.04 GB peak.
- Focus: the last launched lab window gets keyboard focus; a click on the title screen starts the game; a Windows
  toast (ShellExperienceHost) can hold focus - close it with its X.
- The game's own bgm.dll has a duplicated relocation table (fixed in hmbgm.dll by tools/fix_bgm.py,
  the co-op exe loads that). If the game ever fails with "Error defining an external function" again,
  check what else changed in DLL loading first (it also hit the unmodified game).
- Run Python via Git Bash (`py -3`), not the packaged PowerShell (it can't see AppData\Roaming).
- Backslashes in heredoc-generated Python/C get eaten; edit such lines with the Edit tool.
- HM menus map the mouse from the screen centre: in an off-centre window click where the item would be
  in a centred window. The tool often can't send keys to the second window (foreground NULL).
- Jumping into a level straight from the menu errors (globals unset) - debug only.

## Open ideas / not verified
- Real combat on two PCs (melee on partner, door bashes, executions of puppets), fullscreen,
  bosses/elevators/car end of level not synced, enemies target only their owner.
