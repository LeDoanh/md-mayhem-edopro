"""Start a real duel in ocgcore.dll, headless, and report what the plugin did.

The offline harness in test-cores.lua proves the Lua wiring; it cannot prove the
engine accepts an effect, or that EDOPro's script search actually reaches our
folder. This driver loads the client's own ocgcore.dll and replicates
Game::SetupDuel + generic_duel.cpp exactly:

    constant.lua -> utility.lua -> ./init.lua

so a core can be verified without launching the GUI and playing a match.

Usage:
    python tools/run-duel.py               # plain duel, just check the plugin loads
    python tools/run-duel.py --code 7      # as if the host typed 1000007 as Starting LP
    python tools/run-duel.py --lp 1000016  # the same thing, spelled out
    python tools/run-duel.py --code 7 --real-config   # what the player sees
"""

from __future__ import annotations

import argparse
import ctypes
import json
import sqlite3
import sys
from ctypes import (
    CFUNCTYPE,
    POINTER,
    Structure,
    byref,
    c_char_p,
    c_int,
    c_int32,
    c_uint8,
    c_uint16,
    c_uint32,
    c_uint64,
    c_void_p,
)
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

# A vanilla Normal Monster, used to fill both decks so the duel can start.
FILLER_CARD = 46986414  # Dark Magician Girl
DECK_SIZE = 40


class OCG_CardData(Structure):
    _fields_ = [
        ("code", c_uint32), ("alias", c_uint32), ("setcodes", POINTER(c_uint16)),
        ("type", c_uint32), ("level", c_uint32), ("attribute", c_uint32),
        ("race", c_uint64), ("attack", c_int32), ("defense", c_int32),
        ("lscale", c_uint32), ("rscale", c_uint32), ("link_marker", c_uint32),
    ]


class OCG_Player(Structure):
    _fields_ = [
        ("startingLP", c_uint32),
        ("startingDrawCount", c_uint32),
        ("drawCountPerTurn", c_uint32),
    ]


DataReader = CFUNCTYPE(None, c_void_p, c_uint32, POINTER(OCG_CardData))
DataReaderDone = CFUNCTYPE(None, c_void_p, POINTER(OCG_CardData))
ScriptReader = CFUNCTYPE(c_int, c_void_p, c_void_p, c_char_p)
LogHandler = CFUNCTYPE(None, c_void_p, c_char_p, c_int)


class OCG_DuelOptions(Structure):
    _fields_ = [
        ("seed", c_uint64 * 4), ("flags", c_uint64),
        ("team1", OCG_Player), ("team2", OCG_Player),
        ("cardReader", DataReader), ("payload1", c_void_p),
        ("scriptReader", ScriptReader), ("payload2", c_void_p),
        ("logHandler", LogHandler), ("payload3", c_void_p),
        ("cardReaderDone", DataReaderDone), ("payload4", c_void_p),
        ("enableUnsafeLibraries", c_uint8),
    ]


class OCG_NewCardInfo(Structure):
    _fields_ = [
        ("team", c_uint8), ("duelist", c_uint8), ("code", c_uint32),
        ("con", c_uint8), ("loc", c_uint32), ("seq", c_uint32), ("pos", c_uint32),
    ]


