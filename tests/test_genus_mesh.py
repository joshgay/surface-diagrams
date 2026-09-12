from dataclasses import replace
import unittest

from surface_diagrams import GenusSurface, render_svg, render_tikz
from surface_diagrams.genus_mesh import genus_binding
from surface_diagrams.genus_diagrams import NamedCut, _append_paths
from surface_diagrams.mesh_atlas import MeshBinding, MeshTriangle, flatten_segment, _near, _star_positive, _segment_distance
from surface_diagrams.disk_routes import Crossing, DiskRoute, ItineraryError


class GenusMeshTests(unittest.TestCase):
    def test_genus_and_views_have_two_certified_embedded_disks(self):
        for genus in (1, 2, 3, 5):
            ids = None
            for vertical in ('above', 'below'):
                for horizontal in ('left', 'right'):
                    with self.subTest(genus=genus, vertical=vertical, horizontal=horizontal):
                        binding = genus_binding(GenusSurface(genus, view_vertical=vertical, view_horizontal=horizontal))
                        report = binding.system.validate()
                        self.assertTrue(report.certified, report.diagnostics)
                        self.assertEqual(len(report.complement), 2)
                        atlas, triangles = binding.charts()
                        self.assertEqual(len(triangles), len(binding.triangles))
                        current = tuple((p.number, p.walk) for p in binding.system.cellulation.parents)
                        if ids is not None:
                            self.assertEqual(ids, current)
                        ids = current
                        self.assertEqual(len(current), 2*genus+1)

    def test_route_projection_closes_across_front_and_back(self):
        binding = genus_binding(GenusSurface(1))
        atlas, _ = binding.charts()
        side = next(s for s in atlas.pairs if atlas.sides[s].id == atlas.sides[atlas.cross(Crossing(s)).side].id)
        route = DiskRoute((Crossing(side, .37),))
        pieces = binding.project(route)
        self.assertEqual({p.sheet for p in pieces}, {'front', 'back'})
        for a,b in zip(pieces, pieces[1:]+pieces[:1]):
            self.assertTrue(_near(a.points[-1], b.points[0]))
        reverse = binding.project(atlas.reversed(route))
        self.assertTrue(_near(pieces[0].points[0], reverse[0].points[0]))
        svg = render_svg(GenusSurface(1).with_curves(route))
        self.assertIn('stroke-dasharray', svg)
        for error in (0, -1, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                binding.project(route, error=error)

    def test_all_named_members_render_and_invalid_numbers_fail(self):
        surface = GenusSurface(2)
        for number in range(1, 6):
            diagram = surface.with_curves(NamedCut(number))
            self.assertIn('<svg', render_svg(diagram))
            self.assertIn('draw', render_tikz(diagram))
        with self.assertRaises(ValueError):
            render_svg(surface.with_curves(NamedCut(6)))
        self.assertIn('>5</text>', render_svg(surface.with_cut_system()))

    def test_mutated_binding_rejects_missing_faces_and_folds(self):
        binding = genus_binding(GenusSurface(1))
        with self.assertRaises(ItineraryError):
            MeshBinding(binding.system, binding.triangles[1:])
        t = binding.triangles[0]
        changed = replace(t, points=(t.points[1], t.points[0], t.points[2]))
        with self.assertRaises(ItineraryError):
            MeshBinding(binding.system, (changed,)+binding.triangles[1:])
        changed = replace(t, points=tuple((x+.1,y) for x,y in t.points), curved=tuple((x+.1,y) for x,y in t.curved))
        with self.assertRaisesRegex(ItineraryError, 'do not match'):
            MeshBinding(binding.system, (changed,)+binding.triangles[1:])

    def test_curved_certificate_checks_interior_not_only_endpoints(self):
        curve = ((0.,0.),(0.,4.),(1.,4.),(1.,0.))
        self.assertFalse(_star_positive(curve, (.5,1.), 1))
        self.assertTrue(_star_positive(tuple(reversed(curve)), (.5,-1.), 1))

    def test_disconnected_projected_pieces_are_not_bridged(self):
        for sheet in ('front','back'):
            with self.assertRaises(ItineraryError):
                _append_paths([], [('front', ((0,0),(1,0))), (sheet, ((2,0),(3,0)))], 'black', 1, 'route')


class ProjectionBoundTests(unittest.TestCase):
    def test_s_bend_is_not_lost_at_its_zero_deviation_midpoint(self):
        curve=((0.,0.),(1/3,1.),(2/3,-1.),(1.,0.))
        triangle=MeshTriangle('T','front',(curve[0],curve[-1],(.5,5.)),curve)
        self.assertTrue(_star_positive(curve,triangle.points[2],1))
        self.assertEqual(triangle.project((.5,.5,0.)),(.5,0.))
        error=.002
        points=flatten_segment(triangle,(1.,0.,0.),(0.,1.,0.),error)
        self.assertGreater(len(points),2)
        for i in range(401):
            t=i/400
            point=triangle.project((1-t,t,0.))
            self.assertLessEqual(min(_segment_distance(point,a,b) for a,b in zip(points,points[1:])),error)

    def test_radial_segment_to_apex_is_exactly_straight(self):
        curve=((0.,0.),(.3,-.3),(.7,-.3),(1.,0.))
        triangle=MeshTriangle('T','front',(curve[0],curve[-1],(.5,1.)),curve)
        points=flatten_segment(triangle,(.7,.3,0.),(0.,0.,1.),1e-8)
        self.assertEqual(len(points),2)
        self.assertEqual(points[-1],triangle.points[2])
