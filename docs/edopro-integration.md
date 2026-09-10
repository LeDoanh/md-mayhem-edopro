# EDOPro integration — verified findings

How the mutation cores attach to EDOPro, and the evidence behind each claim.
Verified 2026-09-09 against the client at `F:\Game\ProjectIgnis` (build 2026-04-20)
and the upstream sources `edo9300/edopro` and `edo9300/ygopro-core`.

## 1. Where a custom rule can attach

Four extension points exist. Only one is needed.

| Hook | How it loads | Verdict |
| --- | --- | --- |
| `<game>/init.lua` | `Game::PopulateResourcesDirectories` adds it to `init_scripts`; `Game::SetupDuel` loads every entry after `constant.lua` + `utility.lua` | **used** — no registration, no card database, runs every duel |
| `<repo>/script/init.lua` | same list, added per registered repo in `config/configs.json` | alternative for git-distributed installs |
| `proc_unofficial.lua` | `utility.lua` ends with `Duel.LoadScript("proc_unofficial.lua")`; the file ships nowhere, so it is a deliberate empty slot | usable, but it is a shared name other add-ons may claim |
| `pcall(dofile,"init.lua")` at the end of `utility.lua` | works only because EDOPro passes `enableUnsafeLibraries = 1`; `ygopro-core/interpreter.cpp` nils `dofile` otherwise | **avoid** — silently dead on any core built without that option |

`Game::SetupDuel` is the single duel factory: `generic_duel.cpp` (hosted/net play)
and `single_mode.cpp` (solo, AI) both call it, so the same hook covers every mode.

**The scan happens once, at startup.** `PopulateResourcesDirectories()` runs from
the `Game` constructor (game.cpp:153) and fixes both `init_scripts` and
`script_dirs` for the whole session. A client that was already open when the
plugin was installed never sees it: `./init.lua` is not in `init_scripts`, or
`expansions/script/mdmayhem/` is not in `script_dirs`, and the duel silently runs
stock rules with the typed code left sitting in the life points. `init.lua`
therefore reports a failed `Duel.LoadScript` through `Debug.Message`, and
install.ps1 warns when EDOPro is running.

Consequence for tournaments: **only the host installs the plugin.** The duel core
runs on the hosting client; the opponent's client only renders messages. Anyone
replaying the match file locally needs the plugin to reproduce it.

**But only LAN-hosted rooms run the core locally.** `BUTTON_HOST_CONFIRM` in
`menu_handler.cpp` branches on `isHostingOnline`:

| Menu path | `isHostingOnline` | Who runs the duel core |
| --- | --- | --- |
| Online Multiplayer -> host a room | `true` -> `ServerLobby::JoinServer(true)` | the remote server |
| LAN mode -> Create Host | `false` -> `NetServer::StartServer` + connect to 127.0.0.1 | this client |

A room hosted through any server lobby runs on that server's core with that
server's scripts, so the plugin has no effect there and cannot even report the
fact - it is never loaded. Matches must be played in LAN mode, direct to the
referee's machine. Solo mode is no good either: `single_mode.cpp` takes its LP
from the puzzle script, not the Host window.

## 2. How a rule is expressed

`Effect.GlobalEffect()` creates an effect owned by no card, and
`Duel.RegisterEffect(effect, 0)` puts it on the field for the whole duel. Stock
precedent: `proc_skill.lua` registers its drawless effect exactly this way at file
scope, and `Auxiliary.BeginPuzzle` in `utility.lua` installs a set of global field
effects the same way.

This is why the plugin needs no custom cards, no `.cdb` rows and no deck slot.

## 3. What the engine can and cannot enforce

