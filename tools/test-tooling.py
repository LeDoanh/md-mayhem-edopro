"""Regression tests for generators and install/uninstall safety."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parent.parent
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell")


class ToolingTests(unittest.TestCase):
    def make_repo(self, root: Path) -> Path:
        repo = root / "repo"
        for name in ("tools", "src", "install"):
            shutil.copytree(REPO / name, repo / name)
        shutil.copy2(REPO / "cores.json", repo / "cores.json")
        return repo

    def run_ps(self, script: Path, *args: str) -> subprocess.CompletedProcess[str]:
        assert POWERSHELL
        return subprocess.run(
            [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, *args],
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
        )

    def test_catalogue_handles_legacy_console_and_labels_partial_entries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "cp1252"
            result = subprocess.run(
                [sys.executable, repo / "tools" / "build-catalogue.py"],
                env=env,
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

            codes = (repo / "install" / "generated" / "Mayhem-codes.txt").read_text(
                encoding="utf-8"
            )
            self.assertIn("PARTIAL", codes)
            self.assertIn("set Time Limit=30s", codes)
            self.assertIn("missing: no_hand_effects", codes)

            catalogue = (repo / "install" / "generated" / "mayhem_catalogue.lua").read_text(
                encoding="utf-8"
            )
            version = json.loads((repo / "cores.json").read_text(encoding="utf-8"))["version"]
            self.assertIn(f'MAYHEM_CATALOGUE_VERSION = "{version}"', catalogue)

    def test_implemented_entry_cannot_silently_drop_a_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            data = json.loads((repo / "cores.json").read_text(encoding="utf-8"))
            next(core for core in data["cores"] if core["code"] == 13)["status"] = "implemented"
            (repo / "cores.json").write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

            result = subprocess.run(
                [sys.executable, repo / "tools" / "build-catalogue.py"],
                env={**os.environ, "PYTHONIOENCODING": "cp1252"},
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing: no_hand_effects", result.stderr)

    @unittest.skipUnless(POWERSHELL, "PowerShell is required")
    def test_install_refuses_to_overwrite_an_existing_backup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            game = root / "game"
            game.mkdir()
            (game / "EDOPro.exe").touch()
            (game / "init.lua").write_text("current owner", encoding="utf-8")
            (game / "init.lua.bak").write_text("older backup", encoding="utf-8")

            result = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((game / "init.lua").read_text(encoding="utf-8"), "current owner")
            self.assertEqual((game / "init.lua.bak").read_text(encoding="utf-8"), "older backup")
            self.assertFalse((game / "expansions" / "script" / "mdmayhem").exists())
            self.assertFalse((game / "Mayhem-codes.txt").exists())

    @unittest.skipUnless(POWERSHELL, "PowerShell is required")
    def test_uninstall_preserves_a_new_foreign_init_and_dry_run_has_no_memory_write(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            game = root / "game"
            game.mkdir()
            (game / "EDOPro.exe").touch()
            (game / "init.lua").write_text("original owner", encoding="utf-8")

            install = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            self.assertEqual(install.returncode, 0, install.stderr)
            shared_loader = 'Duel.LoadScript("other.lua")\nDuel.LoadScript("mayhem_bootstrap.lua")\n'
            (game / "init.lua").write_text(shared_loader, encoding="utf-8")

            uninstall = self.run_ps(repo / "tools" / "uninstall.ps1", "-GamePath", str(game))
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr)
            self.assertEqual((game / "init.lua").read_text(encoding="utf-8"), shared_loader)
            self.assertEqual((game / "init.lua.bak").read_text(encoding="utf-8"), "original owner")

            (repo / ".game-path").unlink(missing_ok=True)
            dry_run = self.run_ps(
                repo / "tools" / "uninstall.ps1", "-WhatIf", "-GamePath", str(game)
            )
            self.assertEqual(dry_run.returncode, 0, dry_run.stderr)
            self.assertFalse((repo / ".game-path").exists())

    @unittest.skipUnless(POWERSHELL, "PowerShell is required")
    def test_normal_uninstall_restores_the_original_init(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            game = root / "game"
            game.mkdir()
            (game / "EDOPro.exe").touch()
            (game / "init.lua").write_text("original owner", encoding="utf-8")

            install = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            self.assertEqual(install.returncode, 0, install.stderr)
            uninstall = self.run_ps(repo / "tools" / "uninstall.ps1", "-GamePath", str(game))
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr)

            self.assertEqual((game / "init.lua").read_text(encoding="utf-8"), "original owner")
            self.assertFalse((game / "init.lua.bak").exists())
            self.assertFalse((game / "expansions" / "script" / "mdmayhem").exists())

    def test_portable_package_contains_init_safety_instructions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            result = subprocess.run(
                [sys.executable, repo / "tools" / "make-package.py"],
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            archive = next((repo / "dist").glob("*.zip"))
            with zipfile.ZipFile(archive) as package:
                readme = package.read("README.txt").decode("utf-8")
                normalized = " ".join(readme.split())
                self.assertIn("If init.lua.bak already exists, move that older backup", normalized)
                self.assertIn("if init.lua exists, rename the current file to init.lua.bak", normalized)
                self.assertIn("Delete init.lua only if it is byte-for-byte identical", normalized)


if __name__ == "__main__":
    unittest.main(verbosity=2)
