---
date: 2026-09-10 10:12
severity: high
component: catalogue generator and distribution tooling
status: resolved
---

# Installer and Catalogue Safety Fixes

**Date**: 2026-09-10 10:12
**Severity**: High
**Component**: Catalogue generator, installer, uninstaller, portable package
**Status**: Resolved

## What Happened

The tooling presented partially implemented cores as finished and treated a missing `also_needs` script as optional. `Tử Chiến` could therefore be selected while its `no_hand_effects` dependency did not exist. Separately, `build-catalogue.py` crashed on Vietnamese output under a legacy Windows console with `UnicodeEncodeError`. The installer could overwrite an occupied `init.lua.bak`, and the uninstaller could restore that backup over a newer foreign `init.lua`.

## The Brutal Truth

We built safety-sensitive distribution tooling around optimistic assumptions. That was reckless: a host could advertise a rule the plugin did not enforce, while install/uninstall could damage another add-on's entry point. The worst part is that the code looked careful because it had backup logic; the logic itself was the hazard. Finding several independent failure modes in one quick review is frustrating and makes prior confidence in packaging feel unearned.

## Technical Details

`build-catalogue.py` now accepts only `implemented`, `partial`, or `planned`; an implemented entry missing a dependency exits with `'<name>' is implemented but is missing: no_hand_effects`. Generated code lists expose `PARTIAL`, room time limits, and missing components. Console streams are reconfigured as UTF-8. `cores.json` is the single version source (`0.4.0`), emitted as `MAYHEM_CATALOGUE_VERSION`; packaging regenerates the catalogue before creating the zip.

Installer preflight now refuses a foreign `init.lua` when `init.lua.bak` already exists. Uninstall ownership requires an exact shipped-file hash and preserves both files when another tool has replaced `init.lua`.

## What We Tried

We rejected silently skipping missing dependencies, substring ownership checks for `mayhem_bootstrap`, and force-overwriting backups. We also rejected pretending a portable zip can inspect its extraction target; it cannot.

## Root Cause Analysis

Status metadata was not treated as an enforcement boundary, and backup behavior was implemented as convenience instead of a transaction with explicit ownership. Version values were duplicated, so drift was inevitable.

## Lessons Learned

Generated user instructions are part of the safety model. Ownership must be proven by content, incomplete behavior must be visible, and generators must validate before packaging.

## Next Steps

The maintainer owns release review today: run all regressions, inspect the packaged README, then commit. Current evidence is clean: `python tools/test-tooling.py` passed 6/6, and `lua tools/test-cores.lua` passed 14/14. Portable installs still depend on users following the documented `init.lua` preflight; no zip format can enforce it.