| Rule shape | Mechanism | Enforceable |
| --- | --- | --- |
| Starting LP | `Debug.SetPlayerInfo` + `Duel.SetLP` at `EVENT_STARTUP` | yes |
| Opening hand size | `Debug.SetPlayerInfo` at `EVENT_STARTUP` (idiom taken from `proc_skill.lua`) | yes |
| Per-turn draw count | `EFFECT_DRAW_COUNT` field effect | yes |
| Max Special Summons per turn | `EFFECT_SPSUMMON_COUNT_LIMIT` + `Duel.EnableGlobalFlag(GLOBALFLAG_SPSUMMON_COUNT)` | yes — the core blocks the summon itself |
| Ban a card *type* from activating | `EFFECT_CANNOT_ACTIVATE` with a value function | yes |
| Ban handtraps | `EFFECT_CANNOT_ACTIVATE` filtered on `LOCATION_HAND` | yes, and it never goes stale |
| Periodic LP swing | `EVENT_PHASE_START + PHASE_STANDBY` trigger + `Duel.Recover` | yes — `EVENT_PHASE` must not be used, see below |
| Alternate win condition | `EVENT_BATTLE_DAMAGE` trigger + `Duel.Win` | yes |
| Deck-size limits (Extra ≤ N, Main ≥ N) | deck validation is client-side and not extensible; enforced instead as a startup check that ends the game | partially — after the duel starts, not in the deck editor |
| Ban specific cards | `lflists/*.lflist.conf`, chosen per room | yes |
| Turn timer | room setting only, no Lua surface | **no** — host must set it |

The original tournament brief assumed manual counting and replay review for the
Special-Summon quota. That is unnecessary: `EFFECT_SPSUMMON_COUNT_LIMIT` is an
engine rule, so an over-quota summon simply cannot be declared.

### Why a core hooks phases through `EVENT_PHASE_START`

A core's effects belong to no card: `Effect.GlobalEffect` hands them the field's
`temp_card`, whose location is `0`. That is invisible for a rule the engine only
evaluates, but not for one it has to *offer*.

`Processors::PhaseEvent` (`processor.cpp:328`) pushes every continuous effect
listening on `EVENT_PHASE + phase` into `core.select_chains`. With one entry and
nothing else triggering, `processor.cpp:424` auto-selects it and the rule just
runs — which is why this shape survives casual testing. With anything else in
that phase the engine emits `Processors::SelectChain`, and `playerop.cpp:489`
writes `peffect->get_handler()->get_info_location()` into `MSG_SELECT_CHAIN`.
Two things then go wrong: the mutation rule is presented as a choice the player
can decline, and the packet names a card at location `0`. WindBot's
`Duel.GetCard` has no case for that location, returns null, and
`GameBehavior.OnSelectChain` dereferences it:

```
Tick Error: System.NullReferenceException
   at WindBot.Game.GameBehavior.OnSelectChain(BinaryReader packet)
```

`EVENT_PHASE_START + PHASE_*` avoids both. It is raised straight after
`MSG_NEW_PHASE` and drained by `process_instant_event`, and `processor.cpp:1218`
skips the whole `EVENT_PHASE_START` band when it builds trigger chains, so the
effect resolves as a continuous chain with nothing to select. `MAYHEM.OnPhase`
is the only phase hook a core should use.

One gap in that band: `PHASE_BATTLE` never raises a start event. The Battle
Phase is opened by `EVENT_PHASE_START + PHASE_BATTLE_START`
(`processor.cpp:3482`); `PHASE_BATTLE` only gets the `PhaseEvent` window that
closes it.

### Which callback the core reads a restriction from

A restriction is only conditional if the engine actually calls the function
holding the condition, and the callback differs per effect code. Verified
against `edo9300/ygopro-core` (the core EDOPro builds from) at the lines named
below; the offline harness cannot catch a mistake here, because a stub records
whatever it is handed.

| Effect code | Collected by | Condition read from | Consequence of the wrong one |
| --- | --- | --- | --- |
| `EFFECT_CANNOT_SUMMON` | `field::is_player_can_summon` (`field.cpp:2744`) | `target(e, card, player, sumtype, sumpos, toplayer)` | `if(!peff->target) return FALSE` — no target means no summons at all |
| `EFFECT_CANNOT_FLIP_SUMMON` | `field::is_player_can_flipsummon` | `target(e, card, player)` | same blanket ban |
| `EFFECT_CANNOT_SPECIAL_SUMMON` | `field::is_player_can_spsummon` (`field.cpp:2815`, `2845`) | `target(e, card, player, sumtype, sumpos, toplayer, re, proc)` | same blanket ban, and the "can this player Special Summon at all" probe fails too |
| `EFFECT_CANNOT_ACTIVATE` | `effect::is_action_check` (`effect.cpp:308`) | `value(e, activating_effect, player)` | a target is ignored; the ban never applies |
| `EFFECT_CANNOT_INACTIVATE`, `EFFECT_CANNOT_DISEFFECT` | `field::is_chain_negatable` / `is_chain_disablable` | `value(e, chain_count)` | as above |
| `EFFECT_CANNOT_DRAW` | `field::is_player_can_draw` -> `is_player_affected_by_effect` | nothing — presence only | any such effect bans every non-`REASON_RULE` draw for the whole duel |
| `EFFECT_CANNOT_TO_HAND`, `EFFECT_CANNOT_ATTACK_ANNOUNCE`, `EFFECT_IMMUNE_EFFECT` | `card::is_affected_by_effect` / `filter_effect` | `target(e, card)` picks the cards, `value` decides the outcome | a card-scoped rule with no target hits every card |
| `EFFECT_ACTIVATE_COST` | `filter_player_effect` (`effect.cpp:316`, `processor.cpp:3643`) | `target(e, te, player)` gates it, `cost(e, te, player)` checks, `operation(e, player)` pays | needs `EFFECT_FLAG_PLAYER_TARGET`, or it is never collected |
| `EFFECT_SPSUMMON_COST` | `card::check_cost_condition` -> `card::filter_effect` (`card.cpp:3078`) | `cost(e, card, player, sumtype)`, `operation(e, player)` | must **not** have `EFFECT_FLAG_PLAYER_TARGET`: `filter_effect` only takes aura effects without it |

