# MD Mayhem — EDOPro mutation-core plugin

Custom duel rules ("lõi đột biến") for EDOPro / MDPro3, selected per match by
typing a code into the client's Starting LP box. Companion to the roller web-app
in `../web-app`, which picks which cores a match runs under; this repo makes the
client actually enforce them.

Two documents carry the detail:

- `docs/writing-a-core.md` — how to write a core: recipes per rule shape, the
  helper API, testing, and the traps that have actually bitten. Start here.
- `docs/edopro-integration.md` — which EDOPro hooks were verified and against
  which source. Read it before changing anything under `src/runtime/`.

## Two mechanisms

**Loading.** EDOPro loads `<game>/init.lua` into **every duel it creates**, right
after `constant.lua` and `utility.lua` (`gframe/game.cpp`:
`PopulateResourcesDirectories` + `SetupDuel`). That file loads
`mayhem_bootstrap.lua`, which applies cores as global effects
(`Effect.GlobalEffect()` + `Duel.RegisterEffect`) - the same mechanism stock
`proc_skill.lua` uses. No custom cards, no `.cdb` rows, no deck slots.

**Per-match selection.** The host types `1000000 + <core code>` into the Host
window's **Starting LP** box; `Mayhem-codes.txt` is dropped beside `EDOPro.exe`
as the lookup. Only five values reach the duel core
(`OCG_DuelOptions`: seed, duel flags, and each team's startingLP /
startingDrawCount / drawCountPerTurn), and startingLP is an unclamped `uint32`
parsed with `stoul` - verified end to end with `tools/run-duel.py`. The bootstrap
decodes it, puts real life points back, and applies the catalogue entry.

**The life point counter is not the core's LP.** The host builds `MSG_START`
itself from `host_info.start_lp` (`generic_duel.cpp`), so the screen shows the
number that was typed. `Debug.SetPlayerInfo` changes the core silently, so the
plugin re-broadcasts through `Duel.SetLP` at `EVENT_STARTUP`, which always emits
`MSG_LPUPDATE`. LP snapping from the code to the real value is what tells the host
the plugin ran.

Why not the Host window's 13 "Extra Rules" checkboxes: they work, but only by
overriding EDOPro's 13 stock extra-rule cards and renaming their labels. The
stock modes have to keep working, and 13 is a hard ceiling. The LP code has
neither problem - the client is not patched at all, and the catalogue is
unbounded.

Only the **duel host** needs the plugin installed: EDOPro runs the duel core on
the hosting client — but only for **LAN-hosted** rooms. A room hosted through
Online Multiplayer runs on the remote server's core, where the plugin is never
loaded and cannot even report that it is missing (`menu_handler.cpp`,
`isHostingOnline`). Solo mode takes its LP from the puzzle script, not the Host
window, so it is not a valid test either.

**Platforms.** Nothing here is Windows-specific — the plugin is plain Lua, and
`init.lua` is loaded from shared code in `game.cpp` on every build. `install.ps1`
is the Windows convenience; `python tools/make-package.py` builds a zip that is
extracted over the game folder on Android, Linux or macOS. Keep the two in sync:
whatever install.ps1 writes, the zip must contain.

## Adding a core - the golden path

1. Add an entry to `cores.json` with the **next unused `code`**. Codes are
   permanent: a printed code must keep meaning the same mutation. `sheet_name`
   must match the Name column in `../web-app/public/mutations.xlsx` exactly.
2. Create `src/cores/<id>.lua` - copy the closest existing core; they are all
   under 25 lines. The file name **is** the core id; there is no registry to
   update, because `build-catalogue.py` reads the folder and fails if a
   `cores.json` entry names a file that is not there.
3. `python tools/build-catalogue.py`
4. Add a test to `tools/test-cores.lua`; run `lua tools/test-cores.lua`.
5. `powershell -ExecutionPolicy Bypass -File tools\install.ps1`
   (first run asks which EDOPro install to use and remembers it in `.game-path`;
   every tool reads that file, so none of them hardcode a path)
6. Verify against the real engine: `python tools/run-duel.py --code <code>`
   (needs a 32-bit Python - see Verifying below).

`python tools/list-codes.py` prints the LP numbers to hand to hosts.

Never hand-write card passcodes. Banlist entries go in
`install/banlist/mayhem-tactical.txt` by English name and are resolved against the
client's own `cards.cdb` by `python tools/build-banlist.py`.

## Core file shape

```lua
MAYHEM.Register("my_core", {
    defaults = { some_number = 5 },   -- optional, overridden by the catalogue entry
    apply = function(params)          -- required
        MAYHEM.FieldRule(EFFECT_X, params.some_number, true)
    end,
})
```

Helpers in `src/mayhem_engine.lua`:

