from dataclasses import replace
import unittest
from xml.etree import ElementTree as ET

from surface_diagrams import render_svg, render_tikz
from surface_diagrams.cut_systems import Cellulation, Face, SidePair, BoundarySide, SurfaceSpec
from surface_diagrams.standard_cuts import CutSystem, chain_system
from surface_diagrams.disk_routes import (BoundaryPoint, MarkPoint, Crossing, DiskRoute,
                                         CutAtlas, ItineraryError, cut_along_route)


def annulus():
    return CutSystem(Cellulation((Face('F', ('a', 'B1', '-a', 'B0')),),
                     (SidePair('a', 'a', '-a'),),
                     (BoundarySide('B1', 'inner'), BoundarySide('B0', 'outer')), cuts=('a',)),
                     SurfaceSpec('annulus', 0, ('inner', 'outer')))


class DiskRouteTests(unittest.TestCase):
    def setUp(self):
        self.system = chain_system(1)
        self.atlas = CutAtlas.build(self.system)

    def test_one_crossing_closed_curve_and_nonseparation(self):
        route = DiskRoute((Crossing('c2.e1+', .4),))
        result = self.atlas.route(route)
        self.assertEqual(len(result.pieces), 1)
        self.assertEqual(result.pieces[0].start_locator, Crossing('c2.e1-', .6))
        topology = cut_along_route(self.atlas, route)
        self.assertFalse(topology.separating)
        self.assertEqual((topology.components[0].genus, len(topology.components[0].boundary_cycles)), (0, 2))

    def test_repeated_crossings_are_preserved_and_embedded(self):
        route = DiskRoute((Crossing('c1.e1+', .25), Crossing('c2.e1+', .25),
                           Crossing('c2.e1+', .75), Crossing('c3.e1-', .75)))
        result = self.atlas.route(route)
        self.assertEqual(len(result.pieces), 4)
        self.assertEqual([p.end_locator for p in result.pieces], list(route.crossings[1:]+route.crossings[:1]))
        self.assertFalse(cut_along_route(self.atlas, route).separating)

    def test_reversal_preserves_unoriented_disk_geometry(self):
        route = DiskRoute((Crossing('c1.e1+', .2), Crossing('c3.e1-', .7)))
        def geometry(result):
            return { (p.chart, tuple(sorted((tuple(round(x, 10) for x in p.start),
                                             tuple(round(x, 10) for x in p.end))))) for p in result.pieces }
        self.assertEqual(geometry(self.atlas.route(route)), geometry(self.atlas.route(self.atlas.reversed(route))))

    def test_boundary_arc_and_return_arc_on_annulus(self):
        atlas = CutAtlas.build(annulus())
        route = DiskRoute((), BoundaryPoint('B0', .5), BoundaryPoint('B1', .5))
        result = atlas.route(route)
        self.assertEqual(len(result.pieces), 1)
        topology = cut_along_route(atlas, route)
        self.assertFalse(topology.separating)
        self.assertEqual(len(topology.components[0].boundary_cycles), 1)
        route = DiskRoute((Crossing('a', .5),), BoundaryPoint('B0', .8), BoundaryPoint('B0', .2))
        result = atlas.route(route)
        self.assertEqual(len(result.pieces), 2)
        self.assertTrue(cut_along_route(atlas, route).separating)

    def test_mark_endpoint_uses_its_actual_cut_corner(self):
        atlas = CutAtlas.build(chain_system(1, marks=('M',)))
        chart, point, endpoint = atlas.endpoint(MarkPoint('M'))
        self.assertEqual(endpoint.corner, 's4-')
        self.assertEqual(point, chart.point('s4-', 0))
        with self.assertRaises(ItineraryError):
            atlas.endpoint(MarkPoint('M', 'c1.e1+'))

    def test_ambiguous_numbers_require_explicit_side(self):
        with self.assertRaisesRegex(ItineraryError, 'ambiguous'):
            self.atlas.resolve_number(2)
        self.assertEqual(self.atlas.resolve_number(1, source_chart='chain-disk-1'), 'c1.e1+')

    def test_invalid_itineraries_and_repeated_position(self):
        for route in (DiskRoute(()), DiskRoute((Crossing('missing'),)),
                      DiskRoute((Crossing('c1.e1+'),)),
                      DiskRoute((Crossing('c2.e1+', .5), Crossing('c2.e1+', .5))),
                      DiskRoute((Crossing('c2.e1+', 0),)),
                      DiskRoute((Crossing('c2.e1+', float('nan')),))):
            with self.subTest(route=route), self.assertRaises(ItineraryError):
                self.atlas.route(route)

    def test_self_intersecting_chords_are_rejected(self):
        with self.assertRaisesRegex(ItineraryError, 'intersects itself'):
            self.atlas.route(DiskRoute((Crossing('c2.e1+', .2), Crossing('c2.e1+', .8))))

    def test_overlay_requires_exact_actual_intersection_records(self):
        a = DiskRoute((Crossing('c2.e1+', .25),), id='A')
        b = DiskRoute((Crossing('c1.e1+', .5), Crossing('c3.e1-', .5)), id='B')
        with self.assertRaises(ItineraryError):
            self.atlas.family((a,b))
        result = self.atlas.family((a,b), intersections=((('A',0),('B',0)),))
        self.assertEqual(len(result), 2)
        with self.assertRaises(ItineraryError):
            self.atlas.family((a,replace(a,id='B')), intersections=((('A',0),('B',0)),))

    def test_numbered_diagnostics_are_valid_svg_and_shared_tikz_geometry(self):
        diagram = chain_system(2, boundaries=('B1',), marks=('M',)).diagram()
        root = ET.fromstring(render_svg(diagram))
        self.assertIn('M', [e.text for e in root.iter()])
        self.assertIn('cut-side', [e.attrib.get('class') for e in root.iter()])
        self.assertIn('tikzpicture', render_tikz(diagram))
        self.assertEqual(render_svg(diagram), render_svg(diagram))


if __name__ == '__main__':
    unittest.main()
