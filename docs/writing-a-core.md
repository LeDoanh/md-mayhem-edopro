# Writing a mutation core

A **core** is one duel rule — "at most 5 Special Summons per turn", "the first
player to take battle damage loses". One core is one file in `src/cores/`, and
the file name is the core's id.

This is the practical guide. `edopro-integration.md` records *why* the plumbing
looks the way it does; read that once before changing anything under
`src/runtime/`.

## What a core actually is

A table with an `apply` function, registered under an id:

```lua
MAYHEM.Register("my_core", {
    defaults = { some_number = 5 },   -- optional, overridden per catalogue entry
    apply = function(params)          -- required
        -- install the rule here
    end,
})
```

`apply` runs once, at duel setup, before the opening hands are drawn. Its job is
to install **global effects** — effects owned by no card
(`Effect.GlobalEffect()` + `Duel.RegisterEffect`). That is why the plugin needs
no custom cards, no `.cdb` rows and no deck slots, and why the opponent does not
have to install anything: only the host runs the duel core.

`params` is `defaults` merged with the catalogue entry's `params`, so the same
core file serves every tier of a mutation. `high_friction` is one file and
covers both `Hạn Điền Bạc` (7 summons) and `Hạn Điền Vàng` (5).

## The loop

```bash
# 1. write the core
$EDITOR src/cores/my_core.lua

# 2. add a cores.json entry with the next unused code

# 3. regenerate the catalogue (fails if the file is missing)
python tools/build-catalogue.py

# 4. offline check, about a second
lua tools/test-cores.lua

# 5. install
powershell -ExecutionPolicy Bypass -File tools\install.ps1

# 6. prove the engine accepts it (32-bit Python)
python tools/run-duel.py --code <code>
```

Step 6 is the one that matters. The offline harness proves your Lua is wired
correctly; only `run-duel.py` proves the **engine** accepts the effect, because
it loads the client's own `ocgcore.dll` and replays `Game::SetupDuel`.

## Anatomy

`src/cores/high_friction.lua`, in full:

```lua
-- Han Dien / High Friction - hard cap on Special Summons per turn, per player.
--
-- EFFECT_SPSUMMON_COUNT_LIMIT is the same engine rule "Vanity's Fiend"-style
-- cards use, so the core counts and blocks by itself. No manual counting, no
-- replay review: an illegal Special Summon simply cannot be declared.
MAYHEM.Register("high_friction", {
    defaults = { max_special_summons = 5 },
    apply = function(params)
        -- The core only tracks per-turn Special Summon counts when asked to.
        Duel.EnableGlobalFlag(GLOBALFLAG_SPSUMMON_COUNT)
        MAYHEM.FieldRule(EFFECT_SPSUMMON_COUNT_LIMIT, params.max_special_summons, true)
    end,
})
```

Three things to copy from it:

- The header says what the rule *is* in one line, then why this mechanism.
  Someone reading `cores.json` already knows the name; the file explains the
  choice.
- Every tunable number is a `defaults` key, never a literal in `apply`.
- Engine quirks get a comment where they bite. `EnableGlobalFlag` is not
  obvious, so it is explained on the spot.

Keep cores under about 25 lines. If one grows past that, the mechanism probably
belongs in `src/runtime/mayhem_engine.lua` as a helper.

## Helpers

All of these live on the global `MAYHEM` table, from `src/runtime/mayhem_engine.lua`.

| Helper | Use for |
| --- | --- |
| `MAYHEM.FieldRule(code, value, player_target)` | a permanent rule on both players |
| `MAYHEM.OnEvent(event, op, countlimit)` | a duel-wide trigger |
| `MAYHEM.OnStartup(op)` | run once before the opening hands are drawn |
| `MAYHEM.SetPlayerRules{ lp=, hand=, draw= }` | starting LP / opening hand / per-turn draw — **startup only** |
| `MAYHEM.Log(msg)` | progress note; silent unless `debug = true` in the config |
| `MAYHEM.Warn(msg)` | a real fault; always reported |
| `MAYHEM.WIN_REASON` | the win reason id to pass to `Duel.Win` |

`player_target` on `FieldRule` is not cosmetic: effects the core reads off a
player (`EFFECT_DRAW_COUNT`, `EFFECT_SPSUMMON_COUNT_LIMIT`) need
`EFFECT_FLAG_PLAYER_TARGET`, and effects like `EFFECT_CANNOT_ACTIVATE` must not
have it. Copy whichever the stock card scripts use — see *Finding an effect
code* below.

