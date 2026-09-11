"""Coordinate semantics and independent geometric checks for emitted routes."""
import math
import random
import unittest
from xml.etree import ElementTree as ET

from surface_diagrams import Arc, Loop, PlanarSurface, MarkedPoint, Style, RoutingError, render_svg
from surface_diagrams.curves import route, _axis_distance, _conflict


class CurvesTest(unittest.TestCase):
    def setUp(self):
        self.surface = PlanarSurface.row("PPPPPP", spacing=55, height=210, margin=60)
        self.style = Style()

    def test_minimality_and_integer_validation(self):
        bad = [lambda: Arc(1,3,(0,)), lambda: Arc(1,3,(3,)),
               lambda: Arc(1,5,(3,3)), lambda: Arc(1,1), lambda: Arc(True,3),
               lambda: Arc(1,4,(2.0,)), lambda: Loop((0,2,4)),
               lambda: Loop((0,3,2,0)), lambda: Loop(())]
        for make in bad:
            with self.assertRaises(ValueError): make()

    def test_visit_itinerary_and_alternating_sides_preserved(self):
        arc = Arc(2,3,(4,2,4,2,4),False)
        pieces = route(self.surface.with_curves(arc), self.style)
        xs = sorted(p.x for p in self.surface.objects)
        bounds = [-self.surface.width/2] + xs + [self.surface.width/2]
        self.assertEqual(pieces[0].start, xs[1])
        self.assertEqual(pieces[-1].end, xs[2])
        self.assertEqual([p.up for p in pieces], [False,True,False,True,False,True])
        for i, cut in enumerate(arc.cuts):
            self.assertLess(bounds[cut], pieces[i].end)
            self.assertLess(pieces[i].end, bounds[cut+1])
            self.assertEqual(pieces[i].end, pieces[i+1].start)
        # Distinct visits retain one position across both half-planes.
        self.assertEqual(len({pieces[i].end for i in (0,2,4)}), 3)

    def test_outer_boundary_endpoints(self):
        parts = route(self.surface.with_curves(Arc(0,7)), self.style)
        self.assertEqual(parts[0].start, -self.surface.width/2)
        self.assertEqual(parts[-1].end, self.surface.width/2)

    def test_default_consecutive_arcs_are_straight_in_both_directions(self):
        for start, end in ((2,3), (3,2), (0,1), (1,0), (6,7), (7,6)):
            with self.subTest(start=start, end=end):
                surface = self.surface.with_curves(Arc(start,end))
                piece, = route(surface,self.style)
                self.assertTrue(piece.straight)
                self.assertEqual(piece.point(.5), ((piece.start+piece.end)/2,0))
                self.assertEqual(_axis_distance(piece,(piece.start+piece.end)/2),0)
                svg = ET.fromstring(render_svg(surface))
                path = svg.find("{http://www.w3.org/2000/svg}path")
                self.assertIn("L",path.attrib["d"])
                self.assertNotIn("A",path.attrib["d"])

    def test_direction_overrides_and_legacy_calls_are_curved(self):
        for start,end in ((2,3),(3,2),(0,1),(6,7)):
            for direction,up in (("up",True),("down",False)):
                modern, = route(self.surface.with_curves(Arc(start,end,direction=direction)),self.style)
                legacy, = route(self.surface.with_curves(Arc(start,end,(),up)),self.style)
                self.assertEqual(modern,legacy)
                self.assertFalse(modern.straight)
                self.assertEqual(modern.up,up)
                self.assertGreater(modern.point(.5)[1]*(1 if up else -1),0)

    def test_nonconsecutive_and_outer_to_outer_defaults_remain_up(self):
        for surface,arc in ((self.surface,Arc(1,4)), (self.surface,Arc(0,7)),
                            (PlanarSurface(),Arc(0,1))):
            p, = route(surface.with_curves(arc),self.style)
            self.assertIs(p.up,True)
        self.assertEqual(Arc(1,2).direction,"default")

    def test_default_never_removes_cut_visits(self):
        for start,end,cuts in ((2,3,(4,)), (0,4,(2,))):
            default = route(self.surface.with_curves(Arc(start,end,cuts)),self.style)
            up = route(self.surface.with_curves(Arc(start,end,cuts,direction="up")),self.style)
            down = route(self.surface.with_curves(Arc(start,end,cuts,direction="down")),self.style)
            self.assertEqual(default,up)
            self.assertEqual(len(default),len(cuts)+1)
            self.assertTrue(all(not p.straight for p in default))
            self.assertEqual([not p.up for p in up],[p.up for p in down])

    def test_straight_arcs_cannot_overlap_or_meet_cut_crossings(self):
        for curves in ((Arc(2,3),Arc(3,2)), (Arc(2,3),Loop((2,5)))):
            with self.assertRaises(RoutingError):
                render_svg(self.surface.with_curves(*curves))
        # Shared object endpoints and an enclosing curved arc are permitted.
        render_svg(self.surface.with_curves(Arc(1,2),Arc(2,3),Arc(1,3)))
        render_svg(self.surface.with_curves(Arc(2,3),Arc(2,3,direction="up")))
        for a,b,expected in (((0,4,None),(2,6,True),True),
                             ((0,4,None),(4,6,True),False),
                             ((0,4,None),(-1,5,False),False),
                             ((0,4,None),(2,6,None),True)):
            self.assertEqual(_conflict(a,b),expected)
            self.assertEqual(_conflict(b,a),expected)

    def test_outer_straight_arc_rejects_intervening_dots(self):
        for start,end in ((0,3),(3,0),(4,7),(7,4)):
            with self.assertRaisesRegex(RoutingError,"straight arc meets"):
                render_svg(self.surface.with_curves(Arc(start,end)))
            for direction in ("up","down"):
                render_svg(self.surface.with_curves(Arc(start,end,direction=direction)))

    def test_invalid_direction_is_rejected(self):
        for kwargs in ({"direction":"sideways"}, {"direction":None}, {"start_up":1},
                       {"direction":"up","start_up":True}):
            with self.assertRaises(ValueError):
                Arc(1,2,**kwargs)
        with self.assertRaises(ValueError):
            Loop((0,2),start_up=None)

    def test_loop_closure_and_svg(self):
        surface = self.surface.with_curves(Loop((0,6,5,1)))
        pieces = route(surface,self.style)
        self.assertEqual(pieces[-1].end,pieces[0].start)
        root = ET.fromstring(render_svg(surface))
        path = root.find("{http://www.w3.org/2000/svg}path")
        self.assertTrue(path.attrib['d'].rstrip().endswith('Z'))
        self.assertEqual(path.attrib['class'],'closed-curve')

    def test_reflection_and_reverse(self):
        cuts=(4,2,4,2,4)
        a=route(self.surface.with_curves(Arc(2,3,cuts,False)),self.style)
        b=route(self.surface.with_curves(Arc(2,3,cuts,True)),self.style)
        self.assertEqual([(p.start,p.end) for p in a],[(p.start,p.end) for p in b])
        self.assertEqual([not p.up for p in a],[p.up for p in b])
        # Reversal must also remain representable, though slot positions can differ.
        route(self.surface.with_curves(Arc(3,2,tuple(reversed(cuts)),False)),self.style)

    def test_impossible_routes_and_search_budget_never_simplify(self):
        with self.assertRaises(RoutingError):
            render_svg(self.surface.with_curves(Arc(1,4),Arc(2,5)))
        with self.assertRaises(RoutingError):
            route(self.surface.with_curves(Arc(2,3,(4,2,4),False)),self.style,max_states=0)
        with self.assertRaises(RoutingError):
            render_svg(PlanarSurface([MarkedPoint(-10,2),MarkedPoint(10)]).with_curves(Arc(1,2)))
        with self.assertRaises(ValueError):
            render_svg(self.surface.with_curves(Arc(1,8)))
        with self.assertRaises(ValueError):
            render_svg(self.surface.with_curves(Loop((0,9))))

    def test_nested_and_disjoint_curves(self):
        render_svg(self.surface.with_curves(Loop((0,6)),Loop((1,5)),Arc(3,4)))
        render_svg(self.surface.with_curves(Arc(1,2),Arc(3,4),Arc(5,6)))

    def test_marker_collision_rejected(self):
        with self.assertRaises(RoutingError):
            render_svg(PlanarSurface.row('PPP',height=20).with_curves(Arc(1,3)))

    def test_analytic_dot_distance_matches_dense_sample(self):
        parts=route(self.surface.with_curves(Arc(1,6)),self.style)
        p=parts[0]
        for x in (-200,-100,0,50,160):
            sampled=min(math.hypot(px-x,py) for px,py in (p.point(i/2000) for i in range(2001)))
            self.assertAlmostEqual(_axis_distance(p,x),sampled,delta=.01)

    def test_seeded_itineraries_have_no_proper_geometric_crossings(self):
        rng=random.Random(49)
        accepted=0
        for _ in range(250):
            try:
                c=Arc(*rng.sample(range(1,7),2),tuple(rng.randrange(7) for _ in range(rng.randrange(5))))
                pieces=route(self.surface.with_curves(c),self.style,max_states=500)
            except ValueError: continue
            accepted+=1
            segments=[]
            for p in pieces:
                samples=[p.point(i/24) for i in range(25)]
                segments.extend(zip(samples,samples[1:]))
                for x,y in samples:
                    self.assertLessEqual((x/(self.surface.width/2))**2+(y/(self.surface.height/2))**2,1+1e-10)
            def cross(a,b,c):
                return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
            for i,(a,b) in enumerate(segments):
                for c,d in segments[i+2:]:
                    self.assertFalse(cross(a,b,c)*cross(a,b,d)<-1e-9 and cross(c,d,a)*cross(c,d,b)<-1e-9)
        self.assertGreater(accepted,25)


if __name__ == '__main__': unittest.main()
