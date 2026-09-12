import unittest
from surface_diagrams import GenusSurface, render_svg
from surface_diagrams.genus_mesh import genus_binding
from surface_diagrams.disk_routes import Crossing, DiskRoute, ItineraryError, cut_along_route
from surface_diagrams.mesh_atlas import _near


def long_route():
    return DiskRoute((Crossing('front.3.0.0.s0',.23),Crossing('front.126.2.1.s0',.63)),id='long')


def handle_route(atlas, number, name):
    parent=next(p for p in atlas.system.cellulation.parents if p.number==number)
    side=next(s for s in parent.walk if atlas.sides[s].id==atlas.sides[atlas.cross(Crossing(s)).side].id)
    return DiskRoute((Crossing(side,.37),),id=name)


class GenusRouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.surface=GenusSurface(2)
        cls.binding=genus_binding(cls.surface)
        cls.atlas=cls.binding.charts()[0]

    def test_multiple_handles_and_reconstructed_nonseparation(self):
        route=long_route()
        topology=cut_along_route(self.atlas,route)
        self.assertFalse(topology.separating)
        self.assertEqual([(c.genus,len(c.boundary_cycles)) for c in topology.components],[(1,2)])
        projected=self.binding.project(route)
        for a,b in zip(projected,projected[1:]+projected[:1]):
            self.assertTrue(_near(a.points[-1],b.points[0]))
        self.assertEqual({p.sheet for p in projected},{'front','back'})

    def test_essential_separating_curve_gives_two_once_bordered_tori(self):
        route=DiskRoute((Crossing('front.71.0.0.s0',.23),Crossing('front.76.2.1.s0',.63)),id='separating')
        topology=cut_along_route(self.atlas,route)
        self.assertTrue(topology.separating)
        self.assertEqual([(c.genus,len(c.boundary_cycles)) for c in topology.components],[(1,1),(1,1)])
        self.assertTrue(self.binding.project(route))

    def test_repeated_edge_visits_survive_projection(self):
        route=DiskRoute((Crossing('front.3.0.0.s0',.25),Crossing('front.31.0.0.s0',.25),
                         Crossing('front.31.0.0.s0',.75),Crossing('front.70.2.1.s0',.75)),id='repeat')
        routed=self.atlas.route(route)
        self.assertEqual(len(routed.pieces),4)
        projected=self.binding.project(route)
        self.assertEqual({p.index for p in projected},set(range(4)))
        for a,b in zip(projected,projected[1:]+projected[:1]):
            self.assertTrue(_near(a.points[-1],b.points[0]))

    def test_overlay_requires_its_exact_genuine_intersection(self):
        long=long_route()
        short=handle_route(self.atlas,2,'short')
        with self.assertRaises(ItineraryError):
            render_svg(self.surface.with_curves(long,short))
        declared=((('long',0),('short',0)),)
        self.assertIn('<svg',render_svg(self.surface.with_curves(long,short,intersections=declared)))
        self.assertIn('<svg',render_svg(self.surface.with_curves(long).with_curves(short,intersections=declared)))
        with self.assertRaises(ItineraryError):
            render_svg(self.surface.with_curves(long,short,intersections=((('long',1),('short',0)),)))

    def test_disjoint_handle_family_needs_no_intersection_override(self):
        left=handle_route(self.atlas,2,'left')
        right=handle_route(self.atlas,4,'right')
        self.atlas.family((left,right))
        self.assertIn('<svg',render_svg(self.surface.with_curves(left,right)))

    def test_uniform_scaling_preserves_the_mesh_route_locators(self):
        expected=tuple(p.walk for p in self.binding.system.cellulation.parents)
        for spacing,height in ((55,50),(220,200),(113.7,100)):
            binding=genus_binding(GenusSurface(2,handle_spacing=spacing,height=height))
            self.assertEqual(tuple(p.walk for p in binding.system.cellulation.parents),expected)
            self.assertTrue(binding.project(long_route()))
