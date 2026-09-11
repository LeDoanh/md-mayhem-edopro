# Writing a mutation core

A **core** is one duel rule — "at most 5 Special Summons per turn", "the first
player to take battle damage loses". One core is one file in `src/cores/`, and
the file name is the core's id. Catalogue cores use `<code>_<slug>.lua` so the
LP code is visible while browsing files. The generated catalogue keeps aliases
for pre-prefix operator configs, so an old `enabled = { "energy_dominate" }`
still resolves to `56_energy_dominate`.

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

`params` is `defaults` merged with the catalogue entry's `params`, so one core
file can serve catalogue variants without embedding tournament values in Lua.

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

Step 6 checks what the offline harness cannot: whether the **engine** accepts
the effect. `run-duel.py` loads the client's own `ocgcore.dll` and replays
`Game::SetupDuel`; the source-tree engine regressions below use that DLL too.

## Anatomy

The numeric Monster Zone limit from `src/cores/30_be_more_efficient.lua`
(its Spell/Trap limit needs additional handling; see the traps below):

```lua
-- Minimal example of a numeric Monster Zone limit.
MAYHEM.Register("30_be_more_efficient", {
    defaults = { monster_zones = 3 },
    apply = function(params)
        MAYHEM.FieldRule(EFFECT_MAX_MZONE, params.monster_zones, true)
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
| `MAYHEM.PlayerRestriction(code, predicate)` | a summon ban, whose predicate the core reads as a *target* |
| `MAYHEM.OnEvent(event, op, countlimit)` | a duel-wide trigger |
| `MAYHEM.OnPhase(phase, op)` | work at the start of a phase — the only safe way to hook one |
| `MAYHEM.OnStartup(op)` | run once before the opening hands are drawn |
| `MAYHEM.SetPlayerRules{ lp=, hand=, draw= }` | starting LP / opening hand / per-turn draw — **startup only** |
| `MAYHEM.Log(msg)` | progress note; silent unless `debug = true` in the config |
| `MAYHEM.Warn(msg)` | a real fault; always reported |
| `MAYHEM.AnnounceEnergy(player, value, max, reason)` | Energy Dominate number hint + requested chat line |
| `MAYHEM.WIN_REASON` | the win reason id to pass to `Duel.Win` |

`player_target` on `FieldRule` is not cosmetic: effects the core reads off a
player (`EFFECT_DRAW_COUNT`, `EFFECT_SPSUMMON_COUNT_LIMIT`) need
`EFFECT_FLAG_PLAYER_TARGET`, and effects like `EFFECT_CANNOT_ACTIVATE` must not
have it. Copy whichever the stock card scripts use — see *Finding an effect
code* below.

`FieldRule` installs the rule as the effect's **value**, which is where most
codes are read from. Three summon bans are read from the effect's **target**
instead, so they use `PlayerRestriction`: `EFFECT_CANNOT_SUMMON`,
`EFFECT_CANNOT_FLIP_SUMMON` and `EFFECT_CANNOT_SPECIAL_SUMMON`. The trap list
explains why choosing the wrong one fails silently.

## Recipes

Every shape below is already implemented; open the named file for the full
version.

**A permanent numeric limit** — `30_be_more_efficient`

```lua
MAYHEM.FieldRule(EFFECT_MAX_MZONE, params.monster_zones, true)
```

**A ban on activating something** — `51_quick_play_owner_turn`

```lua
MAYHEM.FieldRule(EFFECT_CANNOT_ACTIVATE, function(e, re, tp)
    return re:GetHandler():IsType(TYPE_QUICKPLAY)
end)
```

Returning `true` blocks the activation. The same shape bans handtraps by
filtering on `re:GetHandler():IsLocation(LOCATION_HAND)` — by position, so no
card list can go stale.

**A ban on summoning something** — `26_there_can_be_only_one_kind`

```lua
MAYHEM.PlayerRestriction(EFFECT_CANNOT_SPECIAL_SUMMON, function(e, card, player)
    return card:IsLocation(LOCATION_EXTRA) and used[player + 1]
end)
```

Returning `true` blocks the summon. `EFFECT_CANNOT_SUMMON` and
`EFFECT_CANNOT_FLIP_SUMMON` pass the same first three arguments, so a single
predicate can serve all three codes.

**Something every turn** — `47_back_from_the_grave`

```lua
MAYHEM.OnPhase(PHASE_END, function()
    -- select and Special Summon one legal monster from each player's GY
end)
```

Always `OnPhase`, never `OnEvent(EVENT_PHASE + PHASE_x, ...)` — see the trap
list. The op runs once per phase, for whichever player's turn it is, so loop
over both players yourself when the rule is symmetric.

**An alternate win condition** — `37_create_your_own_victory`

```lua
MAYHEM.OnEvent(EVENT_ADJUST, function()
    -- evaluate the five-name / three-copies board condition, then Duel.Win
end)
```

The trailing `1` is a count limit: fire once per duel. Leave it off for a
trigger that should repeat.

**Changed starting resources** — `32_you_have_to_be_quick`

```lua
MAYHEM.OnStartup(function()
    MAYHEM.SetPlayerRules({ lp = params.lp })
end)
```

Must be inside `OnStartup`: it rewrites raw player state and the opening draw
has not happened yet.

**A deck-construction rule** — `25_this_sound_familiar`

EDOPro's deck checker is client-side and not extensible, so size limits cannot
block deck building. Enforce them as an automatic referee call instead:

```lua
MAYHEM.OnStartup(function()
    for player = 0, 1 do
        -- reject duplicate original codes in the Main Deck
        if has_duplicate_name(player) then
            MAYHEM.Warn("player " .. player .. " lost: duplicate Main Deck name")
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
  "sheet_name": "Energy Dominate",
  "code": 56,
  "tier": "Excel",
  "status": "implemented",
  "script": "56_energy_dominate",
  "params": { "max_energy": 12, "normal_cost": 2, "quick_cost": 4 }
}
```

- `code` is **permanent**. It is what a host types into Starting LP, and it may
  end up printed on a tournament sheet. Always take the next unused number;
  never renumber, never reuse.
- `sheet_name` must match the Name column in the approved source workbook
  (`D:\AI\MDMayHem\Loi.xlsx` for catalogue 1.0.0) exactly.
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
tests["strength and efficiency install their field rules"] = function()
    run({ enabled = { "29_strength_of_the_weak", "30_be_more_efficient" } })
    assert(effect_with(EFFECT_IMMUNE_EFFECT), "weakest-monster immunity missing")
    assert(effect_with(EFFECT_MAX_MZONE).value == 3, "monster zone cap missing")
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

The beta regressions have separate entry points:

```bash
lua tools/test-combat-regressions.lua
lua tools/test-limit-regressions.lua
# Use a 32-bit Python executable for the configured client's DLL:
python tools/test-engine-regressions.py
```

The engine regression runner reads this repository's Lua sources and the
configured game's `ocgcore.dll` without installing or changing the game. Its
checks include loading all 38 cores to the first prompt, first-turn draws with
and without the native draw flag, a skipped Draw Phase, and mandatory deck-out.
Loading successfully is not a complete duel behavior test.

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
- **There is no normal arbitrary player-text API.** `Debug.ShowHint` is dropped
  by the client. Energy Dominate is the deliberate exception: it uses
  `HINT_NUMBER` for the balance and `Debug.Message` for the requested chat log.
  The host must set `coreLogOutput=3`; EDOPro labels those lines "Script Error".
- **`MAYHEM.Log` is silent by default.** EDOPro labels every script message
  "Script Error" and prints it in red in the duel chat, so routine notes must
  stay off. Use `MAYHEM.Warn` only for genuine faults.
- **Only LAN-hosted rooms run your code.** A room hosted through Online
  Multiplayer runs on the remote server, where the plugin does not exist and
  cannot even report that it is missing. Solo mode takes its LP from the puzzle
  script, so it is not a valid test either.
- **`EVENT_PHASE` turns a core's rule into a prompt, and crashes WindBot.**
  `Processors::PhaseEvent` collects every continuous effect listening on
  `EVENT_PHASE + phase` into `core.select_chains`. A lone entry is auto-selected,
  which is why this looks fine in testing — but as soon as any card also
  triggers that phase, the engine asks the player to choose between them, so the
  mutation rule becomes declinable *and* `MSG_SELECT_CHAIN` has to name the
  effect's card. A core has no card: its effects hang off the field's
  `temp_card`, whose location is `0`, and WindBot's `Duel.GetCard` returns null
  for that, then dereferences it (`NullReferenceException` in `OnSelectChain`,
  which kills the AI mid-duel). Use `MAYHEM.OnPhase`, which hooks
  `EVENT_PHASE_START` — an instant event that resolves automatically and is
  explicitly skipped when the engine builds trigger chains. `OnEvent` redirects
  an `EVENT_PHASE` code and warns rather than leaving the rule broken.
- **`PHASE_BATTLE` has no start event.** Every other phase raises
  `EVENT_PHASE_START + PHASE_*`; `PHASE_BATTLE` is the marker for the *end* of
  the Battle Phase, and `PHASE_BATTLE_START` is what opens it. A per-Battle-Phase
  reset hooked on `PHASE_BATTLE` never fires — it cost `46_once_punch` its reset,
  so only the duel's first attacker was boosted. `OnPhase` substitutes
  `PHASE_BATTLE_START` and warns.
- **A restriction on the wrong callback bans the action outright.** The engine
  collects the summon bans with `field::filter_player_effect` and then evaluates
  the effect's *target*: `if(!eff->target) return FALSE` means an effect with no
  target function is a blanket ban, and a predicate parked on the value is never
  consulted. Use `MAYHEM.PlayerRestriction` for `EFFECT_CANNOT_SUMMON`,
  `EFFECT_CANNOT_FLIP_SUMMON` and `EFFECT_CANNOT_SPECIAL_SUMMON`.
  `EFFECT_CANNOT_ACTIVATE` is the opposite — `effect::is_action_check` reaches
  it through `check_value_condition`, so its predicate belongs on the value.
- **`EFFECT_CANNOT_DRAW` cannot be made conditional.** `is_player_can_draw`
  only asks `is_player_affected_by_effect`, which checks that such an effect
  exists; no callback is ever run. To gate draws on duel state, register the
  effect when the condition begins and `Effect.Reset()` it when the condition
  ends, the way `31_droll_lock_limit` does. It also only covers draws that are
  not `REASON_RULE`, so it never blocks the normal Draw Phase draw.
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

### Beta regression lessons

- **Count the Field Zone explicitly (30).** `EFFECT_MAX_SZONE` caps only the
  ordinary slots. Subtract an occupied Field Zone from that cap, and block new
  Field Spell activations/sets when the total is full. Effects can still place
  cards directly: an `EVENT_ADJUST` rule makes the controller choose the excess
  Spell/Trap cards to send to the GY with `REASON_RULE`.
- **Hand destinations follow ownership (31).** A stolen card returns to its
  owner's hand. Test the owner's quota, not the current controller's quota.
- **Draw count does not enable the first-turn draw (35).** Supplement it at
  `EVENT_PREDRAW` only on turn one without `DUEL_1ST_TURN_DRAW`. This avoids
  doubling a native draw and respects a skipped Draw Phase.
- **Negating an effect differs from negating its activation (38).** Use
  `Duel.NegateEffect` for the former; do not fall back to `NegateActivation`.
- **Exclude only your own generated Tokens (39).** Track created card identities
  before summoning them to stop recursion while still mirroring other Tokens.
- **Attach damage-only ATK bonuses in the Damage Step (46).** Record the first
  declaration, then apply at `EVENT_BATTLE_START`. A negated attack consumes the
  first-attack allowance without leaving a buff waiting for a nonexistent reset.
- **“Other card effects” excludes the protected card's own effects (53).** A
  field immunity value receives `(e, incoming, card)`; compare
  `incoming:GetOwner()` with `card`, not the global rule's handler.
- **Mandatory draws must attempt the full amount (55).** Do not guard
  `Duel.Draw` with a deck-size check; an insufficient deck must cause deck-out.
- **Cost probes are not payment (56).** Probes for different actions can
  interleave. Use separate fixed-price activation effects instead of storing the
  last probed price in a shared label for the later payment callback.

## Generated token codes

Token-creating cores read `src/runtime/mayhem_token_codes.lua`. Regenerate that
file from the selected client's `cards.cdb` with
`python tools/build-token-codes.py`; never copy a card passcode into a core by
hand.
