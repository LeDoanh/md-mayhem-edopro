"""Build a portable zip of the plugin, laid out exactly as it sits in EDOPro.

install.ps1 only runs on Windows, but the plugin itself is plain Lua and text:
EDOPro loads ./init.lua on every platform from shared code in game.cpp, and
Starting LP is a uint32 everywhere. So Android, Linux and macOS clients just need
the same files dropped into the game folder, which is what this zip is for.

The archive cannot inspect the destination before extraction. Its README
therefore requires preserving any existing init.lua before files are copied.

Usage:
    python tools/make-package.py
"""

from __future__ import annotations

import json
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GENERATED = REPO / "install" / "generated"
DIST = REPO / "dist"

PLUGIN_DIR = "expansions/script/mdmayhem/"

README = """MD Mayhem - EDOPro mutation cores
=================================

Install
-------
IMPORTANT: check the EDOPro folder before extracting.

First install: if init.lua.bak already exists, move that older backup out of the
game folder and keep it separately. If init.lua is not MD Mayhem's own loader,
rename it to init.lua.bak before extraction.

Upgrade: do NOT rename MD Mayhem's current init.lua again and do not replace the
pre-Mayhem init.lua.bak. Overwrite the Mayhem loader directly. If init.lua also
loads another tool, preserve that shared file and ensure it still loads
mayhem_bootstrap.lua instead of replacing it blindly.

For every upgrade, copy expansions/script/mdmayhem/mayhem_config.lua somewhere
safe if you customized it, then delete the old expansions/script/mdmayhem
directory before extracting. This removes retired core modules. Extract only
after this preflight, then restore your saved mayhem_config.lua over the packaged
default.

Extract this zip over your EDOPro folder, keeping the folder structure. The
files land as:

  init.lua                            (next to EDOPro.exe / the app data root)
  expansions/script/mdmayhem/*.lua
  lflists/Mayhem_Tactical.lflist.conf
  Mayhem-codes.txt

Then restart EDOPro.

Only the player who HOSTS the duel needs this. EDOPro runs the duel core on the
hosting client, so the host's rules are what both players play under.

Android / Linux / macOS
-----------------------
Same files, same places - the plugin is plain Lua, nothing platform specific.
The game folder is wherever EDOPro keeps init.lua, config/ and expansions/.
On Android that is the app's own data folder; use a file manager that can reach
it, or copy the files across from a computer.

Use
---
Host in LAN mode. Only a LAN-hosted room runs the duel core on your own
machine; a room hosted through Online Multiplayer runs on the remote server,
where this plugin does not exist and the code would just become real life
points. Solo mode does not work either - it takes its LP from the puzzle.

There is no menu. Pick a core by typing its number into
LAN mode -> Create Host -> Duel tab -> Starting LP:

  Starting LP = {base} + core code

The chosen core sets the real life points once the duel starts. A normal
Starting LP is left alone, so casual and AI games are unaffected. The full code
list is in Mayhem-codes.txt.

Energy Dominate starts each player at 12 energy and refills that player's energy
to 12 at their Standby Phase. It shows the numeric balance and also writes a
[MAYHEM ENERGY] line after every spend/refill. To see those lines in duel chat,
set coreLogOutput=3 in config/system.conf; EDOPro labels script chat in red as
"Script Error", even though the duel is working normally.

Uninstall
---------
Delete expansions/script/mdmayhem/, lflists/Mayhem_Tactical.lflist.conf and
Mayhem-codes.txt. Delete init.lua only if it is byte-for-byte identical to the
init.lua in this archive; otherwise it may be a shared loader and must be kept.
If init.lua.bak was created during installation and init.lua was safely deleted,
rename the backup to init.lua.
"""


def main() -> int:
    # Never package stale generated data. This also validates codes, statuses
    # and component dependencies before the archive is written.
    result = subprocess.run([sys.executable, REPO / "tools" / "build-catalogue.py"])
    if result.returncode != 0:
        return result.returncode
    catalogue = GENERATED / "mayhem_catalogue.lua"
    if not catalogue.is_file():
        raise SystemExit("install/generated is missing. Run: python tools/build-catalogue.py")

    data = json.loads((REPO / "cores.json").read_text(encoding="utf-8"))
    version = data["version"]

    DIST.mkdir(exist_ok=True)
    target = DIST / f"mdmayhem-{version}.zip"

    # src/ is split for readability but the install has to be flat, so
    # src/cores/<id>.lua ships as mayhem_core_<id>.lua - the name
    # MAYHEM.ApplyCore derives from the core id. Keep this in step with
    # install.ps1: whatever one writes, the other must too.
    members: list[tuple[Path, str]] = [(REPO / "install" / "init.lua", "init.lua")]
    for lua in sorted((REPO / "src" / "runtime").glob("*.lua")):
        members.append((lua, PLUGIN_DIR + lua.name))
    for lua in sorted((REPO / "src" / "cores").glob("*.lua")):
        members.append((lua, PLUGIN_DIR + "mayhem_core_" + lua.name))
    members.append((catalogue, PLUGIN_DIR + catalogue.name))
    members.append((GENERATED / "Mayhem-codes.txt", "Mayhem-codes.txt"))
    for banlist in sorted((REPO / "install").glob("*.lflist.conf")):
        members.append((banlist, f"lflists/{banlist.name}"))

    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for source, arcname in members:
            archive.write(source, arcname)
        archive.writestr("README.txt", README.format(base=data["lp_code_base"]))

    size = target.stat().st_size
    print(f"wrote {target.relative_to(REPO)}  ({len(members) + 1} files, {size / 1024:.1f} KB)")
    for _, arcname in members:
        print(f"  {arcname}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
