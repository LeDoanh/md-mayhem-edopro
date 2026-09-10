---
date: 2026-09-10
session: rebuild-38-mutation-cores-from-loi-xlsx
---

# Journal: 2026-09-10 — Rebuild 38 Mutation Cores

**Severity**: High  
**Component**: EDOPro mutation-core catalogue, Lua rules, installer  
**Status**: Resolved with 3 documented partial cores

## Context

`Loi.xlsx` became the source for a full catalogue replacement. The old hand-maintained set no longer represented the requested game rules, so codes 1–19 were retired permanently and 38 new entries were assigned sequentially to codes 20–57. Published codes were not recycled; doing that would silently make an old printed LP code launch a different duel rule.

## What Happened

The rebuild produced one Lua module per core and exposed three honest limitations: Droll can overshoot its five-card quota when one resolving effect adds several cards; `yugiH5 Comeback` cannot reproduce a real direct attack outside Battle Phase; Speed Duel still requires the host to select the room mode. Calling these “implemented” would have been dishonest.

The audit also caught two classes of bugs that looked harmless in stubs but were wrong for ocgcore. Player-scoped field effects needed `EFFECT_FLAG_PLAYER_TARGET`, and several reset/refill hooks needed exact timing such as `EVENT_PHASE_START + PHASE_STANDBY`. The ugliest issue was an `EFFECT_DRAW_COUNT` callback consulting `Duel.GetDrawCount`, recursively asking the engine to evaluate itself. It was replaced by a value of `1` that expires after the first Draw Phase.

`Energy Dominate` now starts both players at 12, refills the turn player to 12 at Standby, charges 2 for normal actions and 4 for quick actions, and announces the remaining balance through `HINT_NUMBER` plus `[MAYHEM ENERGY]` chat output. A per-player `summon_pending` guard prevents a simultaneous Special Summon group from charging once per monster.

## Reflection

The frustrating truth is that creating 38 scripts was the easy part. The dangerous work was proving that terse, plausible Lua matched EDOPro’s target semantics and event timing. Without the audit, this batch would have shipped rules that loaded cleanly and still behaved incorrectly—the worst kind of failure because it looks finished.

## Decisions Made

| Decision | Rejected alternative | Why |
|---|---|---|
| Retire 1–19; allocate 20–57 | Reuse old codes | Preserve permanent printed-code meaning |
| Mark 31, 50, 52 partial | Pretend feature parity | Engine hooks cannot fully express those rules |
| Write `.mdmayhem-owned.json` with SHA-256 hashes | Delete the whole plugin directory | Uninstall must preserve foreign or operator-modified files |
| Charge Special Summon groups once | Charge every summoned monster | Energy cost applies to the action, not group size |

## Next Steps

- Plugin maintainer: run the offline Lua/tooling suites and all codes against 32-bit `ocgcore.dll` before release.
- Duel host: set `coreLogOutput=3` for Energy chat and select Speed Duel mode for code 52.
- Future core author: add a real-engine timing test whenever a rule depends on phase start, player targeting, or group events.
