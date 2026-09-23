"""Independent schema, exact rendering and strand-continuity contracts."""
from copy import deepcopy
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "src"), str(ROOT / "godot/bridge")]
from factor_workspace import parse, diagram
from surface_diagrams import DiagramDocument, FactorPanel, FactorizationDiagram, Panel, render_svg, render_tikz, Style
from surface_diagrams.layout import layout

SOURCE = (ROOT / "godot/fixtures/workspaces/grouped-v1.json").read_text()


class FactorWorkspaceTests(unittest.TestCase):
    def test_exact_library_mapping_preserves_labels_and_literal_words(self):
        raw = json.loads(SOURCE)
        docs = {key: DiagramDocument.from_dict(value) for key, value in raw["documents"].items()}
        left = Panel(docs["leftArc"], docs["leftArc"].title, style=docs["leftArc"].style)
        right = Panel(docs["rightArc"], docs["rightArc"].title, style=docs["rightArc"].style)
        expected = FactorizationDiagram((
            FactorPanel("a", left, braid_word=(1,), state=right, group="First block"),
            FactorPanel("hold", right, braid_word=(), state=right, group="First block"),
            FactorPanel("b", right, exponent=-2, braid_word=(-2, 1, -1), state=left, group="Second block"),
        ), strands=3, initial_state=left)
        actual, title = diagram(SOURCE)
        self.assertEqual(actual.factor_ids, ("a", "hold", "b"))
        self.assertEqual(actual.product_label, "[b]^-2 * [hold] * [a]")
        self.assertEqual(render_svg(actual, title=title), render_svg(expected, title=title))
        self.assertEqual(render_tikz(actual, title=title), render_tikz(expected, title=title))
        self.assertIn("Supplied left arc", render_svg(actual))
        self.assertEqual(actual.factors[2].braid_word, (-2, 1, -1))

    def test_cli_outputs_are_reproducible(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "workspace.json"
            source.write_text(SOURCE)
            command = [sys.executable, str(ROOT / "godot/bridge/render_document.py"), str(source), str(root / "a.svg"), str(root / "a.tikz")]
            first = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            svg, tikz = (root / "a.svg").read_bytes(), (root / "a.tikz").read_bytes()
            second = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
            self.assertEqual(svg, (root / "a.svg").read_bytes())
            self.assertEqual(tikz, (root / "a.tikz").read_bytes())
            source.write_text(SOURCE.replace('"after": "rightArc"', '"after": null', 1))
            failed = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(failed.returncode, 1)
            self.assertIn("Incomplete supplied states", failed.stdout)

    def test_absence_is_not_an_action(self):
        raw = json.loads(SOURCE)
        raw["factors"][0]["after"] = None
        parsed, _ = parse(json.dumps(raw))
        self.assertIsNone(parsed["factors"][0]["after"])
        with self.assertRaisesRegex(ValueError, "Incomplete supplied states"):
            diagram(json.dumps(raw))
        raw["initial_state"] = None
        for factor in raw["factors"]:
            factor["after"] = None
        result, _ = diagram(json.dumps(raw))
        self.assertIsNone(result.initial_state)
        self.assertTrue(all(f.state is None for f in result.factors))
        self.assertNotIn("After [", render_svg(result))

    def test_continuous_id_colors_through_empty_and_tall_blocks_both_directions(self):
        raw = json.loads(SOURCE)
        raw["documents"]["leftArc"]["surface"]["height"] = 600
        for direction in ("bottom-to-top", "top-to-bottom"):
            raw["direction"] = direction
            result, _ = diagram(json.dumps(raw))
            drawing = layout(result, Style())
            paths = [p for p in drawing.paths if p.role == "braid-strand"]
            levels = [paths[i:i+3] for i in range(0, len(paths), 3)]
            for previous, following in zip(levels, levels[1:]):
                for path in previous:
                    continuation = next(p for p in following if p.stroke == path.stroke)
                    self.assertEqual(path.commands[-1][1:], continuation.commands[0][1:])
            crossing_levels = [level for level in levels if any(len(p.commands) == 4 for p in level)]
            self.assertEqual(len(crossing_levels), 4)
            for level, generator in zip(crossing_levels, (1, -2, 1, -1)):
                under = next(p for p in level if len(p.commands) == 4)
                endpoints = (under.commands[0][1:], under.commands[-1][1:])
                upper = max(endpoints, key=lambda p: p[1])
                lower = min(endpoints, key=lambda p: p[1])
                self.assertEqual(upper[0] > lower[0], generator > 0)

    def test_rejects_ambiguous_or_executable_fields(self):
        for text in ("[]", "{}", SOURCE + "x", " " * (256*1024+1),
                     SOURCE.replace('"version": 1,', '"version": 1, "version": 1,', 1)):
            with self.subTest(text=text[:25]), self.assertRaises(ValueError):
                parse(text)
        cases = []
        original = json.loads(SOURCE)
        for key, value in (("version", True), ("version", 2), ("strands", 33), ("strands", True),
                           ("initial_state", "absent"), ("script", "evil.py"), ("documents", [])):
            raw = deepcopy(original)
            raw[key] = value
            cases.append(raw)
        for key, value in (("id", "hold"), ("exponent", 0), ("exponent", True), ("exponent", 1000001),
                           ("braid_word", [3]), ("braid_word", [True]), ("braid_word", [1]*129),
                           ("support", None), ("after", "absent"), ("script", "evil.gd")):
            raw = deepcopy(original)
            raw["factors"][0][key] = value
            cases.append(raw)
        raw = deepcopy(original)
        raw["factors"][1]["group"] = "separate"
        raw["factors"][2]["group"] = "First block"
        cases.append(raw)
        for raw in cases:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                parse(json.dumps(raw))

    def test_empty_workspace_does_not_manufacture_factors(self):
        raw = json.loads(SOURCE)
        raw.update(factors=[], initial_state=None, documents={})
        result, _ = diagram(json.dumps(raw))
        self.assertEqual(result.factors, ())
        self.assertEqual(result.product_label, "1")
        self.assertIn("Empty factor sequence", render_svg(result))


if __name__ == "__main__":
    unittest.main()
