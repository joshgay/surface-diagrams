"""Independent deterministic walkthrough publication contracts."""

from copy import deepcopy
from io import BytesIO
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "src"), str(ROOT / "godot/bridge")]
from build_walkthrough_bundle import build
from surface_diagrams import DiagramDocument

FIXTURES = ROOT / "godot" / "fixtures" / "walkthroughs"


class WalkthroughBundleTests(unittest.TestCase):
    def source(self, name):
        return (FIXTURES / name).read_text(encoding="utf-8")

    def test_all_walkthrough_kinds_are_exact_and_deterministic(self):
        for name in ("point-and-label-v1.json", "signed-braid-v1.json",
                     "supplied-cover-disk-v1.json"):
            with self.subTest(name=name):
                source = self.source(name)
                first, manifest = build(source)
                second, second_manifest = build(source)
                self.assertEqual(first, second)
                self.assertEqual(manifest, second_manifest)
                self.assertEqual(manifest["source"]["sha256"], hashlib.sha256(source.encode()).hexdigest())
                with zipfile.ZipFile(BytesIO(first)) as archive:
                    self.assertEqual(archive.read("walkthrough.json"), source.encode())
                    self.assertEqual(json.loads(archive.read("manifest.json")), manifest)
                    raw = json.loads(source)
                    for item in manifest["documents"]:
                        identifier = item["id"]
                        document = DiagramDocument.from_dict(raw["documents"][identifier])
                        self.assertEqual(archive.read(f"documents/{identifier}.svg").decode(), document.render_svg())
                        self.assertEqual(archive.read(f"documents/{identifier}.tikz").decode(), document.render_tikz())
                        self.assertEqual(archive.read(f"documents/{identifier}.py").decode(), document.python_source())
                        self.assertEqual(archive.read(f"documents/{identifier}.json").decode(), document.to_json())
                        for artifact in item["artifacts"]:
                            data = archive.read(artifact["path"])
                            self.assertEqual(artifact["bytes"], len(data))
                            self.assertEqual(artifact["sha256"], hashlib.sha256(data).hexdigest())

    def test_cover_views_are_retained_as_records_but_not_geometry_exports(self):
        bundle, manifest = build(self.source("supplied-cover-disk-v1.json"))
        excluded = manifest["excluded_exploratory_surface_views"]
        self.assertEqual([item["id"] for item in excluded], ["surface_before", "surface_after"])
        self.assertTrue(all(item["status"] == "exploratory-supplied-geometry" for item in excluded))
        self.assertTrue(all("no certified 3D geometry" in item["reason"] for item in excluded))
        self.assertEqual(manifest["steps"][0]["surface_linkage"], {
            "before": "surface_before", "after": "surface_after",
            "status": "supplied-exploratory-linkage",
            "verification": {"status": "unverified", "authority": "none",
                             "note": "No branched-cover lift is computed or verified."},
        })
        with zipfile.ZipFile(BytesIO(bundle)) as archive:
            names = archive.namelist()
            self.assertFalse(any("surface_before" in name or "surface_after" in name for name in names))
            self.assertIn('"surface_views"', archive.read("walkthrough.json").decode())

    def test_manifest_preserves_stable_records_and_literal_braid_block(self):
        _, planar = build(self.source("point-and-label-v1.json"))
        stable = planar["documents"][0]["stable_records"]
        self.assertEqual([item["id"] for item in stable if item["kind"] == "object"],
                         ["p1", "p2", "p3", "p4"])
        self.assertEqual([item["id"] for item in stable if item["kind"] == "curve"], ["arc1"])
        self.assertEqual([item["id"] for item in stable if item["kind"] == "label"], ["caption"])
        _, braid = build(self.source("signed-braid-v1.json"))
        self.assertEqual([step["literal_braid_block"] for step in braid["steps"]], [[1], [-2], [1]])
        self.assertEqual([item["id"] for item in braid["documents"][0]["stable_records"]], [1, 2, 3])

    def test_generated_recipe_reproduces_one_bundled_export(self):
        bundle, _ = build(self.source("point-and-label-v1.json"))
        with tempfile.TemporaryDirectory() as directory, zipfile.ZipFile(BytesIO(bundle)) as archive:
            root = Path(directory)
            source = archive.read("documents/initial.py")
            expected_svg = archive.read("documents/initial.svg")
            expected_tikz = archive.read("documents/initial.tikz")
            result = subprocess.run([sys.executable, "-c", source.decode()], cwd=root,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((root / "diagram.svg").read_bytes(), expected_svg)
            self.assertEqual((root / "diagram.tikz").read_bytes(), expected_tikz)

    def test_invalid_or_executable_wrapper_data_fails_without_output(self):
        valid = json.loads(self.source("point-and-label-v1.json"))
        cases = []
        for mutation in ("future", "script", "missing", "mixed", "chain", "duplicate_step"):
            raw = deepcopy(valid)
            if mutation == "future": raw["version"] = 2
            if mutation == "script": raw["script"] = "evil.py"
            if mutation == "missing": raw["steps"] = []
            if mutation == "mixed": raw["documents"]["point_moved"] = json.loads((ROOT / "godot/fixtures/braid-v1.json").read_text())
            if mutation == "chain": raw["steps"][1]["before"] = "initial"
            if mutation == "duplicate_step": raw["steps"][1]["id"] = raw["steps"][0]["id"]
            cases.append((mutation, json.dumps(raw)))
        cases.extend((("array", "[]"), ("duplicate", self.source("point-and-label-v1.json").replace(
            '"version": 1,', '"version": 1, "version": 1,', 1)),
            ("oversized", " " * (256 * 1024 + 1))))
        for name, source in cases:
            with self.subTest(name=name), self.assertRaises((ValueError, TypeError, KeyError, json.JSONDecodeError)):
                build(source)

    def test_cli_failure_does_not_create_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "invalid.json"
            output = root / "bundle.zip"
            source.write_text('{"format":"surface-diagrams-walkthrough","version":99}')
            result = subprocess.run([sys.executable, str(ROOT / "godot/bridge/build_walkthrough_bundle.py"),
                                     str(source), str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(json.loads(result.stdout)["ok"])
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