## Recipes

Every shape below is already implemented; open the named file for the full
version.

**A permanent numeric limit** — `high_friction`, `thrift`

```lua
MAYHEM.FieldRule(EFFECT_DRAW_COUNT, params.draw, true)
```

**A ban on activating something** — `sealed_magic`

```lua
MAYHEM.FieldRule(EFFECT_CANNOT_ACTIVATE, function(e, re, tp)
    return re:GetHandler():IsType(TYPE_SPELL)
end)
```

Returning `true` blocks the activation. The same shape bans handtraps by
filtering on `re:GetHandler():IsLocation(LOCATION_HAND)` — by position, so no
card list can go stale.

**Something every turn** — `energy_surge`

```lua
MAYHEM.OnEvent(EVENT_PHASE + PHASE_STANDBY, function()
    Duel.Recover(Duel.GetTurnPlayer(), params.amount, REASON_RULE)
end)
```

**An alternate win condition** — `first_blood`

```lua
-- ep is the player the battle damage was dealt to.
MAYHEM.OnEvent(EVENT_BATTLE_DAMAGE, function(e, tp, eg, ep)
    Duel.Win(1 - ep, MAYHEM.WIN_REASON)
end, 1)
```

The trailing `1` is a count limit: fire once per duel. Leave it off for a
trigger that should repeat.

**Changed starting resources** — `speed_blitz`, `resource_starvation`

```lua
MAYHEM.OnStartup(function()
    MAYHEM.SetPlayerRules({ lp = params.lp })
end)
```

Must be inside `OnStartup`: it rewrites raw player state and the opening draw
has not happened yet.

**A deck-construction rule** — `extra_embargo`

EDOPro's deck checker is client-side and not extensible, so size limits cannot
block deck building. Enforce them as an automatic referee call instead:

```lua
MAYHEM.OnStartup(function()
    for player = 0, 1 do
        if Duel.GetFieldGroupCount(player, LOCATION_EXTRA, 0) > params.max_extra then
            MAYHEM.Warn("player " .. player .. " lost: extra deck too large")
            Duel.Win(1 - player, MAYHEM.WIN_REASON)
            return
        end
    end
end)
```

**Not possible from a core:** the turn timer. It is a room setting with no Lua
surface. Record it under `room_settings` in `cores.json` and let the host set
it; do not fake it.

## Wiring it into the catalogue

Add one entry per *sheet* mutation to `cores.json` — tiers are separate entries
pointing at the same script:

```json
{
  "sheet_name": "Hạn Điền Vàng",
  "code": 8,
  "tier": "Vang",
  "status": "implemented",
  "script": "high_friction",
  "params": { "max_special_summons": 5 }
}
```

- `code` is **permanent**. It is what a host types into Starting LP, and it may
  end up printed on a tournament sheet. Always take the next unused number;
  never renumber, never reuse.
- `sheet_name` must match the Name column in `../web-app/public/mutations.xlsx`
  exactly — that is the join between the roller and the plugin.
- `script` is the file stem in `src/cores/`. There is no registry to update:
  `build-catalogue.py` reads the folder and fails if the file is missing.
- `status: "planned"` documents a core that has no script yet. It is skipped by
  the generator and its code stays reserved.
- `status: "partial"` keeps a selectable entry while marking it prominently in
  `Mayhem-codes.txt`; any manual room settings and missing component cores are
  printed beside it so a host cannot mistake it for a fully enforced rule.
- `also_needs: ["other_core"]` applies a second core with the same entry, for
  mutations that are a composite. A missing component is allowed only while the
  entry is `partial`; an `implemented` entry fails catalogue generation.

## Finding an effect code you do not know

Do not guess constants, and do not trust a remembered idiom. The method that
works:

