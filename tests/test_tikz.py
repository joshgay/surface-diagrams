import importlib.util
from math import cos, sin, radians
from pathlib import Path
import re
import tempfile
import unittest

from surface_diagrams import (
    Arc, Boundary, GenusSurface, PlanarSurface, RoutingError, Style, render_tikz, save_tikz,
)
from surface_diagrams.curves import route
from surface_diagrams.layout import layout
from surface_diagrams.tikz import _path, _text


class TikzTest(unittest.TestCase):
    def test_all_gallery_geometry_is_exported(self):
        file = Path(__file__).resolve().parents[1] / "examples" / "gallery.py"
        spec = importlib.util.spec_from_file_location("gallery", file)
        gallery = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gallery)
        for examples in gallery.gallery_examples().values():
            for name, caption, surface, style in examples:
                with self.subTest(name=name):
                    result = render_tikz(surface, style=style, title=caption)
                    drawing = layout(surface, style)
                    self.assertEqual(result.count(r"\draw["), len(drawing.paths))
                    self.assertEqual(result.count(" ellipse ["), len(drawing.ellipses)+sum(e.role == "inner-boundary-circle" for e in drawing.ellipses))
                    self.assertEqual(result.count(r"\node["), len(drawing.texts))
                    self.assertEqual(result, render_tikz(surface, style=style, title=caption))

    def test_arc_midpoints_and_endpoints_match_router_both_directions(self):
        row = PlanarSurface.row("PPPPPP", spacing=55, height=210, margin=60)
        for start, end in ((1, 4), (4, 1)):
            for direction in ("up", "down"):
                with self.subTest(start=start, direction=direction):
                    surface = row.with_curves(Arc(start, end, direction=direction))
                    piece, = route(surface, Style())
                    result = render_tikz(surface)
                    match = re.search(r"arc\[start angle=(-?\d+),end angle=(-?\d+),x radius=([^,]+),y radius=([^\]]+)", result)
                    a, b, rx, ry = map(float, match.groups())
                    center = piece.start-rx*cos(radians(a))
                    for t in (0, .25, .5, .75, 1):
                        angle = radians(a+(b-a)*t)
                        actual = (center+rx*cos(angle), ry*sin(angle))
                        expected = piece.point(t)
                        for x, y in zip(actual, expected):
                            self.assertAlmostEqual(x, y, places=8)

    def test_straight_default_and_invalid_route(self):
        row = PlanarSurface.row("PPP")
        result = render_tikz(row.with_curves(Arc(1, 2)))
        self.assertNotIn("arc[start", result)
        with self.assertRaises(RoutingError):
            render_tikz(row.with_curves(Arc(0, 3)))

    def test_scale_includes_strokes_dashes_and_labels(self):
        surface = PlanarSurface.row("PP")
        result = render_tikz(surface, style=Style(show_guides=True), scale=2)
        self.assertIn("x=1.5bp,y=1.5bp", result)
        self.assertIn("line width=2.25bp", result)
        self.assertIn("on 4.5bp off 4.5bp", result)
        self.assertIn(r"\fontsize{13.5bp}{16.2bp}", result)

    def test_palette_background_and_frame(self):
        surface = GenusSurface()
        one = render_tikz(surface)
        two = render_tikz(surface, style=Style(background="#abc", outline_color="#123"))
        self.assertNotIn(r"\fill[", one)
        self.assertIn("{HTML}{AABBCC}", two)
        self.assertIn("{HTML}{112233}", two)
        self.assertEqual(re.search(r"\\clip (.*);", one)[1], re.search(r"\\clip (.*);", two)[1])

    def test_plain_text_and_multiline_title(self):
        self.assertEqual(_text(r"a_b%{x}\&"), r"a\_b\%\{x\}\textbackslash{}\&")
        result = render_tikz(PlanarSurface(), title="hello\n\\input{bad}")
        self.assertIn("% hello\n% \\input{bad}", result)
        self.assertNotIn("^^", render_tikz(PlanarSurface(), title="^^0a"))

    def test_save_and_validation_do_not_overwrite_on_error(self):
        with tempfile.TemporaryDirectory() as temp:
            path = save_tikz(PlanarSurface(), Path(temp)/"nested"/"figure.tikz")
            before = path.read_text(encoding="utf-8")
            self.assertEqual(before, render_tikz(PlanarSurface()))
            with self.assertRaises(ValueError):
                save_tikz(PlanarSurface(), path, scale=0)
            self.assertEqual(path.read_text(encoding="utf-8"), before)
            with self.assertRaises(ValueError):
                save_tikz(PlanarSurface(), Path(temp)/"figure.tex")
        for kwargs in ({"scale": True}, {"scale": float("nan")}, {"scale": -1}):
            with self.assertRaises(ValueError):
                render_tikz(PlanarSurface(), **kwargs)
        for kwargs in ({"style": {}}, {"title": 3}):
            with self.assertRaises(TypeError):
                render_tikz(PlanarSurface(), **kwargs)
        with self.assertRaises(TypeError):
            render_tikz("PP")

    def test_unsupported_internal_geometry_is_explicit(self):
        with self.assertRaises(ValueError):
            _path((("M", 0, 0), ("Q", 1, 2, 3, 4)))
        with self.assertRaises(ValueError):
            _path((("M", 0, 0), ("A", 10, 5, 20, 0, 0, 20, 0)))


if __name__ == "__main__":
    unittest.main()
