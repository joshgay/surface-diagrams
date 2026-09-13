import unittest
from dataclasses import FrozenInstanceError, replace
from xml.etree import ElementTree as ET

from surface_diagrams import (Arc, BraidDiagram, ColoredCurve, FactorPanel,
    FactorizationDiagram, Figure, GenusSurface, Panel, PlanarDiagram, PlanarSurface,
    RAINBOW, RoutingError, Style, TypeIBoundary, render_svg, render_tikz)
from surface_diagrams.layout import layout


class FactorizationTest(unittest.TestCase):
    def setUp(self):
        self.surface = PlanarSurface.row('PPP', spacing=60, height=140, margin=60)
        self.a = FactorPanel('a', Panel(self.surface.with_curves(Arc(1, 2)), 'Arc (1,2)'), braid_word=(1,))
        self.b = FactorPanel('b', Panel(self.surface.with_curves(Arc(2, 3)), 'Arc (2,3)'), exponent=-1, braid_word=(-2,))
        self.diagram = FactorizationDiagram((self.a, self.b), strands=3)

    def drawing(self, diagram=None):
        return layout(self.diagram if diagram is None else diagram, Style())

    def test_application_order_is_independent_of_product_and_display_order(self):
        self.assertEqual(self.diagram.factor_ids, ('a', 'b'))
        self.assertEqual(self.diagram.product_label, '[b]^-1 * [a]')
        for direction in ('bottom-to-top', 'top-to-bottom'):
            diagram = replace(self.diagram, direction=direction)
            texts = {t.text: t.y for t in self.drawing(diagram).texts}
            self.assertEqual(texts['1. [a]'] < texts['2. [b]^-1'], direction == 'bottom-to-top')
            self.assertIn('Application order: '+direction, texts)
            self.assertIn('[b]^-1 * [a]', texts)

    def test_continuous_braid_transports_colors_across_rows_and_gap(self):
        paths = [p for p in self.drawing().paths if p.role == 'braid-strand']
        levels = [paths[i:i+3] for i in range(0, len(paths), 3)]
        crossing_levels = [level for level in levels if any(len(p.commands) == 4 for p in level)]
        self.assertEqual(len(crossing_levels), 2)
        self.assertEqual([p.stroke for p in crossing_levels[0]], list(RAINBOW[:3]))
        self.assertEqual([p.stroke for p in crossing_levels[1]], [RAINBOW[1], RAINBOW[0], RAINBOW[2]])
        for before, after in zip(levels, levels[1:]):
            for p in before:
                next_path = next(q for q in after if q.stroke == p.stroke)
                self.assertEqual(p.commands[-1][1:], next_path.commands[0][1:])
        labels = [t for t in self.drawing().texts if t.text in ('1', '2', '3')]
        entry = min(t.y for t in labels)
        self.assertEqual([t.text for t in labels if t.y == entry], ['1', '2', '3'])
        self.assertEqual([t.text for t in labels if t.y != entry], ['2', '3', '1'])

    def test_crossing_sign_is_fixed_when_traversal_direction_changes(self):
        for direction in ('top-to-bottom', 'bottom-to-top'):
            for word in ((1,), (-1,)):
                drawing = layout(BraidDiagram(2, word, direction=direction), Style())
                under = next(p for p in drawing.paths if len(p.commands) == 4)
                # Positive: upper-RIGHT strand is under; negative: upper-LEFT.
                endpoints = (under.commands[0][1:], under.commands[-1][1:])
                upper = max(endpoints, key=lambda point: point[1])
                self.assertEqual(upper[0] > 0, word[0] > 0)

    def test_braid_word_is_not_reversed_cancelled_or_repeated_by_exponent(self):
        factor = replace(self.a, exponent=3, braid_word=(1, -1, 2))
        diagram = FactorizationDiagram((factor,), strands=3)
        paths = [p for p in self.drawing(diagram).paths if p.role == 'braid-strand']
        # Three supplied crossings, not nine (power) or one (cancellation).
        self.assertEqual(sum(len(p.commands) == 4 for p in paths), 3)
        self.assertEqual(diagram.factors[0].braid_word, (1, -1, 2))
        self.assertEqual(diagram.product_label, '[a]^3')

    def test_explicit_empty_braid_block_keeps_straight_strands(self):
        diagram = replace(self.diagram, factors=(replace(self.a, braid_word=()), self.b))
        paths = [p for p in self.drawing(diagram).paths if p.role == 'braid-strand']
        self.assertTrue(all(len(p.commands) == 2 for p in paths[:6]))
        crossing_level = next(paths[i:i+3] for i in range(0, len(paths), 3)
                              if any(len(p.commands) == 4 for p in paths[i:i+3]))
        self.assertEqual([p.stroke for p in crossing_level], list(RAINBOW[:3]))

    def test_group_bracket_follows_contiguous_factors(self):
        factors = (replace(self.a, group='block'), replace(self.b, group='block'),
                   replace(self.a, id='c', group='tail'))
        drawing = self.drawing(replace(self.diagram, factors=factors))
        groups = [p for p in drawing.paths if p.role == 'factor-group']
        self.assertEqual(len(groups), 2)
        self.assertGreater(abs(groups[0].commands[-1][2]-groups[0].commands[0][2]),
                           abs(groups[1].commands[-1][2]-groups[1].commands[0][2]))
        with self.assertRaisesRegex(ValueError, 'contiguous'):
            replace(self.diagram, factors=(factors[0], replace(factors[1], group=''),
                                           replace(factors[2], group='block')))

    def test_supplied_states_are_complete_and_in_application_order(self):
        factors = (replace(self.a, state=Panel(self.surface, 'C1')),
                   replace(self.b, state=Panel(self.surface, 'C2')))
        diagram = replace(self.diagram, factors=factors, initial_state=Panel(self.surface, 'C0'))
        texts = {t.text: t for t in self.drawing(diagram).texts}
        self.assertLess(texts['C0'].y, texts['C1'].y)
        self.assertLess(texts['C1'].y, texts['C2'].y)
        self.assertEqual(texts['C0'].x, texts['C1'].x)
        self.assertEqual(texts['C1'].x, texts['C2'].x)
        self.assertIn('After [b]^-1 (supplied)', texts)
        with self.assertRaisesRegex(ValueError, 'every factor state'):
            replace(self.diagram, initial_state=Panel(self.surface))
        with self.assertRaisesRegex(ValueError, 'every factor state'):
            replace(self.diagram, factors=factors)

    def test_support_itineraries_colors_and_geometry_are_preserved(self):
        surface = PlanarSurface.row('PPPPPP', spacing=55, height=210, margin=60)
        curve = Arc(2, 5, cuts=(3,), direction='down')
        support = PlanarDiagram(surface, (ColoredCurve('cut-7', curve, RAINBOW[6]),))
        factor = FactorPanel('F7', Panel(support))
        before = layout(support, Style()).paths[0]
        after = self.drawing(FactorizationDiagram((factor,))).paths[0]
        self.assertEqual(factor.support.diagram.curves[0].curve.cuts, (3,))
        self.assertEqual(before.stroke, after.stroke)
        dx = after.commands[0][1]-before.commands[0][1]
        dy = after.commands[0][2]-before.commands[0][2]
        for a, b in zip(before.commands, after.commands):
            self.assertEqual(a[0], b[0])
            if a[0] == 'A':
                self.assertEqual(a[1:6], b[1:6])
            self.assertAlmostEqual(a[-2]+dx, b[-2])
            self.assertAlmostEqual(a[-1]+dy, b[-1])

    def test_bordered_genus_supports_keep_numbered_members_and_dashing(self):
        family = GenusSurface(2, type_i=(TypeIBoundary(6),)).with_reference_arcs()
        factors = tuple(FactorPanel('twist-'+str(n), Panel(family.select(n))) for n in (2, 4))
        drawing = self.drawing(FactorizationDiagram(factors))
        before = [p for f in factors for p in layout(f.support.diagram, Style()).paths]
        self.assertEqual([(p.stroke, p.dashed) for p in before],
                         [(p.stroke, p.dashed) for p in drawing.paths])
        self.assertEqual([f.support.diagram.selection for f in factors], [(2,), (4,)])

    def test_overlay_opt_in_is_not_bypassed(self):
        surface = PlanarSurface.row('PPPP', spacing=60, height=210, margin=65)
        support = PlanarDiagram(surface, (ColoredCurve('a', Arc(1, 3), '#f00'),
                                         ColoredCurve('b', Arc(2, 4), '#00f')))
        with self.assertRaises(RoutingError):
            self.drawing(FactorizationDiagram((FactorPanel('f', Panel(support)),)))

    def test_reordered_supplied_panels_preserve_identity_and_colors(self):
        reordered = replace(self.diagram, factors=self.diagram.factors[::-1])
        self.assertEqual(reordered.factor_ids, ('b', 'a'))
        self.assertEqual(reordered.product_label, '[a] * [b]^-1')
        self.assertIs(reordered.factors[0].support, self.b.support)
        self.assertIs(reordered.factors[1].support, self.a.support)

    def test_empty_factorization_is_identity_with_optional_state_and_braid(self):
        for kwargs in ({}, {'strands': 1}, {'strands': 3, 'initial_state': Panel(self.surface)}):
            diagram = FactorizationDiagram((), **kwargs)
            self.assertEqual(diagram.product_label, '1')
            drawing = self.drawing(diagram)
            self.assertGreater(drawing.width, 0)
            self.assertGreater(drawing.height, 0)
            self.assertTrue(all(len(p.commands) == 2 for p in drawing.paths if p.role == 'braid-strand'))
            ET.fromstring(render_svg(diagram))

    def test_input_records_are_immutable_and_lists_are_copied(self):
        word = [1]
        factor = replace(self.a, braid_word=word)
        factors = [factor]
        diagram = FactorizationDiagram(factors, strands=3, colors=list(RAINBOW))
        word.append(2)
        factors.clear()
        self.assertEqual(diagram.factors, (factor,))
        self.assertEqual(factor.braid_word, (1,))
        with self.assertRaises(FrozenInstanceError):
            factor.id = 'changed'

    def test_rejects_ambiguous_or_invalid_inputs(self):
        for fields in ({'id': ''}, {'id': '  '}, {'id': 'a\nb'}, {'id': 'a\n'}, {'exponent': 0},
                       {'exponent': True}, {'exponent': 1.5}, {'support': self.surface},
                       {'braid_word': (0,)}, {'braid_word': (True,)}, {'group': '\n'},
                       {'state': self.surface}):
            with self.subTest(fields=fields), self.assertRaises((TypeError, ValueError)):
                replace(self.a, **fields)
        for fields in ({'factors': (self.a, self.a)}, {'strands': None}, {'strands': 2},
                       {'strands': True}, {'strands': 0}, {'direction': 'up'},
                       {'gap': -1}, {'gap': float('nan')}, {'braid_spacing': 0},
                       {'colors': ()}, {'colors': ('magenta',)}, {'initial_state': self.surface},
                       {'factors': (replace(self.a, braid_word=None),)}):
            with self.subTest(fields=fields), self.assertRaises((TypeError, ValueError)):
                replace(self.diagram, **fields)
        with self.assertRaises(ValueError):
            BraidDiagram(3, direction='up')

    def test_small_gaps_and_long_words_keep_braid_continuous(self):
        for gap in (0, 1, 24):
            diagram = replace(self.diagram, gap=gap,
                              factors=(replace(self.a, braid_word=(1, -1)*15), self.b))
            paths = [p for p in self.drawing(diagram).paths if p.role == 'braid-strand']
            self.assertEqual(sum(len(p.commands) == 4 for p in paths), 31)
            levels = [paths[i:i+3] for i in range(0, len(paths), 3)]
            for before, after in zip(levels, levels[1:]):
                self.assertEqual(sorted(p.commands[-1][1:] for p in before),
                                 sorted(p.commands[0][1:] for p in after))
            for path in paths:
                if len(path.commands) == 4:
                    self.assertEqual(abs(path.commands[-1][2]-path.commands[0][2]), 36)

    def test_long_labels_fit_frame_and_group_text_is_escaped(self):
        a = replace(self.a, id='a<&>_'*12, group='block<&>')
        diagram = replace(self.diagram, factors=(a, self.b))
        drawing = self.drawing(diagram)
        for t in drawing.texts:
            self.assertLessEqual(abs(t.x)+len(t.text)*t.size*.36, drawing.width/2)
            self.assertLessEqual(abs(t.y)+t.size, drawing.height/2)
        root = ET.fromstring(render_svg(diagram))
        self.assertIn('block<&>', [t.text for t in root.iter()])
        tikz = render_tikz(diagram)
        self.assertIn(r'block<\&>', tikz)
        self.assertNotIn('<rect', render_svg(diagram))

    def test_both_exporters_use_shared_paths_and_support_nested_figures(self):
        diagram = replace(self.diagram, factors=(replace(self.a, group='pair'), replace(self.b, group='pair')))
        drawing = self.drawing(diagram)
        root = ET.fromstring(render_svg(diagram))
        svg_paths = root.findall('{http://www.w3.org/2000/svg}path')
        self.assertEqual(len(svg_paths), len(drawing.paths))
        self.assertEqual([p.get('class') for p in svg_paths], [p.role for p in drawing.paths])
        tikz = render_tikz(diagram)
        self.assertEqual(tikz.count('\\draw['), len(drawing.paths))
        for path in drawing.paths:
            self.assertIn('% '+path.role, tikz)
        figure = Figure(((Panel(diagram, 'Supplied sequence'),),))
        ET.fromstring(render_svg(figure))
        self.assertIn('factor-group', render_tikz(figure))
        self.assertEqual(render_svg(diagram), render_svg(diagram))
        self.assertEqual(diagram._repr_svg_(), render_svg(diagram))

    def test_circular_boundary_support_keeps_transparent_export_clipping(self):
        surface = PlanarSurface.row('BP', spacing=60, height=140, margin=60).with_curves(Arc(1, 2))
        factor = FactorPanel('rim', Panel(surface, style=Style(boundary_shape='circle')))
        diagram = FactorizationDiagram((factor,))
        svg = render_svg(diagram)
        self.assertIn('clipPath', svg)
        self.assertNotIn('<rect', svg)
        self.assertIn(r'\pgfseteorule', render_tikz(diagram))


if __name__ == '__main__':
    unittest.main()
