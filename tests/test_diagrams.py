import tempfile
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

from surface_diagrams import Boundary, MarkedPoint, PlanarSurface, Style, render_svg, save_svg


class DiagramsTest(unittest.TestCase):
    def parse(self, surface, **options):
        return ET.fromstring(render_svg(surface, **options))

    def dots(self, root):
        return root.findall("{http://www.w3.org/2000/svg}circle")

    def test_mixed_row_order_colors_and_spacing(self):
        dots = self.dots(self.parse(PlanarSurface.row("B P B P P", spacing=40)))
        self.assertEqual([d.attrib["class"] for d in dots],
                         ["inner-boundary", "marked-point", "inner-boundary", "marked-point", "marked-point"])
        self.assertEqual([d.attrib["fill"] for d in dots],
                         ["#8b8b8b", "#006fff", "#8b8b8b", "#006fff", "#006fff"])
        self.assertEqual([float(d.attrib["cx"]) - float(dots[0].attrib["cx"]) for d in dots], [0, 40, 80, 120, 160])

    def test_outline_toggle_preserves_viewbox_and_positions(self):
        surface = PlanarSurface.row("BPP")
        shown = self.parse(surface)
        hidden = self.parse(surface, style=Style(show_outer_ellipse=False))
        self.assertEqual(shown.attrib["viewBox"], hidden.attrib["viewBox"])
        self.assertEqual([d.attrib for d in self.dots(shown)], [d.attrib for d in self.dots(hidden)])
        self.assertEqual(len(hidden.findall("{http://www.w3.org/2000/svg}ellipse")), 0)

    def test_custom_coordinates_and_radius_overrides(self):
        surface = PlanarSurface([Boundary(-40, radius=9), Boundary(0), MarkedPoint(40, 15)])
        root = self.parse(surface, style=Style(boundary_radius=6, marked_point_radius=3))
        dots = self.dots(root)
        self.assertEqual([d.attrib["r"] for d in dots], ["9", "6", "3"])
        self.assertEqual(float(dots[0].attrib["cy"]) - float(dots[2].attrib["cy"]), 15)

    def test_scale_changes_only_display_dimensions(self):
        surface = PlanarSurface.row("P")
        one, two = self.parse(surface), self.parse(surface, scale=2)
        self.assertEqual(one.attrib["viewBox"], two.attrib["viewBox"])
        self.assertEqual(float(two.attrib["width"]), 2 * float(one.attrib["width"]))
        self.assertEqual([d.attrib for d in self.dots(one)], [d.attrib for d in self.dots(two)])

    def test_empty_disk_and_transparent_background(self):
        root = self.parse(PlanarSurface.row(""))
        self.assertEqual(len(self.dots(root)), 0)
        self.assertEqual(len(root.findall("{http://www.w3.org/2000/svg}rect")), 0)

    def test_title_escaping_and_deterministic_utf8_save(self):
        surface = PlanarSurface.row("BP")
        title = '<surface & "points">'
        expected = render_svg(surface, title=title)
        self.assertEqual(ET.fromstring(expected)[0].text, title)
        with tempfile.TemporaryDirectory() as temp:
            path = save_svg(surface, Path(temp) / "nested" / "figure.svg", title=title)
            self.assertEqual(path.read_text(encoding="utf-8"), expected)
            self.assertEqual(render_svg(surface, title=title), expected)

    def test_bad_coordinates_sizes_and_patterns(self):
        for value in (float("nan"), float("inf"), -1, 0, True):
            with self.subTest(value=value), self.assertRaises(ValueError):
                Style(marked_point_radius=value)
        with self.assertRaises(ValueError):
            PlanarSurface([MarkedPoint(120)])
        with self.assertRaises(ValueError):
            PlanarSurface.row("BPX")
        with self.assertRaises(ValueError):
            render_svg(PlanarSurface.row("B"), style=Style(boundary_radius=40))
        with self.assertRaises(ValueError):
            Style(boundary_color='url(https://example.com/image)')
        with self.assertRaises(ValueError):
            save_svg(PlanarSurface(), "not-a-png.png")


if __name__ == "__main__":
    unittest.main()