class Client:
    """Mirrors the parts of EDOPro that the duel core talks back to."""

    def __init__(self, game_path: Path):
        self.game_path = game_path
        self.messages: list[str] = []
        self.missing_scripts: list[str] = []
        self.loaded_scripts: list[str] = []
        self._databases = [
            sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
            for db in sorted((game_path / "expansions").glob("*.cdb"))
        ]
        self._empty_setcodes = (c_uint16 * 1)(0)
        # Same search order as Game::PopulateResourcesDirectories.
        self.script_dirs = [game_path / "expansions" / "script"]
        expansions_script = game_path / "expansions" / "script"
        if expansions_script.is_dir():
            self.script_dirs += [p for p in sorted(expansions_script.iterdir()) if p.is_dir()]
        self.script_dirs.append(game_path / "script")
        script_root = game_path / "script"
        if script_root.is_dir():
            self.script_dirs += [p for p in sorted(script_root.iterdir()) if p.is_dir()]

    def card_data(self, _payload, code, out):
        row = None
        for database in self._databases:
            row = database.execute(
                "SELECT alias, type, level, attribute, race, atk, def FROM datas WHERE id = ?",
                (code,),
            ).fetchone()
            if row:
                break
        data = out.contents
        data.code = code
        data.setcodes = self._empty_setcodes
        if not row:
            data.alias = data.type = data.level = data.attribute = 0
            data.race = 0
            data.attack = data.defense = 0
            data.lscale = data.rscale = data.link_marker = 0
            return
        alias, type_, level, attribute, race, atk, defense = row
        data.alias = alias or 0
        data.type = type_ or 0
        data.level = (level or 0) & 0xFF
        data.attribute = attribute or 0
        data.race = race or 0
        data.attack = atk or 0
        data.defense = defense or 0
        data.lscale = ((level or 0) >> 24) & 0xFF
        data.rscale = ((level or 0) >> 16) & 0xFF
        data.link_marker = 0

    def card_data_done(self, _payload, _data):
        return

    def find_script(self, name: str) -> Path | None:
        for directory in self.script_dirs:
            candidate = directory / name
            if candidate.is_file():
                return candidate
        return None

    def log(self, _payload, string, log_type):
        # Core output carries Vietnamese core names. This runs inside a ctypes
        # callback, where an encoding error would be swallowed and the line lost,
        # so stdout is forced to UTF-8 in main() before any duel starts.
        text = string.decode("utf-8", "replace")
        self.messages.append(text)
        prefix = {0: "ERROR ", 1: "script", 2: "debug "}.get(log_type, "?     ")
        print(f"  [{prefix}] {text}")


def iter_messages(blob: bytes):
    """Yield each (id, payload) in a core message buffer: uint32 length + payload."""
    offset = 0
    while offset + 4 <= len(blob):
        size = int.from_bytes(blob[offset:offset + 4], "little")
        offset += 4
        payload = blob[offset:offset + size]
        offset += size
        if payload:
            yield payload[0], payload


