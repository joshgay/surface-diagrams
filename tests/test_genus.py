import unittest
from xml.etree import ElementTree as ET
from surface_diagrams import GenusSurface, TypeIBoundary, BoundaryPair, Style, render_svg
from surface_diagrams.layout import layout


class GenusTest(unittest.TestCase):
    def test_compact_defaults_and_larger_handle_openings(self):
        surface=GenusSurface()
        self.assertLess(surface.width/surface.height,2)
        d=layout(surface,Style())
        upper=next(p for p in d.paths if p.role=='handle')
        start=upper.commands[0][1:]
        cubic=upper.commands[1][1:]
        self.assertGreater(cubic[-2]-start[0],surface.handle_spacing*.6)
        # Actual cubic midpoint, not its taller control polygon.
        midpoint_y=(start[1]+3*cubic[1]+3*cubic[3]+cubic[5])/8
        self.assertGreater(midpoint_y,surface.height*.2)
        self.assertLess(midpoint_y,surface.height*.35)

    def test_top_boundary_necks_protrude_only_slightly(self):
        surface=GenusSurface(1,type_ii=(BoundaryPair("top"),))
        d=layout(surface,Style())
        rim=next(e for e in d.ellipses if e.y>0)
        silhouette_peak=.96*surface.height/2
        self.assertGreater(rim.y+rim.ry,silhouette_peak)
        self.assertLess(rim.y+rim.ry-silhouette_peak,rim.rx)

    def test_closed_surfaces_have_requested_handle_count(self):
        for g in (1,2,3,7):
            d=layout(GenusSurface(g),Style())
            self.assertEqual(sum(p.role=='handle' for p in d.paths),2*g)
            self.assertFalse(d.ellipses)
            ET.fromstring(render_svg(GenusSurface(g)))

    def test_all_six_genus_two_fixed_slots(self):
        d=layout(GenusSurface(type_i=tuple(TypeIBoundary(i) for i in range(1,7))),Style())
        holes=[e for e in d.ellipses if e.role=='type-i-boundary']
        self.assertEqual(len(holes),6)
        self.assertTrue(all(e.y==0 for e in holes))
        self.assertEqual(len({e.x for e in holes}),6)

    def test_pairs_are_distinct_reflections_and_fit_canvas(self):
        surface=GenusSurface(type_ii=(BoundaryPair('left'),BoundaryPair('right'),BoundaryPair('top')))
        d=layout(surface,Style())
        holes=d.ellipses
        self.assertEqual(len(holes),6)
        for e in holes:
            self.assertIn((e.x,-e.y),[(f.x,f.y) for f in holes])
            self.assertLess(abs(e.y)+e.ry,d.height/2)
            self.assertLess(abs(e.x)+e.rx,d.width/2)

    def test_silhouette_and_handle_reflection(self):
        d=layout(GenusSurface(type_i=(TypeIBoundary(2),),type_ii=(BoundaryPair('top'),)),Style())
        paths=[p for p in d.paths if p.role in ('handle','surface-outline')]
        for p in paths:
            reflected=tuple((op,*(v if i%2==0 else -v for i,v in enumerate(vals))) for op,*vals in p.commands)
            self.assertIn(reflected,[q.commands for q in paths])

    def test_boundary_necks_join_rims(self):
        d=layout(GenusSurface(type_ii=(BoundaryPair('top'),)),Style())
        ends=[]
        for p in d.paths:
            if p.role=='surface-outline':
                ends.extend((p.commands[0][1:],p.commands[-1][-2:]))
        for e in d.ellipses:
            self.assertTrue(any(abs(x-(e.x-e.rx))<1e-8 and abs(y-e.y)<1e-8 for x,y in ends))
            self.assertTrue(any(abs(x-(e.x+e.rx))<1e-8 and abs(y-e.y)<1e-8 for x,y in ends))

    def test_invalid_boundary_geometry(self):
        with self.assertRaises(ValueError): GenusSurface(0)
        with self.assertRaises(ValueError): GenusSurface(type_i=(TypeIBoundary(7),))
        with self.assertRaises(ValueError): GenusSurface(type_i=(TypeIBoundary(1),TypeIBoundary(1)))
        with self.assertRaises(ValueError): BoundaryPair('inside')
        with self.assertRaises(ValueError):
            render_svg(GenusSurface(type_ii=(BoundaryPair('top'),BoundaryPair('top'))))
        with self.assertRaises(ValueError):
            render_svg(GenusSurface(type_i=(TypeIBoundary(2,99),)))

    def test_balloon_and_axis_options(self):
        d=layout(GenusSurface(3,handle_style='balloon',show_axis=True),Style())
        self.assertEqual(sum(p.role=='handle-back' for p in d.paths),3)
        self.assertEqual(sum(p.role=='involution-axis' for p in d.paths),1)


if __name__ == '__main__': unittest.main()
