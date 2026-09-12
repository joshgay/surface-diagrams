from dataclasses import replace
from pathlib import Path
from itertools import combinations
import importlib.util
import unittest

from surface_diagrams.cut_systems import (
    BoundarySide, Cellulation, Face, Intersection, Mark, ParentCut,
    SidePair, SurfaceSpec, VertexIncidence, validate_cut_system,
)

# The examples are the actual documented fixtures, not duplicated test models.
_loader = importlib.util.spec_from_file_location(
    'cut_system_examples', Path(__file__).resolve().parents[1]/'examples'/'cut_system_examples.py')
_examples = importlib.util.module_from_spec(_loader)
_loader.loader.exec_module(_examples)


class CutSystemTests(unittest.TestCase):
    def setUp(self):
        self.cases = _examples.examples()

    def report(self, name, **changes):
        cell, spec = self.cases[name]
        return validate_cut_system(replace(cell, **changes), spec)

    def assertFailure(self, report, code):
        self.assertFalse(report.certified)
        self.assertIn(code, [d.code for d in report.diagnostics], report)

    def test_six_worked_surfaces_and_two_disk_complement(self):
        expected = {'disk': (3, 3, 1, 0, 1), 'annulus': (2, 3, 0, 0, 2),
                    'marked-disk': (2, 2, 1, 0, 1), 'torus': (1, 2, 0, 1, 0),
                    'genus-two': (1, 4, -2, 2, 0), 'pair-of-pants': (4, 6, -1, 0, 3),
                    'split-disk': (4, 5, 1, 0, 1)}
        for name, (v, e, chi, g, b) in expected.items():
            with self.subTest(name=name):
                report = self.report(name)
                self.assertTrue(report.certified, report.diagnostics)
                full, = report.full
                self.assertEqual((full.vertices, full.edges, full.euler, full.genus,
                                  len(full.boundary_cycles)), (v, e, chi, g, b))
                self.assertEqual(len(report.complement), 2 if name == 'split-disk' else 1)
                self.assertTrue(all(c.genus == 0 and len(c.boundary_cycles) == 1
                                    and c.euler == 1 for c in report.complement))
                self.assertEqual(report.scope, 'abstract_cellulation')

    def test_incomplete_annulus_and_missing_pants_connection(self):
        for name, cuts in (('annulus', ()), ('pair-of-pants', ('a',))):
            with self.subTest(name=name):
                report = self.report(name, cuts=cuts)
                self.assertFailure(report, 'residual_topology')
                self.assertEqual(report.complement[0].genus, 0)
                self.assertEqual(len(report.complement[0].boundary_cycles), 2)
                self.assertIn(name, report.diagnostics[0].ids)

    def test_uncut_handle_and_single_torus_cut(self):
        for cuts, genus, boundaries in (((), 1, 0), (('a',), 0, 2)):
            report = self.report('torus', cuts=cuts)
            self.assertFailure(report, 'residual_topology')
            self.assertEqual((report.complement[0].genus, len(report.complement[0].boundary_cycles)),
                             (genus, boundaries))

    def test_marked_slit_tip_is_interior_until_cut(self):
        report = self.report('marked-disk')
        self.assertEqual(report.full[0].interior_marks, ('M',))
        self.assertEqual(report.complement[0].boundary_marks, ('M',))
        report = self.report('marked-disk', cuts=())
        self.assertFailure(report, 'interior_marks')
        self.assertEqual(report.complement[0].genus, 0)
        self.assertEqual(report.diagnostics[0].ids, ('M',))

    def test_all_copies_of_marked_vertex_are_carried_across_cutting(self):
        cell, spec = self.cases['split-disk']
        cell = replace(cell, marks=(Mark('M', corner='a'),))
        report = validate_cut_system(cell, replace(spec, marks=('M',)))
        self.assertTrue(report.certified, report.diagnostics)
        self.assertEqual([c.boundary_marks for c in report.complement], [('M',), ('M',)])

    def test_face_interior_mark_cannot_be_discarded(self):
        cell, spec = self.cases['disk']
        report = validate_cut_system(replace(cell, marks=(Mark('M', face='disk'),)),
                                     replace(spec, marks=('M',)))
        self.assertFailure(report, 'interior_marks')

    def test_corner_mark_locator_is_invariant_under_glued_representative(self):
        cell, spec = self.cases['torus']
        reports = [validate_cut_system(replace(cell, marks=(Mark('M', corner=s),)),
                                       replace(spec, marks=('M',))) for s in cell.faces[0].sides]
        self.assertTrue(all(r.certified for r in reports))
        self.assertTrue(all(r == reports[0] for r in reports))

    def test_wrong_requested_surface_and_disconnected_surface(self):
        cell, spec = self.cases['torus']
        self.assertFailure(validate_cut_system(cell, replace(spec, genus=0)), 'surface_genus')
        cell, spec = self.cases['split-disk']
        cell = replace(cell, pairs=(), cuts=(), boundaries=cell.boundaries +
                       (BoundarySide('a', 'L'), BoundarySide('-a', 'R')))
        self.assertFailure(validate_cut_system(cell, spec), 'surface_components')

    def test_side_gluing_must_be_complete_unique_and_reversed(self):
        cell, spec = self.cases['torus']
        for pairs, code in ((cell.pairs[:1], 'unclassified_side'),
                            (cell.pairs + (SidePair('c', 'a', '-b'),), 'duplicate_pairing'),
                            ((replace(cell.pairs[0], reversed=False), cell.pairs[1]), 'orientation'),
                            ((SidePair('a', 'a', 'a'), cell.pairs[1]), 'duplicate_pairing'),
                            ((SidePair('a', 'a', 'missing'), cell.pairs[1]), 'unknown_side')):
            with self.subTest(code=code):
                self.assertFailure(validate_cut_system(replace(cell, pairs=pairs), spec), code)

    def test_boundary_ids_follow_cycles_not_labels_alone(self):
        cell, spec = self.cases['annulus']
        bad = replace(cell, boundaries=tuple(BoundarySide(b.side, 'B0') for b in cell.boundaries))
        self.assertFailure(validate_cut_system(bad, replace(spec, boundaries=('B0',))), 'boundary_identity')
        cell, spec = self.cases['disk']
        bad = replace(cell, boundaries=(BoundarySide('B0a', 'other'),)+cell.boundaries[1:])
        self.assertFailure(validate_cut_system(bad, spec), 'boundary_identity')

    def test_boundary_declared_twice_or_on_paired_side(self):
        cell, spec = self.cases['annulus']
        for extra in (cell.boundaries[0], BoundarySide('a', 'B0')):
            self.assertFailure(validate_cut_system(replace(cell, boundaries=cell.boundaries+(extra,)), spec),
                               'duplicate_boundary')

    def test_mark_inventory_locations_and_coincident_marks(self):
        cell, spec = self.cases['torus']
        self.assertFailure(validate_cut_system(replace(cell, marks=(Mark('M', corner='a'),)), spec), 'mark_inventory')
        for mark in (Mark('M'), Mark('M', corner='a', face='torus'), Mark('M', corner='missing')):
            self.assertFailure(validate_cut_system(replace(cell, marks=(mark,)), replace(spec, marks=('M',))), 'mark_locator')
        bad = replace(cell, marks=(Mark('M', corner='a'), Mark('N', corner='b')))
        self.assertFailure(validate_cut_system(bad, replace(spec, marks=('M', 'N'))), 'duplicate_mark_location')

    def test_vertex_links_and_oriented_rotation_are_computed(self):
        report = self.report('torus')
        vertex, = report.vertices
        self.assertFalse(vertex.boundary)
        self.assertEqual(set(vertex.corners), {'a', 'b', '-a', '-b'})
        expected = vertex.ends
        for i in range(len(expected)):
            self.assertTrue(self.report('torus', incidences=(VertexIncidence('b', expected[i:]+expected[:i]),)).certified)
        self.assertFailure(self.report('torus', incidences=(VertexIncidence('a', tuple(reversed(expected))),)), 'vertex_rotation')
        self.assertFailure(self.report('torus', incidences=(VertexIncidence('a',
                           (('a', 'start'), ('a', 'end'), ('b', 'start'), ('b', 'end'))),)), 'vertex_rotation')

    def test_boundary_links_are_intervals_with_ordered_ends(self):
        report = self.report('annulus')
        self.assertTrue(all(v.boundary and len(v.ends) == 3 for v in report.vertices))
        vertex = report.vertices[0]
        self.assertTrue(self.report('annulus', incidences=(VertexIncidence(vertex.id, vertex.ends),)).certified)
        self.assertFailure(self.report('annulus', incidences=(VertexIncidence(vertex.id, vertex.ends[1:]+vertex.ends[:1]),)),
                           'vertex_rotation')

    def test_two_transverse_torus_parents_need_genuine_incidence(self):
        parents = (ParentCut('A', 1, 'closed', ('a',)), ParentCut('B', 2, 'closed', ('b',)))
        crossing = Intersection('a', ('A', 'B'))
        report = self.report('torus', parents=parents, intersections=(crossing,))
        self.assertTrue(report.certified, report.diagnostics)
        self.assertFailure(self.report('torus', parents=parents), 'undeclared_intersection')
        self.assertFailure(self.report('torus', parents=parents, intersections=(replace(crossing, kind='projection'),)),
                           'projection_crossing')
        self.assertFailure(self.report('torus', parents=parents, intersections=(replace(crossing, corner='pixel-crossing'),)),
                           'unknown_vertex')

    def test_projection_claim_does_not_join_distinct_vertices(self):
        cell, spec = self.cases['pair-of-pants']
        parents = (ParentCut('A', 1, 'arc', ('a',), ('a', 'B1')),
                   ParentCut('C', 2, 'arc', ('c',), ('c', 'B2')))
        good = validate_cut_system(replace(cell, parents=parents), spec)
        self.assertTrue(good.certified, good.diagnostics)
        bad = validate_cut_system(replace(cell, parents=parents,
                                          intersections=(Intersection('a', ('A', 'C')),)), spec)
        self.assertFailure(bad, 'false_intersection')

    def test_parent_walks_end_on_actual_boundary_or_mark(self):
        for name, parent in (('annulus', ParentCut('A', 1, 'arc', ('a',), ('a', 'B1'))),
                             ('marked-disk', ParentCut('A', 1, 'arc', ('a',), ('a', '-a')))):
            report = self.report(name, parents=(parent,))
            self.assertTrue(report.certified, report.diagnostics)
            self.assertFailure(self.report(name, parents=(replace(parent, endpoints=parent.endpoints[::-1]),)), 'parent_endpoint')
        self.assertFailure(self.report('torus', parents=(ParentCut('A', 1, 'arc', ('a',), ('a', 'b')),)), 'parent_endpoint')

    def test_duplicate_number_shared_edge_unassigned_and_discontinuous_walk(self):
        parents = (ParentCut('A', 1, 'closed', ('a',)), ParentCut('B', 1, 'closed', ('b',)))
        self.assertFailure(self.report('torus', parents=parents), 'cut_number')
        self.assertFailure(self.report('torus', parents=(ParentCut('A', 1, 'closed', ('a', '-a')),)), 'shared_edge')
        self.assertFailure(self.report('torus', parents=parents[:1]), 'unassigned_cut')
        self.assertFailure(self.report('pair-of-pants', parents=(ParentCut('A', 1, 'arc', ('a', 'c')),)), 'parent_walk')
        self.assertFailure(self.report('torus', parents=(ParentCut('A', 1, 'closed', ('a', 'b')),)), 'parent_self_intersection')

    def test_higher_genus_spines_and_every_genus_two_cut_subset(self):
        for genus in (1, 2, 3, 5, 8):
            word = ' '.join(f'a{i} b{i} -a{i} -b{i}' for i in range(genus))
            cell, spec = _examples.polygon('spine', word, genus)
            report = validate_cut_system(cell, spec)
            self.assertTrue(report.certified, report.diagnostics)
            self.assertEqual(report.full[0].euler, 2-2*genus)
            self.assertEqual(report.complement[0].euler, 1)
        cell, spec = self.cases['genus-two']
        for count in range(5):
            for cuts in combinations(cell.cuts, count):
                report = validate_cut_system(replace(cell, cuts=cuts), spec)
                self.assertEqual(report.certified, count == 4, cuts)
                self.assertEqual(report.full[0].genus, 2)

    def test_reversing_edge_reference_does_not_change_topology(self):
        cell, spec = self.cases['annulus']
        original = validate_cut_system(cell, spec)
        pair, = cell.pairs
        changed = replace(cell, pairs=(replace(pair, first=pair.second, second=pair.first),),
                          parents=(ParentCut('A', 1, 'arc', ('-a',), ('-a', 'B0')),))
        report = validate_cut_system(changed, spec)
        self.assertTrue(report.certified, report.diagnostics)
        self.assertEqual(report.full, original.full)
        self.assertEqual(report.complement, original.complement)

    def test_limits_duplicates_and_unknown_cut(self):
        cell, spec = self.cases['disk']
        self.assertFailure(validate_cut_system(replace(cell, faces=()), spec), 'input_limit')
        self.assertFailure(validate_cut_system(replace(cell, faces=(Face('disk', ('x', 'x', 'y')),)), spec), 'duplicate_id')
        self.assertFailure(validate_cut_system(replace(cell, cuts=('unknown',)), spec), 'unknown_cut')
        self.assertFailure(validate_cut_system(cell, replace(spec, genus=True)), 'invalid_genus')
        self.assertFailure(validate_cut_system(replace(cell, faces=cell.faces*4097), spec), 'input_limit')
        self.assertFailure(validate_cut_system(replace(cell, marks=(Mark('M', face='disk'),)*16385), spec), 'input_limit')

    def test_tangent_closed_parents_are_not_transverse_intersections(self):
        # Two triangular petals embedded on a sphere share only one vertex.
        # Each loop is embedded, but their ends do not alternate there.
        faces = (Face('left', ('a', 'b', 'c')), Face('right', ('d', 'e', 'f')),
                 Face('outside', ('-c', '-b', '-a', '-f', '-e', '-d')))
        pairs = tuple(SidePair(s, s, '-'+s) for s in 'abcdef')
        cell = Cellulation(faces, pairs, cuts=tuple('abcdef'))
        spec = SurfaceSpec('sphere', 0)
        report = validate_cut_system(cell, spec)
        self.assertTrue(report.certified, report.diagnostics)
        self.assertEqual(len(report.complement), 3)
        cell = replace(cell, parents=(ParentCut('A', 1, 'closed', ('a', 'b', 'c')),
                                      ParentCut('D', 2, 'closed', ('d', 'e', 'f'))),
                       intersections=(Intersection('a', ('A', 'D')),))
        self.assertFailure(validate_cut_system(cell, spec), 'nontransverse_intersection')

    def test_vertex_assertions_cannot_create_pinches_with_unchanged_euler_data(self):
        cell, spec = self.cases['disk']
        report = validate_cut_system(cell, spec)
        vertex = report.vertices[0]
        # A claimed common vertex would join separate interval links. The valid
        # disk's Euler count is still 1, but cannot excuse the false incidence.
        pinched = VertexIncidence(vertex.id, vertex.ends, ('B0a', 'B0b'))
        report = validate_cut_system(replace(cell, incidences=(pinched,)), spec)
        self.assertEqual(report.full[0].euler, 1)
        self.assertFailure(report, 'vertex_identity')
        good = replace(pinched, corners=vertex.corners)
        self.assertTrue(validate_cut_system(replace(cell, incidences=(good,)), spec).certified)

    def test_refined_torus_has_same_topology_with_auxiliary_diagonal(self):
        # Subdivide the fundamental square into two triangles. The diagonal d
        # remains glued and must not be mistaken for an extra selected cut.
        cell = Cellulation((Face('F1', ('a', 'b', 'd')), Face('F2', ('-d', '-a', '-b'))),
                           (SidePair('a', 'a', '-a'), SidePair('b', 'b', '-b'), SidePair('d', 'd', '-d')),
                           cuts=('a', 'b'))
        spec = SurfaceSpec('refined-torus', 1)
        report = validate_cut_system(cell, spec)
        self.assertTrue(report.certified, report.diagnostics)
        self.assertEqual(len(report.complement), 1)
        self.assertEqual(report.full[0].euler, 0)
        self.assertEqual(report.complement[0].euler, 1)
        self.assertEqual(report.complement[0].faces, ('F1', 'F2'))
        self.assertFailure(validate_cut_system(replace(cell, cuts=('a',)), spec), 'residual_topology')

    def test_presentation_binding_cannot_be_certified_by_matching_genus(self):
        cell, spec = self.cases['torus']
        self.assertFailure(validate_cut_system(cell, spec, scope='genus-svg'), 'unsupported_binding')

    def test_face_rotation_and_record_order_preserve_certification(self):
        for name, (cell, spec) in self.cases.items():
            original = validate_cut_system(cell, spec)
            changed = replace(cell, faces=tuple(Face(f.id, f.sides[1:]+f.sides[:1]) for f in reversed(cell.faces)),
                              pairs=tuple(reversed(cell.pairs)), boundaries=tuple(reversed(cell.boundaries)),
                              cuts=tuple(reversed(cell.cuts)))
            self.assertEqual(original, validate_cut_system(changed, spec), name)


if __name__ == '__main__':
    unittest.main()
