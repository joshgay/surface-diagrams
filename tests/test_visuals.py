import unittest
from dataclasses import replace
from xml.etree import ElementTree as ET

from surface_diagrams import (Arc, Loop, PlanarSurface, Style, ColoredCurve,
    PlanarDiagram, Figure, Panel, BraidDiagram, RAINBOW, RoutingError, render_svg, render_tikz)
from surface_diagrams.layout import layout


class VisualsTest(unittest.TestCase):
    def setUp(self):
        self.surface = PlanarSurface.row('PPPP', spacing=60, height=210, margin=65)

    def test_intersections_are_opt_in_and_colors_follow_ids(self):
        curves = (ColoredCurve('a', Arc(1,3), RAINBOW[0]),
                  ColoredCurve('b', Arc(2,4), RAINBOW[4]))
        with self.assertRaises(RoutingError):
            layout(PlanarDiagram(self.surface, curves), Style())
        d = layout(PlanarDiagram(self.surface, curves, allow_intersections=True), Style())
        self.assertEqual([p.stroke for p in d.paths], [RAINBOW[0], RAINBOW[4]])
        # Two overlapping upper semicircles have an actual transverse crossing;
        # overlay mode must retain both complete curves, not reconnect their ends.
        self.assertEqual([p.commands[0][1] for p in d.paths], [-90, -30])
        self.assertEqual([p.commands[-1][-2] for p in d.paths], [30, 90])
        with self.assertRaises(RoutingError):
            render_svg(PlanarDiagram(self.surface, (ColoredCurve('bad', Arc(0,3), '#f00'),), True))

    def test_disjoint_mode_keeps_joint_routing_and_rejects_duplicate_ids(self):
        curves = (ColoredCurve('a', Arc(1,2), '#f00'), ColoredCurve('b', Arc(3,4), '#00f'))
        self.assertEqual(len(layout(PlanarDiagram(self.surface, curves), Style()).paths), 2)
        with self.assertRaises(ValueError):
            PlanarDiagram(self.surface, (curves[0], curves[0]))

    def test_legends_preserve_curve_identity_geometry_and_export(self):
        curves = (ColoredCurve('reference <a>', Arc(1,3), RAINBOW[0]),
                  ColoredCurve('image & b', Arc(2,4), RAINBOW[4]))
        plain = PlanarDiagram(self.surface, curves, True)
        original = layout(plain, Style())
        d = layout(replace(plain, show_legend=True), Style())
        self.assertEqual([(t.text,t.color) for t in d.texts], [(c.id,c.color) for c in curves])
        self.assertGreater(d.height, original.height)
        paths = [p for p in d.paths if p.role == 'arc']
        for before, after in zip(original.paths, paths):
            self.assertEqual(before.commands[0][1], after.commands[0][1])
            self.assertEqual(before.commands[1][1:6], after.commands[1][1:6])
        self.assertEqual(len([p for p in d.paths if p.role == 'curve-legend']), 2)
        reverse = layout(replace(plain, curves=curves[::-1], show_legend=True), Style())
        self.assertEqual([(t.text,t.color) for t in reverse.texts], [(c.id,c.color) for c in curves[::-1]])
        root = ET.fromstring(render_svg(replace(plain, show_legend=True)))
        self.assertIn('reference <a>', [t.text for t in root.iter()])
        self.assertIn('curve-legend', render_tikz(replace(plain, show_legend=True)))
        self.assertEqual(layout(PlanarDiagram(self.surface, show_legend=True), Style()),
                         layout(PlanarDiagram(self.surface), Style()))
        with self.assertRaises(ValueError):
            PlanarDiagram(self.surface, show_legend='yes')

    def test_braid_sign_changes_underpass_and_strand_transport(self):
        for word, under in (((1,), 1), ((-1,), 0)):
            d = layout(BraidDiagram(3, word), Style())
            self.assertEqual([i for i,p in enumerate(d.paths) if sum(c[0]=='M' for c in p.commands)==2], [under])
            bottom = [t.text for t in d.texts if t.y < 0]
            self.assertEqual(bottom, ['2','1','3'])
        d = layout(BraidDiagram(3, (1,-1)), Style())
        self.assertEqual([t.text for t in d.texts if t.y < 0], ['1','2','3'])
        self.assertEqual([p.stroke for p in d.paths[3:]], [RAINBOW[1],RAINBOW[0],RAINBOW[2]])
        empty = layout(BraidDiagram(2), Style())
        self.assertTrue(all(len(p.commands)==2 for p in empty.paths))
        for word in ((0,), (3,), (True,)):
            with self.assertRaises(ValueError):
                BraidDiagram(3, word)

    def test_figure_translates_arcs_preserving_radii_and_aligns_columns(self):
        diagram = self.surface.with_curves(Loop((0,4)))
        figure = Figure(((Panel(diagram, 'first'), Panel(BraidDiagram(3,(1,)))),
                         (Panel(diagram, 'second'), Panel(BraidDiagram(3,(1,2,1))))))
        original = layout(diagram, Style()).paths[0]
        d = layout(figure, Style())
        loops = [p for p in d.paths if p.role=='closed-curve']
        self.assertEqual(len(loops), 2)
        self.assertEqual(loops[0].commands[1][1:6], original.commands[1][1:6])
        self.assertEqual(loops[0].commands[0][1], loops[1].commands[0][1])
        self.assertGreater(loops[0].commands[0][2], loops[1].commands[0][2])
        ET.fromstring(render_svg(figure))
        self.assertIn('braid-strand', render_tikz(figure))

    def test_circle_panels_clip_in_svg_and_cannot_bypass_tikz_guard(self):
        circle = PlanarSurface.row('BP', spacing=60, height=140, margin=60).with_curves(Arc(1,2))
        figure = Figure(((Panel(circle, 'boundary to point', Style(boundary_shape='circle')),),))
        root = ET.fromstring(render_svg(figure))
        self.assertIsNotNone(root.find('.//{http://www.w3.org/2000/svg}clipPath'))
        with self.assertRaises(NotImplementedError):
            render_tikz(figure)
        with self.assertRaises(ValueError):
            Panel(circle, style=Style(background='#fff'))


if __name__ == '__main__':
    unittest.main()