def message_ids(blob: bytes) -> list[int]:
    return [msg_id for msg_id, _ in iter_messages(blob)]


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-path", type=Path, default=None,
                        help="EDOPro folder; defaults to the one install.ps1 remembered")
    parser.add_argument("--code", type=int, default=None,
                        help="catalogue code to select, encoded into Starting LP")
    parser.add_argument("--lp", type=int, default=8000)
    parser.add_argument("--hand", type=int, default=5)
    parser.add_argument("--draw", type=int, default=1)
    parser.add_argument("--verbose", action="store_true",
                        help="print the core message ids of each step")
    parser.add_argument("--real-config", action="store_true",
                        help="use the installed mayhem_config.lua, to see exactly "
                             "what a player's client would print")
    args = parser.parse_args()
    game_path = resolve_game_path(args.game_path)

    # Registered repos can ship a newer core than the one next to the exe, and
    # cores_to_load puts those first (game.cpp), so prefer the repo build.
    candidates = sorted((game_path / "repositories").glob("*/bin/ocgcore.dll"))
    candidates.append(game_path / "ocgcore.dll")
    core_path = next((p for p in candidates if p.is_file()), None)
    if core_path is None:
        raise SystemExit(f"no ocgcore.dll found under {game_path}")

    if ctypes.sizeof(ctypes.c_void_p) != 4:
        raise SystemExit(
            "EDOPro and ocgcore.dll are 32-bit, so this driver needs a 32-bit\n"
            "Python. This interpreter is 64-bit. Install one, e.g.:\n"
            "    uv python install cpython-3.12-windows-x86\n"
            "then run this script with it."
        )

    core = ctypes.CDLL(str(core_path))
    core.OCG_CreateDuel.argtypes = [POINTER(c_void_p), POINTER(OCG_DuelOptions)]
    core.OCG_CreateDuel.restype = c_int
    core.OCG_LoadScript.argtypes = [c_void_p, c_char_p, c_uint32, c_char_p]
    core.OCG_LoadScript.restype = c_int
    core.OCG_DuelNewCard.argtypes = [c_void_p, POINTER(OCG_NewCardInfo)]
    core.OCG_StartDuel.argtypes = [c_void_p]
    core.OCG_DuelProcess.argtypes = [c_void_p]
    core.OCG_DuelProcess.restype = c_int
    core.OCG_DuelGetMessage.argtypes = [c_void_p, POINTER(c_uint32)]
    core.OCG_DuelGetMessage.restype = c_void_p
    core.OCG_DestroyDuel.argtypes = [c_void_p]

    major, minor = c_int(), c_int()
    core.OCG_GetVersion(byref(major), byref(minor))
    print(f"ocgcore {major.value}.{minor.value}  ({core_path})")

    client = Client(game_path)
    duel = c_void_p()

    # The shipped config keeps logging off, because EDOPro tags script messages
    # as "Script Error" and prints them in the duel chat. This driver exists to
    # read those messages, so it serves its own config instead of the installed
    # one - the same trick a client uses: it owns the script reader.
    DEBUG_CONFIG = b"MAYHEM_CONFIG = { announce = true, debug = true }\n"

    def load_script(name: str) -> bool:
        """Same contract as Game::LoadScript / Game::ScriptReader."""
        if name == "mayhem_config.lua" and not args.real_config:
            client.loaded_scripts.append(name)
            return bool(core.OCG_LoadScript(duel, DEBUG_CONFIG, len(DEBUG_CONFIG), name.encode()))
        path = client.find_script(name)
        if path is None:
            client.missing_scripts.append(name)
            return False
        blob = path.read_bytes()
        if blob[:3] == b"\xef\xbb\xbf":
            blob = blob[3:]
        client.loaded_scripts.append(name)
        return bool(core.OCG_LoadScript(duel, blob, len(blob), name.encode()))

    script_reader = ScriptReader(lambda _p, _d, name: 1 if load_script(name.decode()) else 0)
    card_reader = DataReader(client.card_data)
    card_reader_done = DataReaderDone(client.card_data_done)
    log_handler = LogHandler(client.log)

    starting_lp = args.lp
    if args.code is not None:
        starting_lp = json.loads((REPO / "cores.json").read_text(encoding="utf-8"))[
            "lp_code_base"] + args.code
        print(f"selecting code {args.code} -> Starting LP {starting_lp}")

    player = OCG_Player(starting_lp, args.hand, args.draw)
    options = OCG_DuelOptions()
    options.seed = (c_uint64 * 4)(1, 2, 3, 4)
    options.flags = 0
    options.team1 = player
    options.team2 = player
    options.cardReader = card_reader
    options.scriptReader = script_reader
    options.logHandler = log_handler
    options.cardReaderDone = card_reader_done
    options.enableUnsafeLibraries = 1  # matches Game::SetupDuel

    status = core.OCG_CreateDuel(byref(duel), byref(options))
    if status != 0:
        raise SystemExit(f"OCG_CreateDuel failed with status {status}")

    print("\nloading core scripts")
    for name in ("constant.lua", "utility.lua"):
        if not load_script(name):
            raise SystemExit(f"could not load {name}")

    # Game::SetupDuel then loads every entry of init_scripts, ./init.lua first.
    print("\nloading init scripts")
    init_lua = game_path / "init.lua"
    if init_lua.is_file():
        blob = init_lua.read_bytes()
        core.OCG_LoadScript(duel, blob, len(blob), b"./init.lua")
        print("  ./init.lua loaded")
    else:
        print("  ./init.lua MISSING - the plugin has no entry point")

    for team in (0, 1):
        for _ in range(DECK_SIZE):
            # Each team has one duelist, at index 0. Using team as the index
            # puts player 2's cards in a nonexistent teammate's deck.
            info = OCG_NewCardInfo(team, 0, FILLER_CARD, team, 0x1, 0, 0x8)
            core.OCG_DuelNewCard(duel, byref(info))

    print("\nstarting duel")
    core.OCG_StartDuel(duel)
    length = c_uint32()
    for _ in range(50):
        state = core.OCG_DuelProcess(duel)
        buffer = core.OCG_DuelGetMessage(duel, byref(length))
        if buffer and length.value:
            blob = ctypes.string_at(buffer, length.value)
            if args.verbose:
                print("  messages: " + ", ".join(str(i) for i in message_ids(blob)))
        if state != 2:  # OCG_DUEL_STATUS_CONTINUE
            break

    print("\n--- summary ---")
    mayhem = [m for m in client.messages if "[MAYHEM]" in m]
    errors = [m for m in client.messages if "[MAYHEM]" not in m]
    print(f"scripts loaded : {len(client.loaded_scripts)}")
    if client.missing_scripts:
        print(f"scripts MISSING: {', '.join(sorted(set(client.missing_scripts)))}")
    print(f"MAYHEM lines   : {len(mayhem)}")
    for line in mayhem:
        print(f"  {line}")
    if errors:
        print(f"other core output ({len(errors)} lines):")
        for line in errors[:20]:
            print(f"  {line}")

    core.OCG_DestroyDuel(duel)
    # With --real-config the shipped config keeps logging off, so silence is the
    # expected result and says nothing about whether the plugin worked.
    return 0 if (mayhem or args.real_config) else 1


if __name__ == "__main__":
    sys.exit(main())
