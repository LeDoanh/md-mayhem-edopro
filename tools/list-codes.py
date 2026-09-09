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
    print(f"{'LP':>9}  {'code':>4}  {'tier':<9} name")
    for core in data["cores"]:
        planned = core["status"] == "planned"
        if planned and not args.all:
            continue
        mark = "  (planned, no script yet)" if planned else ""
        print(f"{base + core['code']:>9}  {core['code']:>4}  {core['tier']:<9} "
              f"{core['sheet_name']}{mark}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
