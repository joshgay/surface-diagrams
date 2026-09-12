from dataclasses import replace
import unittest

from surface_diagrams.cut_systems import validate_cut_system
from surface_diagrams.standard_cuts import chain_system


class StandardCutTests(unittest.TestCase):
    def test_chain_is_the_correct_surface_and_intersection_graph(self):
        for genus in (1, 2, 3, 5, 8):
            system = chain_system(genus)
            report = system.validate()
            self.assertTrue(report.certified, report.diagnostics)
            self.assertEqual(report.full[0].genus, genus)
            self.assertEqual(len(report.complement), 2)
            self.assertEqual(len(system.cellulation.parents), 2*genus+1)
            self.assertEqual([x.parents for x in system.cellulation.intersections],
                             [(f'c{i}', f'c{i+1}') for i in range(1, 2*genus+1)])
            self.assertTrue(all(c.euler == 1 for c in report.complement))

    def test_boundary_mark_cross_product(self):
        for genus in (1, 2, 3, 5):
            for count in (0, 1, 2, 6, 12):
                system = chain_system(genus, boundaries=tuple(f'B{i}' for i in range(count)),
                                      marks=tuple(f'M{i}' for i in range(count//2)))
                report = system.validate()
                self.assertTrue(report.certified, report.diagnostics)
                self.assertEqual(len(report.full[0].boundary_cycles), count)
                self.assertEqual(report.full[0].euler, 2-2*genus-count)
                self.assertEqual(len(report.full[0].interior_marks), count//2)
                self.assertFalse(any(c.interior_marks for c in report.complement))
                self.assertEqual(len(system.cellulation.attachments), count+count//2)

    def test_removing_supplementary_cut_restores_obstruction(self):
        for kind in ('boundaries', 'marks'):
            system = chain_system(2, **{kind: ('X',)})
            cell = system.cellulation
            spoke = cell.parents[-1]
            pair = next(p for p in cell.pairs if p.first in spoke.walk)
            cell = replace(cell, cuts=tuple(c for c in cell.cuts if c != pair.id),
                           parents=(), intersections=(), attachments=())
            report = validate_cut_system(cell, system.surface)
            self.assertFalse(report.certified)
            expected = 'residual_topology' if kind == 'boundaries' else 'interior_marks'
            self.assertIn(expected, [d.code for d in report.diagnostics])

    def test_attachment_is_explicit_and_cannot_fake_crossing(self):
        system = chain_system(1, boundaries=('B',))
        cell = system.cellulation
        report = validate_cut_system(replace(cell, attachments=()), system.surface)
        self.assertFalse(report.certified)
        self.assertEqual(report.diagnostics[0].code, 'parent_endpoint')
        attachment, = cell.attachments
        bad = replace(attachment, through='c2')
        report = validate_cut_system(replace(cell, attachments=(bad,)), system.surface)
        self.assertFalse(report.certified)
        self.assertEqual(report.diagnostics[0].code, 'invalid_attachment')

    def test_ids_and_numbers_are_deterministic(self):
        system = chain_system(3, boundaries=('fixed-8', 'pair-1-upper', 'pair-1-lower'), marks=('M',))
        self.assertEqual(system, chain_system(3, boundaries=system.surface.boundaries, marks=('M',)))
        self.assertEqual(system.numbers[-4:], ((8, 'boundary:fixed-8'), (9, 'boundary:pair-1-upper'),
                                             (10, 'boundary:pair-1-lower'), (11, 'mark:M')))

    def test_invalid_parameters(self):
        for genus in (0, -1, True, 1.5, 65):
            with self.assertRaises(ValueError):
                chain_system(genus)
        for kwargs in ({'boundaries': ('B', 'B')}, {'marks': ('',)}, {'marks': tuple(map(str, range(129)))}):
            with self.assertRaises(ValueError):
                chain_system(1, **kwargs)


if __name__ == '__main__':
    unittest.main()
