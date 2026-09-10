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

    def test_catalogue_handles_legacy_console_and_catalogue_version(self) -> None:
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
            self.assertIn("MD Mayhem - core codes", codes)
            self.assertIn("set Duel Mode=Speed", codes)
            self.assertIn("a single effect that adds several cards can overshoot", codes)
            self.assertIn("for energy chat set coreLogOutput=3", codes)

            catalogue = (repo / "install" / "generated" / "mayhem_catalogue.lua").read_text(
                encoding="utf-8"
            )
            version = json.loads((repo / "cores.json").read_text(encoding="utf-8"))["version"]
            self.assertIn(f'MAYHEM_CATALOGUE_VERSION = "{version}"', catalogue)
            self.assertIn('["20_plan_ahead_of_time"] =', catalogue)
            self.assertIn('["plan_ahead_of_time"] = "20_plan_ahead_of_time"', catalogue)

    def test_retired_code_cannot_be_reused(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            data = json.loads((repo / "cores.json").read_text(encoding="utf-8"))
            data["cores"][0]["code"] = data["retired_codes"][0]["code"]
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
            self.assertIn("(retired)", result.stderr)

    def test_script_id_must_start_with_its_code(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            data = json.loads((repo / "cores.json").read_text(encoding="utf-8"))
            data["cores"][0]["script"] = data["cores"][1]["script"]
            (repo / "cores.json").write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, repo / "tools" / "build-catalogue.py"],
                text=True, encoding="utf-8", errors="replace", capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("code-prefixed script id", result.stderr)

    @unittest.skipUnless(POWERSHELL, "PowerShell is required")
    def test_install_removes_retired_core_modules(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            game = root / "game"
            plugin = game / "expansions" / "script" / "mdmayhem"
            plugin.mkdir(parents=True)
            (game / "EDOPro.exe").touch()
            stale = plugin / "mayhem_core_energy_surge.lua"
            stale.write_text("retired", encoding="utf-8")
            previous_name = plugin / "mayhem_core_energy_dominate.lua"
            previous_name.write_text("pre-code-prefix", encoding="utf-8")
            config = plugin / "mayhem_config.lua"
            config.write_text("operator config", encoding="utf-8")

            result = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(stale.exists())
            self.assertFalse(previous_name.exists())
            self.assertEqual(config.read_text(encoding="utf-8"), "operator config")

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

    @unittest.skipUnless(POWERSHELL, "PowerShell is required")
    def test_second_install_keeps_config_ownership_for_uninstall(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            game = root / "game"
            game.mkdir()
            (game / "EDOPro.exe").touch()
            first = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            second = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            uninstall = self.run_ps(repo / "tools" / "uninstall.ps1", "-GamePath", str(game))
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr)
            self.assertFalse((game / "expansions" / "script" / "mdmayhem").exists())

    @unittest.skipUnless(POWERSHELL, "PowerShell is required")
    def test_uninstall_preserves_foreign_and_modified_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            game = root / "game"
            game.mkdir()
            (game / "EDOPro.exe").touch()
            install = self.run_ps(repo / "tools" / "install.ps1", "-GamePath", str(game))
            self.assertEqual(install.returncode, 0, install.stderr)

            plugin = game / "expansions" / "script" / "mdmayhem"
            foreign = plugin / "notes-from-operator.txt"
            foreign.write_text("keep me", encoding="utf-8")
            code_list = game / "Mayhem-codes.txt"
            code_list.write_text("operator replacement", encoding="utf-8")

            uninstall = self.run_ps(repo / "tools" / "uninstall.ps1", "-GamePath", str(game))
            self.assertEqual(uninstall.returncode, 0, uninstall.stderr)
            self.assertEqual(foreign.read_text(encoding="utf-8"), "keep me")
            self.assertEqual(code_list.read_text(encoding="utf-8"), "operator replacement")
            self.assertFalse((plugin / "mayhem_engine.lua").exists())

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
                members = set(package.namelist())
                readme = package.read("README.txt").decode("utf-8")
                normalized = " ".join(readme.split())
                self.assertIn("First install: if init.lua.bak already exists", normalized)
                self.assertIn("If init.lua is not MD Mayhem's own loader", normalized)
                self.assertIn("Upgrade: do NOT rename MD Mayhem's current init.lua again", normalized)
                self.assertIn("delete the old expansions/script/mdmayhem directory", normalized)
                self.assertIn("set coreLogOutput=3", normalized)
                self.assertIn("Delete init.lua only if it is byte-for-byte identical", normalized)
                expected_cores = {
                    f"expansions/script/mdmayhem/mayhem_core_{path.name}"
                    for path in (repo / "src" / "cores").glob("*.lua")
                }
                expected_runtime = {
                    f"expansions/script/mdmayhem/{path.name}"
                    for path in (repo / "src" / "runtime").glob("*.lua")
                }
                self.assertTrue(expected_cores <= members)
                self.assertTrue(expected_runtime <= members)
                self.assertEqual(
                    {name for name in members if "mayhem_core_" in name}, expected_cores
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
