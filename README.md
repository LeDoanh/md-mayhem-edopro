# MD Mayhem — mutation cores for EDOPro

*[Tiếng Việt](README.vi.md)*

Custom duel rules for [EDOPro / Project Ignis](https://projectignis.github.io/),
picked per match by typing a number into the Host window's **Starting LP** box.

A "mutation core" is one rule: *start with no opening hand and tutor at
Standby*, *only one monster may attack each turn*, *actions spend Energy*. The
tournament rolls a core before each game; this plugin makes the client enforce
it, so nobody has to count summons by hand or review replays.

Nothing in the client is patched. No card scripts are overridden, no game modes
are replaced, no interface strings are changed — EDOPro stays usable for normal
play, and the uninstaller puts everything back.

## Requirements

- EDOPro (any recent build; developed against 2026-04-20)
- **Only the player who hosts the duel needs it.** EDOPro runs the duel core on
  the hosting client, so the host's rules are what both players play under.
- **LAN-hosted rooms only.** A room hosted through Online Multiplayer runs on
  the remote server, where the plugin does not exist.

## Install

**Windows**

```powershell
powershell -ExecutionPolicy Bypass -File tools\install.ps1
```

It asks which EDOPro install to use the first time and remembers the answer.
Restart EDOPro afterwards — it scans for the plugin only at startup.

**Android, Linux, macOS, or handing it to another host**

```bash
python tools/make-package.py     # builds dist/mdmayhem-<version>.zip
```

Read the packaged `README.txt` before extracting. On a first install, preserve a
foreign `init.lua`; on an upgrade, overwrite Mayhem's own loader without
replacing the original pre-Mayhem backup. Preserve a customized
`mayhem_config.lua`, remove the old plugin directory, extract, then restore the
config. This cleanup is what removes retired core modules.

## Use

There is no menu. Pick a core by typing its number into

```
LAN mode → Create Host → Duel tab → Starting LP = 1000000 + core code
```

The selected core sets the real life points once the duel starts. **The counter
snapping from the typed number to the real value is the signal that the plugin
ran.** A normal Starting LP is left alone, so casual and AI games are unaffected.

The full list is written to `Mayhem-codes.txt` next to `EDOPro.exe`, or run
`python tools/list-codes.py`.

Codes `1–19` are retired permanently. The current catalogue has 38 entries at
codes `20–57`; use the generated list rather than copying a static table from
documentation.

A banlist for the tournament's permanent floodgate bans ships as
`lflists/Mayhem_Tactical.lflist.conf`; pick it in the room's Rule dropdown.

## How it works

EDOPro loads `<game>/init.lua` into every duel it creates. That file loads the
plugin, which installs each rule as a global effect — the same mechanism the
client's own `proc_skill.lua` uses, so no custom cards or database rows are
needed.

Only five values travel from the room settings into the duel core, and
`startingLP` is an unclamped 32-bit integer. That makes it the one channel wide
enough to carry a selection, which is why cores are picked by typing a number
rather than clicking one: EDOPro's interface is compiled in and cannot be
extended without forking the client.

`docs/edopro-integration.md` records every engine hook this relies on and the
source it was verified against.

## Adding a core

One file in `src/cores/`, one entry in `cores.json`:

```lua
-- For the next unused code, 58:
MAYHEM.Register("58_my_core", {
    defaults = { some_number = 5 },
    apply = function(params)
        MAYHEM.FieldRule(EFFECT_X, params.some_number, true)
    end,
})
```

**[docs/writing-a-core.md](docs/writing-a-core.md)** is the full guide: recipes
per rule shape, the helper API, how to look up an effect code you do not know,
testing, and the traps that have actually bitten.

Two test layers:

```bash
lua tools/test-cores.lua                # offline, ~1s, checks the wiring
python tools/run-duel.py --code 20      # loads the client's real ocgcore.dll
```

`run-duel.py` needs a 32-bit Python, because EDOPro is 32-bit:
`uv python install cpython-3.12-windows-x86`.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1 -WhatIf   # dry run
powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1
```

Removes only what the installer wrote. An `init.lua` belonging to something else
is detected and left alone.

## Known limits

- **The turn timer is not scriptable.** It is a room setting the host picks;
  each core records the intended value in `cores.json`.
- **Deck-construction rules cannot block deck building.** EDOPro's deck checker
  is client-side, so Extra Deck / Main Deck size limits are enforced as an
  automatic loss at duel start instead.
- **No general player-text channel.** Energy Dominate deliberately uses a
  numeric hint plus script chat; set `coreLogOutput=3` to see its chat balance.
- Three catalogue entries are marked `partial`; their exact engine limitations
  and required room settings are printed in `Mayhem-codes.txt`.

## Layout

```
cores.json          the registry: code → mutation, script, parameters
src/runtime/        bootstrap, engine helpers, operator config
src/cores/          one core per file, named <code>_<id>.lua
install/            duel entry point, banlist sources
tools/              install, uninstall, generators, tests, headless duel runner
docs/               how to write a core, and the verified engine findings
```

Companion to the MD Mayhem roller web app, which picks which core a match runs
under. `sheet_name` in `cores.json` is the join between the two.
