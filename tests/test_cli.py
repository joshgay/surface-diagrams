import subprocess
import sys
import tempfile
from pathlib import Path
import unittest


class CliTest(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, "-m", "surface_diagrams", *map(str, args)],
                              capture_output=True, text=True)

    def test_svg_and_tikz(self):
        with tempfile.TemporaryDirectory() as temp:
            for options, suffix, marker in ((["--row", "BP"], ".svg", "<svg"),
                                             (["--genus", "2"], ".tikz", r"\begin{tikzpicture}")):
                with self.subTest(suffix=suffix):
                    path = Path(temp)/("surface"+suffix)
                    result = self.run_cli(*options, path)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(marker, path.read_text(encoding="utf-8"))

    def test_bad_inputs_do_not_replace_output(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/"surface.svg"
            path.write_text("preserve me")
            for args in (["--genus", "0"], ["--row", "X"], ["--row", "P", "--scale", "nan"],
                         ["--row", "P", "--genus", "2"]):
                result = self.run_cli(*args, path)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Traceback", result.stderr)
                self.assertEqual(path.read_text(), "preserve me")
