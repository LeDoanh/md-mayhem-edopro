---
date: 2026-09-10
type: code-review
scope: 38 mutation cores + runtime, phase 3 close-out
verdict: 3 defects found and fixed, release gate green
---

# Independent review — mutation cores 20–57

Closes plan `rebuild-cores-from-loi-xlsx.md` phase 3. Rename + sync were already
complete on entry (38 files `<code>_<id>.lua`, `cores.json` scripts,
`MAYHEM.Register` ids, installer/package mapping, `retired_scripts` all agree).
This pass did the spec review, the code review and the full gate.

## Spec review — clean

`Loi.xlsx` (Sheet1, 38 rows) compared row-by-row to `cores.json`: `sheet_name`,
`description` and code (`row n -> 19+n`) match exactly, typos included. No drift.

## Defects found

All three shared one root cause: **the engine does not read every restriction
from the effect's value.** Verified in `edo9300/ygopro-core` (the core EDOPro
builds from), not inferred. The offline harness could not see it — a stub
records whatever it is handed.

| # | Core | Was | Real engine behaviour | Fix |
| --- | --- | --- | --- | --- |
| 1 | `26_there_can_be_only_one_kind` | predicate on `SetValue` for `EFFECT_CANNOT_SPECIAL_SUMMON` | `field::is_player_can_spsummon` does `if(!eff->target) return FALSE` — **no Special Summon at all, whole duel** | predicate moved to the target via new `MAYHEM.PlayerRestriction` |
| 2 | `44_restricted_gambling` | same, on `EFFECT_CANNOT_SUMMON` + `_FLIP_SUMMON` + `_SPECIAL_SUMMON` | **every summon banned from turn 1**; the die roll never mattered | same helper for all three |
| 3 | `31_droll_lock_limit` | quota predicate on `EFFECT_CANNOT_DRAW` value | `is_player_can_draw` only asks `is_player_affected_by_effect` — presence only, no callback. **All effect draws banned for the whole duel**, quota ignored | lock is now registered per player when the quota is spent and `Effect.Reset()`-ed at the next Draw Phase |

`EFFECT_CANNOT_ACTIVATE` in cores 44/51 was already correct: that one *is*
value-driven (`effect::is_action_check` -> `check_value_condition`, which
prepends the effect, so `function(e, te, tp)` is the right shape).

### Engine proof, not source reading

A/B probe in a real duel through `ocgcore.dll`, code 26 at `EVENT_STARTUP`:

```
old shape (value):  Duel.IsPlayerCanSpecialSummon(0)=false  (1)=false
fixed shape (target): Duel.IsPlayerCanSpecialSummon(0)=true   (1)=true
```

Probe was removed afterwards; all 44 installed files match their
`.mdmayhem-owned.json` hashes again.

## Checked and found correct

- Callback per code now documented in `docs/edopro-integration.md` §3 with source
  lines: activate-cost (`EFFECT_FLAG_PLAYER_TARGET` required), spsummon-cost
  (flag must be absent — `card::filter_effect` only takes aura effects without
  it), immune/to-hand/attack-announce (target selects cards, value decides),
  chain-negation (`value(e, chain_count)`).
- Cores 56/57 cost hooks match the official `EFFECT_ACTIVATE_COST` idiom
  (`pre-errata/c33900658.lua`) and `EFFECT_SPSUMMON_COST` param order
  (`official/c102380.lua`).
- Core 22's blanket set ban works *through* the `!target` shortcut — intended
  ("Không được Set Card"), so it stays as it is.
- Every uppercase constant used by runtime + cores exists in the client's
  `constant.lua` (only false positive: the literal `[MAYHEM ENERGY]`).
- Core 42 mirrors battle damage too; `REASON_RULE` guard prevents recursion —
  matches the Excel wording.

## Gate results

| Gate | Result |
| --- | --- |
| `python tools/build-catalogue.py` | 38 entries, base 1000000 |
| `lua tools/test-cores.lua` | 24 passed, 0 failed (was 22 — +2 tests, 2 rewritten) |
| `python -m unittest tools/test-tooling.py` | 10 passed |
| `python tools/make-package.py` | `dist/mdmayhem-1.0.0.zip`, 47 files |
| `run-duel.py --code 20..57` (32-bit, real `ocgcore.dll`) | 38/38 applied, 0 errors |
| LP invariants | encoded 1000999 and retired 1000008 both restore 8000; plain 8000 untouched |
| `uninstall.ps1 -WhatIf` | touches owned files only, restores `init.lua.bak` |

New tests bite: reverting core 26 to the old shape fails
`there can be only one kind remembers used Extra Deck types`.

## Notes for the maintainer

- `mayhem_config.lua` on this machine keeps a stale comment example
  (`1000008 = Han Dien Vang`, a retired code). The installer preserves an
  existing config on purpose; `install.ps1 -Force` refreshes it.
- Cores still `partial` and why: 31 (quota overshoot within one resolving
  effect), 50 (no real direct attack outside Battle Phase), 52 (host must pick
  Speed Duel mode).

## Unresolved

- Core 56's `EFFECT_SPSUMMON_COST` is collected through `card::filter_effect`
  (source-verified) but no client script uses a field-scoped one, and no test
  plays a summon, so the 2-energy charge itself is still unproven in a real
  match. Same for the 4-energy quick-action branch. A hosted LAN duel is the
  cheapest way to confirm.
- Nothing else in the catalogue has been exercised by an actual played turn;
  the engine gate proves acceptance at duel start only.
