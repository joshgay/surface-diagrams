import unittest
from surface_diagrams import GenusSurface, PlanarSurface, Style, MarkedArc, render_svg
from surface_diagrams.genus_diagrams import NamedCut
from surface_diagrams.genus_geometry import presentation
from surface_diagrams.genus_mesh import genus_binding
from surface_diagrams.layout import layout
from surface_diagrams.mesh_atlas import cubic_point, _near
from surface_diagrams.disk_routes import ItineraryError


class ReferenceAppearanceTests(unittest.TestCase):
    def test_default_is_above_and_planar_reference_follows_every_interval(self):
        self.assertEqual(GenusSurface().view_vertical,'above')
        surface=PlanarSurface.row('BPPB',spacing=65,height=180,margin=65)
        diagram=surface.with_cut_system()
        self.assertEqual([(c.curve.start,c.curve.end) for c in diagram.curves],
                         [(0,1),(1,2),(2,3),(3,4),(4,5)])
        paths=layout(diagram,Style(boundary_shape='circle')).paths
        self.assertEqual(len(paths),5)
        self.assertTrue(all([c[0] for c in p.commands]==['M','L'] for p in paths))
        self.assertTrue(all(c[2]==0 for p in paths for c in p.commands))
        self.assertEqual(len({p.stroke for p in paths}),5)
        self.assertFalse(PlanarSurface.row('').with_cut_system().curves)

    def test_tight_even_cuts_and_opposite_visibility_in_both_views(self):
        for view,sign in (('above',1),('below',-1)):
            surface=GenusSurface(2,view_vertical=view)
            for number in (1,2,3,4,5):
                paths=[p for p in layout(surface.with_curves(NamedCut(number)),Style()).paths if p.role=='named-cut']
                self.assertEqual({p.dashed for p in paths},{False,True})
                for p in paths:
                    mean_y=sum(c[-1] for c in p.commands)/len(p.commands)
                    self.assertEqual(p.dashed, mean_y*sign>0 if number%2 else mean_y*sign<0)
            curves=[p for p in layout(surface.with_curves(NamedCut(2)),Style()).paths if p.role=='named-cut']
            points=[c[1:] for p in curves for c in p.commands]
            hole= presentation(surface).handles[:2]
            hole_points=[]
            for c in hole:
                controls=(c[0][1:],c[1][1:3],c[1][3:5],c[1][5:7])
                hole_points.extend(cubic_point(controls,i/100) for i in range(101))
            self.assertLess(max(x for x,y in points)-max(x for x,y in hole_points),surface.handle_spacing*.05)
            self.assertLess(max(y for x,y in points)-max(y for x,y in hole_points),surface.handle_spacing*.08)

    def test_straight_marked_arc_uses_actual_endpoints_and_rejects_obstacles(self):
        surface=GenusSurface(2,marks=('P','Q'))
        drawing=layout(surface.with_curves(MarkedArc('P','Q')),Style())
        path=next(p for p in drawing.paths if p.role=='surface-route')
        self.assertEqual([c[0] for c in path.commands],['M','L'])
        marks=[(m.x,m.y) for m in drawing.ellipses if m.role=='marked-point']
        self.assertTrue(_near(path.commands[0][1:],marks[0]))
        self.assertTrue(_near(path.commands[-1][1:],marks[1]))
        with self.assertRaises(ValueError):
            render_svg(surface.with_curves(MarkedArc('P','missing')))
        with self.assertRaises(ItineraryError):
            render_svg(surface.with_curves(MarkedArc('P','Q'),MarkedArc('Q','P')))
        three=GenusSurface(2,marks=('P','Q','R'))
        with self.assertRaises(ItineraryError):
            render_svg(three.with_curves(MarkedArc('P','R')))
        self.assertIn('surface-route',render_svg(three.with_curves(MarkedArc('P','Q'),MarkedArc('Q','R'))))


if __name__=='__main__': unittest.main()
