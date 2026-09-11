import unittest
from xml.etree import ElementTree as ET

from surface_diagrams import GenusSurface, TypeIBoundary, BoundaryPair, Style, render_svg
from surface_diagrams.genus_geometry import presentation, _transform
from surface_diagrams.layout import layout


class GenusTest(unittest.TestCase):
    def test_low_default_body_and_shallow_openings(self):
        surface = GenusSurface()
        self.assertGreater(surface.width/surface.height, 2.5)
        p = presentation(surface)
        for commands in p.handles:
            start = commands[0][1:]
            cubic = commands[1][1:]
            width = cubic[-2]-start[0]
            midpoint = abs((start[1]+3*cubic[1]+3*cubic[3]+cubic[5])/8)
            self.assertGreater(width, surface.handle_spacing*.55)
            self.assertGreater(midpoint*2/width, .2)
            self.assertLess(midpoint*2/width, .4)

    def test_default_top_has_no_per_handle_scallops(self):
        p = presentation(GenusSurface(5))
        top = [c for c in p.contours if c[0][2] > 40 and c[-1][-1] > 40]
        self.assertEqual(len(top), 1)
        ys = [v for command in top[0] for v in command[2::2]]
        self.assertLess(max(ys)-min(ys), 1)

    def test_closed_surfaces_have_requested_handle_count(self):
        for genus in (1, 2, 3, 5, 7):
            with self.subTest(genus=genus):
                p = presentation(GenusSurface(genus))
                self.assertEqual(len(p.handles), 2*genus)
                self.assertFalse(p.rims)
                ET.fromstring(render_svg(GenusSurface(genus)))

    def test_all_six_genus_two_fixed_slots(self):
        p = presentation(GenusSurface(type_i=tuple(TypeIBoundary(i) for i in range(1, 7))))
        self.assertEqual(len(p.rims), 6)
        self.assertEqual({r.id for r in p.rims}, {f"fixed-{i}" for i in range(1, 7)})
        self.assertTrue(all(r.y == 0 for r in p.rims))
        self.assertEqual(len({r.x for r in p.rims}), 6)

    def test_pairs_are_distinct_reflections_and_fit_canvas(self):
        surface = GenusSurface(type_ii=(BoundaryPair('left'), BoundaryPair('right'), BoundaryPair()))
        p = presentation(surface)
        d = p.drawing(Style())
        self.assertEqual(len(p.rims), 6)
        for rim in p.rims:
            self.assertIn((rim.x, -rim.y), [(r.x, r.y) for r in p.rims])
            ex, ey = rim.extents
            self.assertLess(ex, d.width/2)
            self.assertLess(ey, d.height/2)

    def test_side_rims_open_sideways(self):
        p = presentation(GenusSurface(type_ii=(BoundaryPair('left'), BoundaryPair('right'))))
        for r in p.rims:
            self.assertEqual(r.normal[1], 0)
            self.assertEqual(r.tangent[0], 0)
            self.assertEqual(r.anchors[0][0], r.anchors[1][0])

    def test_silhouette_and_handle_reflection(self):
        p = presentation(GenusSurface(type_i=(TypeIBoundary(2),), type_ii=(BoundaryPair(),)))
        for commands in p.contours+p.handles:
            reflected = _transform(commands, lambda x, y: (x, -y))
            self.assertIn(reflected, p.contours+p.handles)

    def test_every_rim_anchor_joins_an_actual_contour(self):
        for surface in (
            GenusSurface(type_i=tuple(TypeIBoundary(i) for i in range(1, 7))),
            GenusSurface(3, type_ii=(BoundaryPair('left'), BoundaryPair('right'), BoundaryPair(), BoundaryPair())),
        ):
            with self.subTest(surface=surface):
                p = presentation(surface)
                ends = [point for c in p.contours+p.handles
                        for point in (c[0][1:], c[-1][-2:])]
                for rim in p.rims:
                    for anchor in rim.anchors:
                        self.assertTrue(any(abs(x-anchor[0])+abs(y-anchor[1]) < 1e-8 for x, y in ends))
                        for half in (rim.half(1), rim.half(-1)):
                            self.assertIn(anchor, (half[0][1:], half[-1][-2:]))

    def test_contours_have_no_unattached_endpoints(self):
        p = presentation(GenusSurface(3, type_i=(TypeIBoundary(8),),
                                     type_ii=(BoundaryPair('left'),)+(BoundaryPair(),)*6))
        ends = [point for c in p.contours for point in (c[0][1:], c[-1][-2:])]
        anchors = [point for r in p.rims for point in r.anchors]
        for i, (x, y) in enumerate(ends):
            other = ends[:i]+ends[i+1:]+anchors
            self.assertTrue(any(abs(x-a)+abs(y-b) < 1e-8 for a, b in other))

    def test_neck_joins_have_continuous_tangents(self):
        p = presentation(GenusSurface(type_ii=(BoundaryPair('left'), BoundaryPair('right'), BoundaryPair())))
        for commands in p.contours:
            previous = None
            for op, *v in commands:
                if op == 'C' and previous is not None:
                    point = previous[-2:]
                    incoming = (point[0]-previous[-4], point[1]-previous[-3])
                    outgoing = (v[0]-point[0], v[1]-point[1])
                    cross = incoming[0]*outgoing[1]-incoming[1]*outgoing[0]
                    self.assertAlmostEqual(cross, 0, places=7)
                    self.assertGreaterEqual(incoming[0]*outgoing[0]+incoming[1]*outgoing[1], -1e-8)
                previous = v if op == 'C' else None

    def test_automatic_pairs_are_spaced_without_tuning(self):
        for count in (1, 2, 4, 6):
            p = presentation(GenusSurface(3, type_ii=(BoundaryPair(),)*count))
            upper = sorted((r.x, r.radius) for r in p.rims if r.y > 0)
            self.assertEqual(len(p.rims), 2*count)
            for (x, r), (xx, rr) in zip(upper, upper[1:]):
                self.assertGreater(xx-x, 1.2*(r+rr))
        # Aliases participate in the same placement region.
        p = presentation(GenusSurface(type_ii=(BoundaryPair('bottom'), BoundaryPair('top-bottom'))))
        self.assertEqual(len({(r.x, r.y) for r in p.rims}), 4)

    def test_rim_ids_do_not_depend_on_dimensions(self):
        pairs = (BoundaryPair('right'), BoundaryPair(), BoundaryPair('left'), BoundaryPair())
        a = presentation(GenusSurface(type_ii=pairs))
        b = presentation(GenusSurface(type_ii=pairs, height=140, handle_spacing=150))
        self.assertEqual([r.id for r in a.rims], [r.id for r in b.rims])

    def test_hidden_halves_and_transparent_background(self):
        surface = GenusSurface(type_ii=(BoundaryPair('left'), BoundaryPair('right'), BoundaryPair()))
        p = presentation(surface)
        d = p.drawing(Style())
        self.assertTrue(any(r.hidden_inner for r in p.rims))
        self.assertTrue(any(not r.hidden_inner for r in p.rims))
        self.assertEqual(sum(path.dashed for path in d.paths), sum(r.hidden_inner for r in p.rims))
        root = ET.fromstring(render_svg(surface))
        self.assertFalse(root.findall('{http://www.w3.org/2000/svg}rect'))
        self.assertTrue(all(e.attrib.get('fill') == 'none'
                            for e in root.findall('{http://www.w3.org/2000/svg}path')))
        colored = ET.fromstring(render_svg(surface, style=Style(background='#cdefab')))
        self.assertEqual(len(colored.findall('{http://www.w3.org/2000/svg}rect')), 1)

    def test_top_collars_are_short(self):
        surface = GenusSurface(1, type_ii=(BoundaryPair(),))
        p = presentation(surface)
        upper = next(r for r in p.rims if r.y > 0)
        self.assertGreater(upper.y+upper.depth, surface.height*.44)
        self.assertLess(upper.y+upper.depth-surface.height*.44, upper.radius)

    def test_invalid_boundary_geometry(self):
        for factory in (lambda: GenusSurface(0),
                        lambda: GenusSurface(type_i=(TypeIBoundary(7),)),
                        lambda: GenusSurface(type_i=(TypeIBoundary(1), TypeIBoundary(1))),
                        lambda: BoundaryPair('inside'),
                        lambda: BoundaryPair(position=float('nan')),
                        lambda: BoundaryPair(radius=0)):
            with self.assertRaises(ValueError):
                factory()
        for surface in (GenusSurface(type_ii=(BoundaryPair('top', .5), BoundaryPair('top', .5))),
                        GenusSurface(type_i=(TypeIBoundary(2, 99),)),
                        GenusSurface(type_ii=(BoundaryPair('left', radius=99),)),
                        GenusSurface(type_ii=(BoundaryPair('top', radius=.1),))):
            with self.assertRaises(ValueError):
                render_svg(surface)

    def test_balloon_and_axis_options(self):
        d = layout(GenusSurface(3, handle_style='balloon', show_axis=True), Style())
        self.assertEqual(sum(p.role == 'handle-back' for p in d.paths), 3)
        self.assertEqual(sum(p.role == 'involution-axis' for p in d.paths), 1)

    def test_scale_preserves_geometry(self):
        surface = GenusSurface(type_ii=(BoundaryPair('left'), BoundaryPair()))
        a = ET.fromstring(render_svg(surface))
        b = ET.fromstring(render_svg(surface, scale=3))
        self.assertEqual(a.attrib['viewBox'], b.attrib['viewBox'])
        self.assertEqual([e.attrib for e in a[1:]], [e.attrib for e in b[1:]])
        self.assertAlmostEqual(float(b.attrib['width']), 3*float(a.attrib['width']), places=7)


if __name__ == '__main__':
    unittest.main()
