import unittest
from dataclasses import replace
from math import hypot
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
            self.assertGreater(width, surface.handle_spacing*.50)
            self.assertGreater(midpoint*2/width, .17)
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

    def test_silhouette_reflection_and_view_reversal(self):
        p = presentation(GenusSurface(type_i=(TypeIBoundary(2),), type_ii=(BoundaryPair(),)))
        for commands in p.contours:
            reflected = _transform(commands, lambda x, y: (x, -y))
            self.assertIn(reflected, p.contours)
        above = presentation(GenusSurface(type_i=(TypeIBoundary(2),), type_ii=(BoundaryPair(),),
                                          view_vertical='above'))
        self.assertEqual(above.contours, p.contours)
        self.assertEqual(above.handles, tuple(_transform(c, lambda x,y: (x,-y)) for c in p.handles))

    def test_four_views_expose_correct_boundary_faces(self):
        surface = GenusSurface(type_i=tuple(TypeIBoundary(i) for i in range(1,7)),
                               type_ii=(BoundaryPair(),))
        for vertical in ('above','below'):
            for horizontal in ('left','right'):
                with self.subTest(vertical=vertical, horizontal=horizontal):
                    p = presentation(replace(surface, view_vertical=vertical, view_horizontal=horizontal))
                    rims = {r.id:r for r in p.rims}
                    self.assertEqual(rims['fixed-1'].hidden_inner, horizontal == 'right')
                    self.assertEqual(rims['fixed-6'].hidden_inner, horizontal == 'left')
                    self.assertEqual(rims['fixed-2'].hidden_inner, horizontal == 'left')
                    self.assertEqual(rims['fixed-3'].hidden_inner, horizontal == 'right')
                    self.assertEqual(rims['pair-1-upper'].hidden_inner, vertical == 'below')
                    self.assertEqual(rims['pair-1-lower'].hidden_inner, vertical == 'above')
                    for r in p.rims:
                        self.assertEqual(p.faces_viewer(r.normal), not r.hidden_inner)
                    paths = p.drawing(Style()).paths
                    self.assertEqual(sum(path.dashed for path in paths), sum(r.hidden_inner for r in p.rims))
                    ET.fromstring(render_svg(replace(surface, view_vertical=vertical, view_horizontal=horizontal)))

    def test_side_pairs_visibility_follows_horizontal_view(self):
        base = GenusSurface(type_ii=(BoundaryPair('left'),BoundaryPair('right')))
        for horizontal in ('left','right'):
            p = presentation(replace(base, view_horizontal=horizontal))
            for r in p.rims:
                self.assertEqual(r.hidden_inner, (r.x < 0) == (horizontal == 'right'))

    def test_hole_overlap_is_real_geometry_in_every_view(self):
        def point(c,t):
            a = c[0][1:]
            b,cc,d = c[1][1:3],c[1][3:5],c[1][5:7]
            return tuple((1-t)**3*a[i]+3*t*(1-t)**2*b[i]+3*t*t*(1-t)*cc[i]+t**3*d[i]
                         for i in (0,1))
        for vertical in ('above','below'):
            for horizontal in ('left','right'):
                p = presentation(GenusSurface(3,view_vertical=vertical,view_horizontal=horizontal))
                for near,far in zip(p.handles[::2],p.handles[1::2]):
                    self.assertLess(near[0][1], far[0][1])
                    self.assertGreater(near[-1][-2],far[-1][-2])
                    samples = [point(near,i/1000) for i in range(1,1000)]
                    for end in (far[0][1:],far[-1][-2:]):
                        self.assertLess(min(hypot(x-end[0],y-end[1]) for x,y in samples),1e-8)
                    self.assertEqual(point(near,.5)[1] > point(far,.5)[1], vertical == 'above')

    def test_horizontal_view_mirrors_hole_occlusion(self):
        right = presentation(GenusSurface(1)).handles
        left = presentation(GenusSurface(1,view_horizontal='left')).handles
        for r,l in zip(right,left):
            # Reverse the reflected cubic to compare paths in left-to-right order.
            points = [r[0][1:],r[1][1:3],r[1][3:5],r[1][5:7]]
            expected = [(-x,y) for x,y in reversed(points)]
            actual = [l[0][1:],l[1][1:3],l[1][3:5],l[1][5:7]]
            for a,b in zip(actual,expected):
                for x,y in zip(a,b):
                    self.assertAlmostEqual(x,y)

    def test_side_pair_defaults_give_room_and_larger_openings(self):
        surface = GenusSurface(3,type_ii=(BoundaryPair('left'),BoundaryPair('right'),
                                         BoundaryPair(),BoundaryPair()))
        self.assertGreater(surface.height,GenusSurface(3).height)
        self.assertEqual(replace(surface,height=120).height,120)
        rims = {r.id:r for r in presentation(surface).rims}
        left = rims['pair-1-upper']
        self.assertGreater(left.radius,25)
        self.assertGreater(left.y-left.radius,20)
        self.assertGreater(rims['pair-4-upper'].x-rims['pair-3-upper'].x,200)

    def test_end_rims_keep_a_balanced_strip_in_all_views(self):
        for genus, spacing, height in ((2,110,150), (3,110,150), (5,145,180)):
            for end in ('left','right'):
                slot = 1 if end == 'left' else 2*genus+2
                other = 'right' if end == 'left' else 'left'
                surface = GenusSurface(genus, handle_spacing=spacing, height=height,
                    type_i=(TypeIBoundary(slot),),
                    type_ii=(BoundaryPair(other),BoundaryPair(),BoundaryPair()))
                for vertical in ('above','below'):
                    for horizontal in ('left','right'):
                        p = presentation(replace(surface,view_vertical=vertical,view_horizontal=horizontal))
                        rim = next(r for r in p.rims if r.id == f'fixed-{slot}')
                        inter = p.handles[2][0][1]-p.handles[0][-1][-2]
                        gap = (rim.x-rim.depth-p.handles[-2][-1][-2] if end == 'right'
                               else p.handles[0][0][1]-rim.x-rim.depth)
                        self.assertGreaterEqual(gap, .95*inter)
                        self.assertLessEqual(gap, 1.5*inter)
                        drawing = p.drawing(Style())
                        self.assertLess(rim.extents[0],drawing.width/2)
                        for anchor in rim.anchors:
                            self.assertTrue(any(anchor in (c[0][1:],c[-1][-2:]) for c in p.contours))

    def test_d3_end_contours_join_directly_to_top_rims(self):
        p = presentation(GenusSurface(3,type_i=(TypeIBoundary(8),),type_ii=(BoundaryPair(),)*6))
        end = next(r for r in p.rims if r.id == 'fixed-8')
        for anchor in end.anchors:
            c = next(c for c in p.contours if c[-1][-2:] == anchor)
            self.assertEqual(len(c),2)
            self.assertAlmostEqual(c[-1][-3],anchor[1])
            self.assertLess(c[-1][-4],anchor[0])

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
                        lambda: GenusSurface(view_vertical='sideways'),
                        lambda: GenusSurface(view_horizontal='above'),
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

    def test_axis_without_additional_handle(self):
        d = layout(GenusSurface(3, show_axis=True), Style())
        self.assertEqual(sum(p.role == 'handle-back' for p in d.paths), 0)
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