| Helper | Use for |
| --- | --- |
| `MAYHEM.FieldRule(code, value, player_target)` | permanent rule on both players |
| `MAYHEM.OnEvent(event, op, countlimit)` | duel-wide trigger (`EVENT_PHASE + PHASE_*` allowed) |
| `MAYHEM.OnStartup(op)` | runs once before opening hands are drawn |
| `MAYHEM.SetPlayerRules{ lp=, hand=, draw= }` | starting LP / opening hand / per-turn draw; **startup only** |
| `MAYHEM.Log(msg)` | progress note, only when `debug` is on in the config |
| `MAYHEM.Warn(msg)` | a real problem; always reported |

There is **no** player-facing text channel. `Debug.ShowHint` looks like one but
`duelclient.cpp` has 97 `case MSG_` arms and none of them is `MSG_SHOW_HINT`, so
the message is dropped. The visible confirmation is the life point counter.

Effect codes already proven to work here: `EFFECT_SPSUMMON_COUNT_LIMIT` (needs
`Duel.EnableGlobalFlag(GLOBALFLAG_SPSUMMON_COUNT)` first), `EFFECT_DRAW_COUNT`,
`EFFECT_CANNOT_ACTIVATE`, `EFFECT_CANNOT_SPECIAL_SUMMON`. Look up anything else in
`<game>\script\constant.lua` and copy the idiom from a real card in
`<game>\script\official\` before using it — target-range and property conventions differ
per effect code.

## Hard constraints

- **Flat files only, in the install.** `Duel.LoadScript` rejects any name
  containing `/` or `\`, and EDOPro only scans `expansions/script/` one level
  deep. `src/` is split for readability and flattened on the way out:
  `src/runtime/*.lua` keep their names, `src/cores/<id>.lua` becomes
  `mayhem_core_<id>.lua` (the name `MAYHEM.ApplyCore` derives from the id).
  `install.ps1`, `make-package.py` and `test-cores.lua` all encode that mapping —
  change one, change all three.
- **No `require`, no module returns.** Cores register themselves into the global
  `MAYHEM` table when loaded.
- **The clock is not scriptable.** Time limit is a room setting the host picks;
  record it under `room_settings` in `cores.json` instead of faking it.
- **Deck construction is client-side.** Extra Deck / Main Deck size rules cannot
  block deck building; they are enforced as a startup check that ends the game.
- **Never touch stock client state.** No overriding EDOPro's card scripts, game
  modes or interface strings. A Mayhem install must leave the client usable for
  normal play, and `tools\uninstall.ps1` must be able to put it back exactly.
  Anything `install.ps1` creates, `uninstall.ps1` removes; test both directions.
  Never hardcode a game folder: resolve it through `tools\resolve-game-path.ps1`
  (PowerShell) or `resolve_game_path()` (Python), which fail loudly rather than
  guess.
  Never delete a file the plugin did not write — `init.lua` is checked for
  ownership, and a foreign one is left alone.
- **The encoded LP must never survive** into the duel, valid code or not.
- A missing or empty config must leave the duel on stock rules. Keep the bootstrap
  fail-soft — it runs in every casual and AI game too.
- **Fail-soft is not fail-silent.** EDOPro scans for `init.lua` and
  `expansions/script/` once at startup, so an install into a running client is
  invisible until it restarts. Anything that stops the plugin loading must say so
  through `Debug.Message`; only routine progress is allowed to be quiet.
- Never edit `install/generated/` by hand; it is wiped on every generator run.

## Verifying for real

Two layers:

- `lua tools/test-cores.lua` — offline, about a second, proves the Lua wiring
  against the client's real `constant.lua`.
- `python tools/run-duel.py --code <n>` — loads the client's own `ocgcore.dll`,
  replicates `Game::SetupDuel`, and prints what the engine actually did. This is
  the layer that proves an effect is accepted. EDOPro is 32-bit, so it needs a
  32-bit interpreter: `uv python install cpython-3.12-windows-x86`, then run the
  script with that interpreter.

In the client, `MAYHEM.Log` is off unless `debug = true` in the installed
`mayhem_config.lua`. That default matters: EDOPro labels every script message
"Script Error" and, when `coreLogOutput` in `<game>\config\system.conf` includes
the chat bit (`3` = chat + file), prints it in red in the duel chat. Routine
progress notes must never appear there — use `MAYHEM.Warn` only for genuine
problems, and `MAYHEM.Announce` for anything the player should see.

`run-duel.py` serves its own config with `debug = true`, so it still sees
everything; `--real-config` uses the installed one to show exactly what a player's
client would print.

## Layout

```
cores.json          registry: code -> sheet name, script, params, room settings
src/runtime/        the framework: bootstrap, engine helpers, operator config
src/cores/          one mutation core per file; the file name is the core id
install/            init.lua entry point, banlist sources
install/generated/  mayhem_catalogue.lua (do not edit)
tools/              install.ps1, uninstall.ps1, resolve-game-path.ps1,
                    build-catalogue.py, make-package.py, list-codes.py,
                    build-banlist.py, test-cores.lua, run-duel.py
dist/               portable zips from make-package.py (gitignored)
.game-path          which EDOPro install this machine targets (gitignored)
docs/               writing-a-core.md (how to add rules),
                    edopro-integration.md (verified engine findings)
```
