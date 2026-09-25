"""Delivery checks use only a temporary synthetic repository and game tree."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

REPO = Path(__file__).resolve().parents[1]
ADDON = "PartyTargetWatch"


class DeliveryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="ptw-delivery-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repository"
        self.repo.mkdir()
        shutil.copytree(REPO / ADDON, self.repo / ADDON)
        (self.repo / "tools").mkdir()
        for name in ("package.py", "install.py"):
            shutil.copy2(REPO / "tools" / name, self.repo / "tools" / name)
        for name in ("README.md", "LICENSE", "CHANGELOG.md"):
            shutil.copy2(REPO / name, self.repo / name)
        self.addons = self.root / "game" / "Interface" / "AddOns"
        self.addons.mkdir(parents=True)
        self.sentinel = self.addons / "SyntheticOtherAddon" / "sentinel.bin"
        self.sentinel.parent.mkdir()
        self.sentinel.write_bytes(bytes(range(256)) + b"leave this file unchanged")
        self.sentinel_hash = hashlib.sha256(self.sentinel.read_bytes()).hexdigest()

    def run_tool(self, name: str, *arguments: str, success: bool = True) -> subprocess.CompletedProcess:
        result = subprocess.run([sys.executable, str(self.repo / "tools" / name), *arguments],
                                capture_output=True, text=True, encoding="utf-8",
                                errors="replace", env={**os.environ, "PYTHONIOENCODING": "utf-8"})
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def install(self, success: bool = True) -> subprocess.CompletedProcess:
        return self.run_tool("install.py", "--addons-dir", str(self.addons), success=success)

    def report(self) -> dict:
        return json.loads((self.repo / "validation" / "local-install.json").read_text(encoding="utf-8"))

    def assert_other_addon_unchanged(self) -> None:
        self.assertEqual(hashlib.sha256(self.sentinel.read_bytes()).hexdigest(), self.sentinel_hash)
        report = self.report()
        self.assertIs(report["other_addons_unchanged"], True)
        self.assertEqual(report["other_addon_hashes_before"], report["other_addon_hashes_after"])
        self.assertEqual(report["other_addon_hashes_before"],
                         {"SyntheticOtherAddon/sentinel.bin": self.sentinel_hash})

    def test_release_zip_exact_contents_and_determinism(self) -> None:
        self.run_tool("package.py")
        archive_path = self.repo / "dist" / "PartyTargetWatch-0.3.1.zip"
        initial = archive_path.read_bytes()
        expected = {f"{ADDON}/{ADDON}.lua", f"{ADDON}/{ADDON}.toc",
                    f"{ADDON}/Communication.lua", f"{ADDON}/Settings.lua",
                    f"{ADDON}/README.md", f"{ADDON}/LICENSE", f"{ADDON}/CHANGELOG.md"}
        with zipfile.ZipFile(archive_path) as archive:
            self.assertEqual(set(archive.namelist()), expected)
            self.assertIsNone(archive.testzip())
            for name in expected:
                relative = name.split("/", 1)[1]
                source = self.repo / ADDON / relative if relative.endswith((".lua", ".xml", ".toc")) else self.repo / relative
                self.assertEqual(archive.read(name), source.read_bytes())
        self.run_tool("package.py")
        self.assertEqual(archive_path.read_bytes(), initial)

    def test_install_and_update_backup_preserve_other_addons_and_saved_variables(self) -> None:
        saved_variables = self.root / "game" / "WTF" / "Account" / "Synthetic" / "SavedVariables" / f"{ADDON}.lua"
        saved_variables.parent.mkdir(parents=True)
        saved_variables.write_bytes(b"PartyTargetWatchDB = { scale = 1.25 }\n")
        saved_content = saved_variables.read_bytes()
        self.install()
        target = self.addons / ADDON
        self.assertEqual((target / f"{ADDON}.lua").read_bytes(), (self.repo / ADDON / f"{ADDON}.lua").read_bytes())
        self.assertEqual(self.report()["status"], "success")
        self.assertIsNone(self.report()["backup_directory"])
        self.assertEqual(self.report()["removed_obsolete_files"], [])
        self.assertFalse((target / "Bindings.xml").exists())
        self.assert_other_addon_unchanged()
        previous_lua = (target / f"{ADDON}.lua").read_bytes()
        (target / "old-local-note.txt").write_text("preserve", encoding="utf-8")
        retired_binding = b'<Bindings><Binding name="PARTYTARGETWATCH_ANNOUNCE">PartyTargetWatch_AnnounceTarget();</Binding></Bindings>\n'
        (target / "Bindings.xml").write_bytes(retired_binding)
        source = self.repo / ADDON / f"{ADDON}.lua"
        source.write_bytes(previous_lua + b"\n-- Synthetic update fixture.\n")
        self.install()
        backup = Path(self.report()["backup_directory"])
        self.assertTrue(backup.is_relative_to(self.repo / "local-backups"))
        self.assertEqual((backup / f"{ADDON}.lua").read_bytes(), previous_lua)
        self.assertEqual((backup / "old-local-note.txt").read_text(), "preserve")
        self.assertEqual((backup / "Bindings.xml").read_bytes(), retired_binding)
        self.assertFalse((target / "Bindings.xml").exists(), "obsolete binding survived the upgrade")
        self.assertEqual(self.report()["removed_obsolete_files"], ["Bindings.xml"])
        self.assertEqual((target / "old-local-note.txt").read_text(), "preserve")
        self.assertEqual((target / f"{ADDON}.lua").read_bytes(), source.read_bytes())
        self.assertEqual(saved_variables.read_bytes(), saved_content)
        self.assert_other_addon_unchanged()

    def test_requires_explicit_correct_addons_path(self) -> None:
        self.run_tool("install.py", success=False)
        wrong = self.root / "AddOns"
        wrong.mkdir()
        self.run_tool("install.py", "--addons-dir", str(wrong), success=False)
        self.assertFalse((wrong / ADDON).exists())
        self.assertFalse((self.addons / ADDON).exists())

    def test_packaging_rejects_unlisted_and_missing_lua(self) -> None:
        extra = self.repo / ADDON / "unlisted.lua"
        extra.write_text("-- synthetic fixture", encoding="utf-8")
        self.run_tool("package.py", success=False)
        extra.unlink()
        (self.repo / ADDON / f"{ADDON}.lua").unlink()
        self.run_tool("package.py", success=False)

    def test_packaging_rejects_parent_traversal(self) -> None:
        toc = self.repo / ADDON / f"{ADDON}.toc"
        with toc.open("a", encoding="utf-8") as stream:
            stream.write("\n../escape.lua\n")
        self.run_tool("package.py", success=False)

    def test_packaging_rejects_malformed_bindings(self) -> None:
        binding = self.repo / ADDON / "Bindings.xml"
        binding.write_text("<Bindings><Binding>", encoding="utf-8")
        self.run_tool("package.py", success=False)
        binding.write_text("<Ui />", encoding="utf-8")
        self.run_tool("package.py", success=False)

    def test_install_rejects_hardlinked_destination(self) -> None:
        target = self.addons / ADDON
        target.mkdir()
        linked = target / f"{ADDON}.lua"
        try:
            os.link(self.sentinel, linked)
        except OSError as error:
            self.skipTest(f"Hard links unavailable: {error}")
        self.install(success=False)
        self.assertEqual(hashlib.sha256(self.sentinel.read_bytes()).hexdigest(), self.sentinel_hash)
        self.assertFalse((self.repo / "local-backups").exists())

    def test_install_rejects_symbolic_link_destination_when_supported(self) -> None:
        external = self.root / "external"
        external.mkdir()
        try:
            (self.addons / ADDON).symlink_to(external, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"Symbolic links unavailable: {error}")
        self.install(success=False)
        self.assertEqual(list(external.iterdir()), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