`card::filter_effect` and `card::is_affected_by_effect` both end by walking
`game_field->effects.aura_effect` and accepting an entry when
`!is_flag(EFFECT_FLAG_PLAYER_TARGET) && is_target(this)` — that is why a global
field effect can carry a per-card rule at all, and why the same effect cannot
serve a player-scoped and a card-scoped code at once.

## 4. Path rules that shape the layout

- `Duel.LoadScript` raises `"Passed script name containing a path separator"` for
  any name with `/` or `\` (`ygopro-core/libduel.cpp`). Plain file names only.
- `Game::FindScript` searches, in order: registered repo script paths → their
  subfolders (depth 2) → `./expansions/script/` → its subfolders (**depth 1**) →
  archives → `./script/` → its subfolders. `expansions/script/mdmayhem/` is
  therefore reachable; a folder nested one level deeper is not.
- Banlists load from `./expansions/lflist.conf`, `./lflist.conf` and every `.conf`
  in `./lflists/` (`DeckManager::LoadLFList`). `$whitelist` is supported.

## 5. Per-match core selection without patching the client

Only `seed`, the duel-flag bitmask and each team's `{startingLP, startingDrawCount,
drawCountPerTurn}` travel from the room settings into the duel core
(`OCG_DuelOptions`). There is no free-text field, so the selection has to ride on
something the host already types.

**Starting LP is the channel.** `host_info.start_lp` is a `uint32_t`, parsed from
the edit box with `std::stoul` and never clamped, then handed straight to
`OCG_Player.startingLP`. A host typing `1000000 + code` selects a catalogue entry;
the bootstrap decodes it at load time, calls `Debug.SetPlayerInfo` to put real
life points back, and applies the entry. Verified against the client's own
`ocgcore.dll`: LP `1000007` produced `code 7` and `lp 4000/4000`.

Properties that matter:

- **Unbounded.** The catalogue is a plain table; codes are permanent ids from
  `cores.json`.
- **Nothing in the client is modified** - no card scripts, no game modes, no
  interface strings. `Mayhem-codes.txt` beside `EDOPro.exe` is the lookup.
- The cost is discoverability: there is no control to click. Adding one means
  editing `chkCustomRules[32]` / `wtcCreateHost` in C++, i.e. forking and
  rebuilding EDOPro.exe.
- An unrecognised code is logged and the duel falls back to the default LP, so a
  typo cannot leak `1000099` into the game as real life points.
- Cosmetic cost: the room list shows the encoded number until the duel starts.

### Rejected: the Extra Rules checkbox panel

The Host window's Duel tab has an "Extra Rules" button (`btnRuleCards`, sysstring
1625) opening 13 checkboxes. Ticking box *i* sets bit `1 << i` of `extra_rules`
(`network.h`), makes `generic_duel.cpp` inject a fixed card code, and the core
loads that card's script. It works - it is how this plugin first shipped - but it
costs EDOPro's 13 stock modes (Sealed Duel, Battle City, Action Duel, ...) and
caps the library at 13. Both were unacceptable, so it was removed.

One finding from that attempt is worth keeping, because it is the general escape
hatch for shadowed scripts: `interpreter::load_card_script` does
`lua_getglobal("c<code>")` and **returns immediately if that global already
exists**, never consulting the script reader. Defining `c<code>` from `init.lua`
therefore beats every script folder - including registered update repos such as
delta-bagooska, whose `script_path` is inserted at the *front* of `script_dirs`
(`game.cpp`) and which silently shadowed our card files on the first attempt.

## 6. Room settings that still belong to the host

These have no Lua surface and stay in the host's hands, tracked per core under
`room_settings` in `cores.json`:

- **Time Limit** — the only hard gap.
- Starting LP / Starting Hand / Draw Count — settable from the room too, but the
  plugin overrides them so a core stays self-contained.
- Duel flags (`DUEL_*` in `constant.lua`, e.g. `DUEL_NO_MAIN_PHASE_2`,
  `DUEL_UNLIMITED_SUMMONS`) — exposed in the host window; a future core family
  could be documented against these rather than scripted.

## 7. What an install touches

Everything `tools/install.ps1` writes, and what `tools/uninstall.ps1` takes back:

| Path | Notes |
| --- | --- |
| `expansions/script/mdmayhem/` | the plugin; a stock client has no `expansions/script/` at all, so the parent is removed too when it ends up empty |
| `init.lua` | the duel entry point. A pre-existing foreign one is moved to `init.lua.bak` on install and restored on uninstall; an `init.lua` that is not ours is never deleted |
| `lflists/Mayhem_Tactical.lflist.conf` | generated banlist |
| `Mayhem-codes.txt` | the printable code list, beside `EDOPro.exe` |
| `expansions/strings.conf` | not written any more. Both scripts strip a `# >>> MD Mayhem` block left by older versions and delete the file if nothing else was in it |

