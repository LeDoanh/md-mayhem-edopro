"""Print the core codes a host types into the Host window's Starting LP box.

Usage:
    python tools/list-codes.py
    python tools/list-codes.py --all      # include cores that have no script yet
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="include planned cores")
    args = parser.parse_args()

    data = json.loads((REPO / "cores.json").read_text(encoding="utf-8"))
    base = data["lp_code_base"]
    print(f"Starting LP = {base} + code\n")
    print(f"{'LP':>9}  {'code':>4}  {'tier':<9} {'status':<11} name / requirements")
    for core in data["cores"]:
        planned = core["status"] == "planned"
        if planned and not args.all:
            continue
        requirements = []
        if planned:
            requirements.append("no script yet")
        time_limit = core.get("room_settings", {}).get("time_limit")
        if time_limit is not None:
            requirements.append(f"set Time Limit={time_limit}s")
        if core.get("also_needs"):
            requirements.append("also needs: " + ", ".join(core["also_needs"]))
        suffix = f" — {'; '.join(requirements)}" if requirements else ""
        print(f"{base + core['code']:>9}  {core['code']:>4}  {core['tier']:<9} "
              f"{core['status'].upper():<11} {core['sheet_name']}{suffix}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
