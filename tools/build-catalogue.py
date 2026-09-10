"""Generate the Lua core catalogue from cores.json.

Per-match selection rides on the Host window's **Starting LP** box. Only five
things travel from the room settings into the duel core (OCG_DuelOptions: seed,
duel flags, and each team's startingLP / startingDrawCount / drawCountPerTurn),
and startingLP is a plain uint32 that EDOPro parses with stoul and never clamps.
So a host typing

    lp_code_base + <core code>

into Starting LP selects any entry in the catalogue, however large the library
grows, and the core then sets the real life points. Nothing in the client is
patched or overridden, so EDOPro's own 13 extra-rule modes stay untouched.

Codes come from the "code" field in cores.json and are stable for life: a code
printed on a tournament sheet keeps meaning the same mutation after the library
grows. Entries whose status is "planned" are skipped - they have no script yet.

Outputs into install/generated/:
    mayhem_catalogue.lua  the code -> cores table the plugin reads
    Mayhem-codes.txt      the printable code list, copied next to EDOPro.exe

Usage:
    python tools/build-catalogue.py
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CORES = REPO / "cores.json"
OUT = REPO / "install" / "generated"
CORE_DIR = REPO / "src" / "cores"


def configure_console() -> None:
    """Keep Vietnamese diagnostics printable in legacy Windows consoles."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

def lua_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def lua_params(params: dict) -> str:
    if not params:
        return "{}"
    body = ", ".join(f"{key} = {lua_value(value)}" for key, value in params.items())
    return "{ " + body + " }"


def write_code_list(data: dict, base: int) -> None:
    """A plain listing dropped next to EDOPro.exe, for the host to keep open."""
    lines = [
        "MD Mayhem - core codes",
        "",
        "USE LAN MODE. Only a LAN-hosted room runs the duel on your own machine.",
        "A room hosted through Online Multiplayer runs on the remote server, where",
        "the plugin does not exist - the code would just become real life points.",
        "",
        f"LAN mode -> Create Host -> Duel tab -> Starting LP = {base} + code",
        "The chosen core sets the real life points once the duel starts.",
        "A normal Starting LP is left alone, so casual and AI games are unaffected.",
        "",
        f"{'LP':>9}  {'code':>4}  {'tier':<9} {'status':<11} name / requirements",
    ]
    for core in data["cores"]:
        if core["status"] == "planned":
            continue
        requirements: list[str] = []
        room_settings = core.get("room_settings", {})
        if "time_limit" in room_settings:
            requirements.append(f"set Time Limit={room_settings['time_limit']}s")
        missing = core.get("missing_dependencies", [])
        if missing:
            requirements.append("missing: " + ", ".join(missing))
        suffix = f" — {'; '.join(requirements)}" if requirements else ""
        lines.append(f"{base + core['code']:>9}  {core['code']:>4}  "
                     f"{core['tier']:<9} {core['status'].upper():<11} "
                     f"{core['sheet_name']}{suffix}")
    (OUT / "Mayhem-codes.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    configure_console()
    data = json.loads(CORES.read_text(encoding="utf-8"))
    # The folder is the registry: a core exists exactly when its file does.
    known = {path.stem for path in CORE_DIR.glob("*.lua")}
    base = data["lp_code_base"]
    default_lp = data["default_lp"]

    seen: dict[int, str] = {}
    entries: list[str] = []
    skipped: list[str] = []

    for core in data["cores"]:
        code, name, status = core["code"], core["sheet_name"], core["status"]
        if status not in {"implemented", "partial", "planned"}:
            raise SystemExit(f"'{name}' has unsupported status '{status}'")
        if code in seen:
            raise SystemExit(f"code {code} used by both '{seen[code]}' and '{name}'")
        seen[code] = name
        if status == "planned":
            skipped.append(f"{code} {name}")
            continue
        script = core["script"]
        if script not in known:
            raise SystemExit(
                f"'{name}' references '{script}', but src/cores/{script}.lua does not exist"
            )
        cores_table = f"{script} = {lua_params(core.get('params', {}))}"
        missing_dependencies: list[str] = []
        for extra in core.get("also_needs", []):
            if extra in known:
                cores_table += f", {extra} = {{}}"
            else:
                missing_dependencies.append(extra)
        if missing_dependencies and status == "implemented":
            missing = ", ".join(missing_dependencies)
            raise SystemExit(f"'{name}' is implemented but is missing: {missing}")
        core["missing_dependencies"] = missing_dependencies
        entries.append(
            f"\t[{code}] = {{ label = {lua_value(name)}, cores = {{ {cores_table} }} }},"
        )

    lines = [
        "-- Generated by tools/build-catalogue.py from cores.json - do not edit by hand.",
        "--",
        "-- The host selects an entry by typing MAYHEM_LP_CODE_BASE + code into the",
        "-- Host window's Starting LP box. See mayhem_bootstrap.lua for the decoding.",
        "",
        f"MAYHEM_LP_CODE_BASE = {base}",
        f"MAYHEM_DEFAULT_LP = {default_lp}",
        f"MAYHEM_CATALOGUE_VERSION = {lua_value(data['version'])}",
        "",
        "MAYHEM_CATALOGUE = {",
        *entries,
        "}",
    ]

    OUT.mkdir(parents=True, exist_ok=True)
    for stale in OUT.glob("*"):
        if stale.is_file():
            stale.unlink()
        else:
            shutil.rmtree(stale)
    (OUT / "mayhem_catalogue.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")

    write_code_list(data, base)

    print(f"catalogue: {len(entries)} selectable entries, base {base}")
    for core in data["cores"]:
        missing = core.get("missing_dependencies", [])
        if missing:
            print(f"  partial: {core['code']} {core['sheet_name']} (missing {', '.join(missing)})")
    for skip in skipped:
        print(f"  skipped (planned): {skip}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
