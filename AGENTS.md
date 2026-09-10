# MD Mayhem — EDOPro mutation-core plugin

The project instructions live in **[CLAUDE.md](CLAUDE.md)** — read that file.

It is the single copy on purpose: this file used to be a duplicate of it and
drifted out of date (it still described the pre-`<code>_<id>` file naming and a
helper that no longer exists), which is worse than no copy at all.

Then, depending on what you are doing:

- `docs/writing-a-core.md` — how to write a core: recipes per rule shape, the
  helper API, testing, and the traps that have actually bitten.
- `docs/edopro-integration.md` — which EDOPro hooks were verified and against
  which source. Read it before changing anything under `src/runtime/`.