1. Grep `<game>\script\constant.lua` for a plausible `EFFECT_` name.
2. Grep `<game>\script\official\` for that constant to find a real card using it.
3. Copy that card's exact idiom — target range, property flags, whether it needs
   an `EnableGlobalFlag` first. These conventions differ per effect code and
   getting them wrong usually fails silently rather than erroring.

`EFFECT_SPSUMMON_COUNT_LIMIT` is the cautionary example: it does nothing at all
unless `Duel.EnableGlobalFlag(GLOBALFLAG_SPSUMMON_COUNT)` was called first, and
nothing warns you.

Codes already proven to work in this plugin: `EFFECT_SPSUMMON_COUNT_LIMIT`,
`EFFECT_DRAW_COUNT`, `EFFECT_CANNOT_ACTIVATE`, `EFFECT_CANNOT_SPECIAL_SUMMON`.

## Testing

Add a case to `tools/test-cores.lua`. The harness runs the real bootstrap
against stub `Duel` / `Effect` / `Debug` globals, loading the client's actual
`constant.lua` so assertions use real effect numbers:

```lua
tests["high_friction caps special summons and enables the counter"] = function()
    run({ enabled = { "high_friction" } }, nil)
    assert(recorder.flags[GLOBALFLAG_SPSUMMON_COUNT], "spsummon counter not enabled")
    local effect = effect_with(EFFECT_SPSUMMON_COUNT_LIMIT)
    assert(effect and effect.value == 5, "wrong limit")
end
```

Available in a test:

| | |
| --- | --- |
| `run(config, starting_lp)` | boots the plugin; pass `base + code` to exercise a catalogue entry |
| `effect_with(code)` | the registered effect with that `EFFECT_`/`EVENT_` code |
| `called(name)` | the first recorded call, e.g. `"Duel.SetLP"`, with `.args` |
| `fire_startup()` | runs the `EVENT_STARTUP` operation |
| `recorder.flags` | what `Duel.EnableGlobalFlag` was called with |

Then confirm against the engine:

```bash
python tools/run-duel.py --code 8            # what the plugin did
python tools/run-duel.py --code 8 --verbose  # core message ids per step
python tools/run-duel.py --code 8 --real-config   # what a player's client prints
```

Finally, one real duel: **LAN mode → Create Host**, Starting LP = `1000000 +
code`. Life points snapping from the typed code to the real value is the signal
that the plugin ran.

## Traps

Each of these cost real debugging time. They are listed in the order they tend
to bite.

- **The life point counter is not the core's LP.** The host builds `MSG_START`
  itself from the number typed into the box, so a core changing LP through
  `Debug.SetPlayerInfo` alone is invisible on screen. `SetPlayerRules` and
  `SetStartingLP` already re-broadcast with `Duel.SetLP`; if you write a new LP
  path, do the same.
- **There is no way to show a player text.** `Debug.ShowHint` exists but
  `duelclient.cpp` has no handler for `MSG_SHOW_HINT`, so it is dropped. Use LP
  changes as the visible signal.
- **`MAYHEM.Log` is silent by default.** EDOPro labels every script message
  "Script Error" and prints it in red in the duel chat, so routine notes must
  stay off. Use `MAYHEM.Warn` only for genuine faults.
- **Only LAN-hosted rooms run your code.** A room hosted through Online
  Multiplayer runs on the remote server, where the plugin does not exist and
  cannot even report that it is missing. Solo mode takes its LP from the puzzle
  script, so it is not a valid test either.
- **EDOPro scans for scripts once, at startup.** Installing into a running
  client does nothing until it restarts.
- **The install is flat.** `src/cores/<id>.lua` ships as
  `mayhem_core_<id>.lua`; `Duel.LoadScript` rejects path separators and EDOPro
  scans `expansions/script/` only one level deep.
- **No `require`, no module returns.** Cores register themselves into the global
  `MAYHEM` table when the file is loaded.
- **Two catalogue entries must not apply the same core twice.** The bootstrap
  refuses the second and warns, so behaviour stays deterministic — but the rule
  you wanted may not be the one that won.

## Exercises

Four cores are specified in `cores.json` but not written. Each entry carries its
`mechanism` field, which is the intended approach:

| Code | Mutation | Shape |
| --- | --- | --- |
| 11 | Lực Hút Vàng | startup validator on `LOCATION_DECK`, same shape as `extra_embargo` |
| 14 | handtrap lock | `EFFECT_CANNOT_ACTIVATE` filtered on `LOCATION_HAND` |
| 17 | Trống Rỗng | `EFFECT_CANNOT_SPECIAL_SUMMON` filtered on previous location `LOCATION_EXTRA` |
| 19 | Tuyệt Vọng | `EFFECT_CANNOT_SPECIAL_SUMMON` for both players |

17 and 19 have stopgaps available today (`extra_embargo` with `max_extra` 0, and
`high_friction` with `max_special_summons` 0), but blocking the summon reads
better in play than an instant loss, which is why each gets its own script.
