"""Turn a plain list of card names into an EDOPro .lflist.conf.

EDOPro banlists are keyed by passcode, and popular cards carry several
passcodes (one per alternate artwork). Hand-maintaining those ids goes stale
the moment a reprint lands, so the list is written by name and resolved here
against the client's own card database.

Usage:
    python tools/build-banlist.py [--game-path <EDOPro folder>]
"""

from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def resolve_game_path(explicit: "Path | None") -> Path:
    """Use the folder install.ps1 confirmed, so the tools never guess a target."""
    path = explicit
    if path is None:
        remembered = REPO / ".game-path"
        text = remembered.read_text(encoding="utf-8").strip() if remembered.is_file() else ""
        if not text:
            raise SystemExit(
                "No EDOPro folder known. Run tools/install.ps1 once (it asks and "
                "remembers), or pass --game-path <folder>."
            )
        path = Path(text)
    if not (path / "EDOPro.exe").is_file():
        raise SystemExit(f"EDOPro.exe not found in '{path}'.")
    return path
SOURCE = REPO / "install" / "banlist" / "mayhem-tactical.txt"
OUTPUT = REPO / "install" / "Mayhem_Tactical.lflist.conf"
LIST_NAME = "Mayhem Tactical"


def read_names(path: Path) -> list[tuple[str, str]]:
    """Return (section, card name) pairs in file order."""
    entries: list[tuple[str, str]] = []
    section = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("##"):
            section = line.lstrip("#").strip()
        elif not line.startswith("#"):
            entries.append((section, line))
    return entries


def find_databases(game_path: Path) -> list[Path]:
    databases = sorted((game_path / "expansions").glob("*.cdb"))
    if not databases:
        raise SystemExit(f"no .cdb found under {game_path / 'expansions'}")
    return databases


def resolve(databases: list[Path], name: str) -> list[int]:
    ids: set[int] = set()
    for database in databases:
        connection = sqlite3.connect(f"file:{database.as_posix()}?mode=ro", uri=True)
        try:
            rows = connection.execute("SELECT id FROM texts WHERE name = ?", (name,))
            ids.update(row[0] for row in rows)
        finally:
            connection.close()
    return sorted(ids)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-path", type=Path, default=None,
                        help="EDOPro folder; defaults to the one install.ps1 remembered")
    args = parser.parse_args()
    game_path = resolve_game_path(args.game_path)

    databases = find_databases(game_path)
    lines = [f"#{LIST_NAME}", f"!{LIST_NAME}"]
    missing: list[str] = []
    section = None

    for entry_section, name in read_names(SOURCE):
        if entry_section != section:
            section = entry_section
            lines.append(f"#{section}")
        ids = resolve(databases, name)
        if not ids:
            missing.append(name)
            continue
        lines.extend(f"{card_id} 0 --{name}" for card_id in ids)

    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    resolved = sum(1 for line in lines if line and line[0].isdigit())
    print(f"wrote {OUTPUT.relative_to(REPO)}: {resolved} passcodes")

    if missing:
        print("NOT FOUND in the card database - check the spelling:", file=sys.stderr)
        for name in missing:
            print(f"  {name}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
