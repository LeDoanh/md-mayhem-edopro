"""Source-tree smoke and behavior tests against the configured 32-bit ocgcore.

Run with the same 32-bit Python as run-duel.py. No installation is changed.
"""
from __future__ import annotations

import ctypes as ct
import importlib.util
import json
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("duel_driver", Path(__file__).with_name("run-duel.py"))
driver = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(driver)
REPO = driver.REPO


class EngineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if ct.sizeof(ct.c_void_p) != 4:
            raise RuntimeError("Use 32-bit Python, as required by tools/run-duel.py")
        cls.game = driver.resolve_game_path(None)
        candidates = sorted((cls.game / "repositories").glob("*/bin/ocgcore.dll"))
        candidates.append(cls.game / "ocgcore.dll")
        cls.core = ct.CDLL(str(next(p for p in candidates if p.is_file())))
        core = cls.core
        core.OCG_CreateDuel.argtypes = [ct.POINTER(ct.c_void_p), ct.POINTER(driver.OCG_DuelOptions)]
        core.OCG_CreateDuel.restype = ct.c_int
        core.OCG_LoadScript.argtypes = [ct.c_void_p, ct.c_char_p, ct.c_uint32, ct.c_char_p]
        core.OCG_LoadScript.restype = ct.c_int
        core.OCG_DuelNewCard.argtypes = [ct.c_void_p, ct.POINTER(driver.OCG_NewCardInfo)]
        core.OCG_StartDuel.argtypes = [ct.c_void_p]
        core.OCG_DuelProcess.argtypes = [ct.c_void_p]
        core.OCG_DuelProcess.restype = ct.c_int
        core.OCG_DuelGetMessage.argtypes = [ct.c_void_p, ct.POINTER(ct.c_uint32)]
        core.OCG_DuelGetMessage.restype = ct.c_void_p
        core.OCG_DestroyDuel.argtypes = [ct.c_void_p]

    def duel(self, code, *, flags=0, hand=5, decks=(40, 40), setup=""):
        core, duel = self.core, ct.c_void_p()
        client = driver.Client(self.game)
        errors, logs, packets, loaded = [], [], [], set()

        def execute(name, blob):
            return bool(core.OCG_LoadScript(duel, blob, len(blob), name.encode()))

        def load(name):
            if name == "mayhem_config.lua":
                return execute(name, b"MAYHEM_CONFIG = {}")
            if name.startswith("mayhem_core_"):
                path = REPO / "src/cores" / name[len("mayhem_core_"):]
            elif (REPO / "src/runtime" / name).is_file():
                path = REPO / "src/runtime" / name
            elif name == "mayhem_catalogue.lua":
                path = REPO / "install/generated" / name
            else:
                path = client.find_script(name)
            if path is None or not path.is_file():
                return False
            loaded.add(name)
            return execute(name, path.read_bytes().removeprefix(b"\xef\xbb\xbf"))

        def log(_payload, message, kind):
            text = message.decode("utf-8", "replace")
            (errors if kind == 0 else logs).append(text)

        # Keep ctypes callbacks alive until the duel is destroyed.
        readers = (
            driver.DataReader(client.card_data), driver.DataReaderDone(client.card_data_done),
            driver.ScriptReader(lambda _p, _d, name: int(load(name.decode()))), driver.LogHandler(log),
        )
        catalogue = json.loads((REPO / "cores.json").read_text(encoding="utf-8"))
        lp = catalogue["lp_code_base"] + code
        options = driver.OCG_DuelOptions()
        options.seed = (ct.c_uint64 * 4)(1, 2, 3, 4)
        options.flags = flags
        options.team1 = options.team2 = driver.OCG_Player(lp, hand, 1)
        options.cardReader, options.cardReaderDone, options.scriptReader, options.logHandler = readers
        options.enableUnsafeLibraries = 1
        self.assertEqual(core.OCG_CreateDuel(ct.byref(duel), ct.byref(options)), 0)
        try:
            for name in ("constant.lua", "utility.lua", "mayhem_bootstrap.lua"):
                self.assertTrue(load(name), name)
            if setup:
                self.assertTrue(execute("beta_test.lua", setup.encode()), errors)
            for player, size in enumerate(decks):
                for _ in range(size):
                    # duelist is the index within a team: 0 for both in 1v1.
                    card = driver.OCG_NewCardInfo(player, 0, driver.FILLER_CARD, player, 1, 0, 8)
                    core.OCG_DuelNewCard(duel, ct.byref(card))
            core.OCG_StartDuel(duel)
            for _ in range(100):
                state = core.OCG_DuelProcess(duel)
                size = ct.c_uint32()
                message = core.OCG_DuelGetMessage(duel, ct.byref(size))
                if message and size.value:
                    packets.extend(driver.iter_messages(ct.string_at(message, size.value)))
                if state != 2:
                    break
            else:
                self.fail("duel did not reach a prompt or completion")
            self.assertFalse(errors, "\n".join(errors))
            return packets, logs, loaded
        finally:
            core.OCG_DestroyDuel(duel)
            for database in client._databases:
                database.close()

    @staticmethod
    def first_player_draws(packets):
        return [int.from_bytes(payload[2:6], "little") for mid, payload in packets
                if mid == 90 and payload[1] == 0]

    def test_all_38_sources_load(self):
        entries = json.loads((REPO / "cores.json").read_text(encoding="utf-8"))["cores"]
        self.assertEqual(len(entries), 38)
        for entry in entries:
            with self.subTest(code=entry["code"]):
                _, _, loaded = self.duel(entry["code"])
                self.assertIn("mayhem_core_" + entry["script"] + ".lua", loaded)

    def test_35_draws_once_with_and_without_native_first_turn_draw(self):
        for flags in (0, 0x200):  # DUEL_1ST_TURN_DRAW
            with self.subTest(flags=flags):
                packets, _, _ = self.duel(35, flags=flags)
                self.assertEqual(self.first_player_draws(packets), [5, 1])

    def test_35_respects_skipped_draw_phase(self):
        packets, _, _ = self.duel(35, setup="MAYHEM.FieldRule(EFFECT_SKIP_DP, 1, true)")
        self.assertEqual(self.first_player_draws(packets), [5])

    def test_55_insufficient_deck_causes_deckout(self):
        packets, _, _ = self.duel(55, hand=0, decks=(2, 40),
                                  setup="Duel.TossDice = function() return 3 end")
        wins = [payload for mid, payload in packets if mid == 5]
        self.assertTrue(wins, "mandatory draw of three from two cards must end the duel")
        self.assertEqual(wins[0][1], 1, "opponent of the exhausted player must win")


if __name__ == "__main__":
    unittest.main(verbosity=2)
