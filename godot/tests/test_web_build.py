"""Build identity must distinguish tested source from local edits and exact assets."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "studio_web_build", Path(__file__).resolve().parents[1] / "web" / "build_web.py")
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class BuildIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "godot").mkdir()
        (self.root / "godot" / "project.godot").write_text("fixture")
        (self.root / ".gitignore").write_text("godot/.godot/\n")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.test",
                 "commit", "-qm", "Fixture")
        self.stage = self.root / "output"
        self.stage.mkdir()
        (self.stage / "index.pck").write_bytes(b"pack fixture")
        (self.stage / "index.wasm.gz").write_bytes(b"engine fixture")
        self.project = patch.object(BUILD, "PROJECT", self.root / "godot")
        self.project.start()
        self.addCleanup(self.project.stop)

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], text=True).strip()

    def test_clean_identity_is_repeatable_and_does_not_include_paths(self):
        first = BUILD.build_metadata(self.stage)
        self.assertEqual(first, BUILD.build_metadata(self.stage))
        self.assertFalse(first["dirty"])
        self.assertEqual(first["revision"], self.git("rev-parse", "HEAD"))
        self.assertNotIn(str(self.root), repr(first))

    def test_modified_and_untracked_source_are_labeled_but_cache_is_ignored(self):
        cache = self.root / "godot" / ".godot"
        cache.mkdir()
        (cache / "cache.bin").write_bytes(b"cache")
        self.assertFalse(BUILD.build_metadata(self.stage)["dirty"])
        (self.root / "godot" / "new.gd").write_text("untracked source")
        self.assertTrue(BUILD.build_metadata(self.stage)["dirty"])
        (self.root / "godot" / "new.gd").unlink()
        (self.root / "godot" / "project.godot").write_text("modified")
        self.assertTrue(BUILD.build_metadata(self.stage)["dirty"])

    def test_same_length_asset_tampering_changes_identity(self):
        before = BUILD.build_metadata(self.stage)
        (self.stage / "index.pck").write_bytes(b"tack fixture")
        after = BUILD.build_metadata(self.stage)
        self.assertEqual(before["assets"]["index.pck"]["bytes"], after["assets"]["index.pck"]["bytes"])
        self.assertNotEqual(before["assets"]["index.pck"]["sha256"], after["assets"]["index.pck"]["sha256"])
        self.assertEqual(before["assets"]["index.wasm.gz"], after["assets"]["index.wasm.gz"])


if __name__ == "__main__":
    unittest.main()
