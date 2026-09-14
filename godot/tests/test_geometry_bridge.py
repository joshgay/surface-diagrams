"""Independent contract tests for the fixed Python geometry bridge."""

from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "godot" / "bridge" / "render_document.py"
FIXTURES = ROOT / "godot" / "fixtures"
sys.path.insert(0, str(ROOT / "src"))

from surface_diagrams import DiagramDocument


class GeometryBridgeTests(unittest.TestCase):
    def invoke(self, source: Path, output: Path):
        svg = output / "diagram.svg"
        tikz = output / "diagram.tikz"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(source), str(svg), str(tikz)],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        return result, svg, tikz

    def test_outputs_match_library_exactly_and_are_deterministic(self):
        for name in ("planar-v1.json", "braid-v1.json", "multi-curve-v1.json"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
                source = FIXTURES / name
                document = DiagramDocument.from_json(source.read_text(encoding="utf-8"))
                first, first_svg, first_tikz = self.invoke(source, Path(first_dir))
                second, second_svg, second_tikz = self.invoke(source, Path(second_dir))
                self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
                self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
                manifest = json.loads(first.stdout)
                self.assertTrue(manifest["ok"])
                self.assertEqual(first_svg.read_text(encoding="utf-8"), document.render_svg())
                self.assertEqual(first_tikz.read_text(encoding="utf-8"), document.render_tikz())
                self.assertEqual(first_svg.read_bytes(), second_svg.read_bytes())
                self.assertEqual(first_tikz.read_bytes(), second_tikz.read_bytes())

    def test_invalid_data_fails_without_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "invalid.json"
            source.write_text('{"format":"surface-diagrams","version":99,"kind":"planar"}', encoding="utf-8")
            result, svg, tikz = self.invoke(source, root / "out")
            self.assertEqual(result.returncode, 1)
            self.assertFalse(json.loads(result.stdout)["ok"])
            self.assertFalse(svg.exists())
            self.assertFalse(tikz.exists())

    def test_edited_multi_curve_outputs_and_route_rejection(self):
        recipe = json.loads((FIXTURES / "multi-curve-v1.json").read_text())
        for cuts, accepted in [([0, 6], True), ([0, 5], False), ([0, 0], False)]:
            with self.subTest(cuts=cuts), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                recipe["curves"][1]["cuts"] = cuts
                source = root / "edited.json"
                source.write_text(json.dumps(recipe), encoding="utf-8")
                result, svg, tikz = self.invoke(source, root / "outputs")
                self.assertEqual(json.loads(source.read_text())["curves"][1]["cuts"], cuts)
                if accepted:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    exact = DiagramDocument.from_json(source.read_text())
                    self.assertEqual(svg.read_text(), exact.render_svg())
                    self.assertEqual(tikz.read_text(), exact.render_tikz())
                else:
                    self.assertEqual(result.returncode, 1)
                    self.assertFalse(svg.exists())
                    self.assertFalse(tikz.exists())


if __name__ == "__main__":
    unittest.main()