`uninstall.ps1` supports `-WhatIf` for a dry run and is idempotent. If another
tool replaces `init.lua` after Mayhem was installed, uninstall preserves both
that newer file and `init.lua.bak` instead of overwriting either one. Ownership
requires an exact hash match with the shipped entry point; merely mentioning
`mayhem_bootstrap.lua` is not enough because a shared loader may mention it too.

Neither script hardcodes a game folder. `tools/resolve-game-path.ps1` takes an
explicit `-GamePath`, else the path remembered in `<repo>/.game-path`, else it
globs `EDOPro.exe` up to three levels under each fixed drive and asks which to
use. A non-interactive run never prompts: it takes a single unambiguous match and
otherwise fails naming the candidates, so a script cannot install into the wrong
client. The Python tools read the same `.game-path`.

## 8. Other platforms

The selection mechanism is platform-independent:

- `Game::PopulateResourcesDirectories` and `Game::SetupDuel` are in shared
  `gframe/game.cpp`; `./init.lua` is picked up on every build.
- `OCG_Player.startingLP` is a `uint32_t` in the C API, so the code channel works
  the same everywhere.
- Android uses ordinary POSIX paths for the game folder (`mkdir`, `open` in
  `utils.cpp`); its Storage Access Framework helpers in
  `gframe/Android/porting_android.cpp` are only used for URI paths such as deck
  import/export. Its working directory comes from a `-work-dir` argument the Java
  activity passes (`gframe.cpp`, `porting_android.cpp: GetExtraParameters`), so
  the folder is app-specific rather than a fixed path.
- Filenames are all lowercase, which matters on case-sensitive filesystems.

The portable zip cannot inspect its extraction target. Before extracting it, a
host moves any pre-existing `init.lua.bak` out of the game folder and preserves
it separately, then renames the current root `init.lua` to `init.lua.bak`. The
packaged README carries the same preflight and restoration instructions.

`python tools/make-package.py` builds `dist/mdmayhem-<version>.zip` laid out
exactly as the files sit in the game folder; extracting it over that folder is a
complete install, verified by wiping the Windows client and installing from the
zip alone.

**Not verified on a device.** The exact Android data folder, and whether a file
manager can reach it without a PC, is untested here.

## 9. Verification

`lua tools/test-cores.lua` runs the real bootstrap against stub engine globals,
loading the client's actual `constant.lua` so the assertions use real effect
numbers. It proves wiring, not engine acceptance — that still needs one hosted
duel (an AI game is enough) per new effect code. When `debug = true`,
`MAYHEM.Log` writes `[MAYHEM]` lines to `<game>\error.log` for after-the-fact
checks; `run-duel.py` enables debug in its synthetic config by default.

## Open questions

- The Android data folder, and whether a file manager can reach it without a PC.
