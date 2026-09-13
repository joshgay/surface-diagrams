import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

from surface_diagrams import DiagramDocument, Style, render_svg, render_tikz
from surface_diagrams.documents import MAX_DOCUMENT_BYTES, example_document


class DocumentTests(unittest.TestCase):
    def recipe(self, kind='planar'):
        return example_document(kind).to_dict()

    def test_round_trip_both_kinds(self):
        for kind in ('planar', 'braid'):
            with self.subTest(kind=kind):
                document = example_document(kind)
                self.assertEqual(document, DiagramDocument.from_json(document.to_json()))
                self.assertEqual(document, DiagramDocument.from_dict(document.to_dict()))
                self.assertEqual(document.render_svg(), DiagramDocument.from_json(document.to_json()).render_svg())

    def test_independent_copy_and_immutable_source(self):
        document = example_document()
        data = document.to_dict()
        data['curves'][0]['cuts'].append(4)
        self.assertEqual(document.to_dict()['curves'][0]['cuts'], [])
        with self.assertRaises(AttributeError):
            document.source = '{}'

    def test_convention_defaults(self):
        data = self.recipe()
        self.assertEqual(data['style']['marked_point_color'], '#006fff')
        self.assertEqual(data['style']['boundary_color'], '#8b8b8b')
        self.assertEqual(data['curves'][0]['color'], '#ff00d4')
        self.assertFalse(data['allow_intersections'])
        self.assertEqual(self.recipe('braid')['braid']['direction'], 'bottom-to-top')

    def test_version_format_and_kind_are_strict(self):
        for key, value in [('version', 2), ('version', True), ('format', 'svg'), ('kind', 'genus')]:
            data = self.recipe(); data[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)

    def test_unknown_fields_at_every_level(self):
        for location in ('document', 'surface', 'object', 'curve', 'style', 'braid', 'label'):
            data = self.recipe('braid' if location == 'braid' else 'planar')
            data['labels'] = [{'id': 'label1', 'text': 'A', 'x': 0, 'y': 0}]
            target = {'document': data, 'surface': data.get('surface'),
                      'object': data.get('surface', {}).get('objects', [None])[0],
                      'curve': data.get('curves', [None])[0], 'style': data['style'],
                      'braid': data.get('braid'), 'label': data['labels'][0]}[location]
            target['future_field'] = 12
            with self.subTest(location=location), self.assertRaisesRegex(ValueError, 'unknown fields'):
                DiagramDocument.from_dict(data)

    def test_duplicate_json_fields_rejected(self):
        text = example_document().to_json().replace('"version": 1', '"version": 1, "version": 1')
        with self.assertRaisesRegex(ValueError, 'duplicate JSON field'):
            DiagramDocument.from_json(text)

    def test_limits_and_bad_json(self):
        for text in ('{', '[]', 'null', ' '*MAX_DOCUMENT_BYTES+'{}', '['*2000+'0'+']'*2000):
            with self.subTest(size=len(text)), self.assertRaises(ValueError):
                DiagramDocument.from_json(text)

    def test_ids_unique_and_syntactically_safe(self):
        for value in ('p2', '', '1point', '<script>', 'a'*41):
            data = self.recipe(); data['surface']['objects'][0]['id'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)

    def test_object_order_is_never_silently_changed(self):
        data = self.recipe()
        data['surface']['objects'][0]['x'] = 10
        with self.assertRaisesRegex(ValueError, 'renumber endpoints and cuts'):
            DiagramDocument.from_dict(data)

    def test_off_axis_and_boolean_coordinates_rejected(self):
        for key, value in [('y', 1), ('y', False), ('x', True), ('x', '4'), ('radius', 0)]:
            data = self.recipe(); data['surface']['objects'][0][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)

    def test_finite_bounded_dimensions(self):
        for value in (float('nan'), float('inf'), -1, 5001, True):
            data = self.recipe(); data['surface']['width'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)

    def test_endpoint_and_cut_ranges(self):
        for key, value in [('start', -1), ('end', 6), ('start', True), ('cuts', [5]), ('cuts', [False])]:
            data = self.recipe(); data['curves'][0][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)

    def test_cut_order_preserved_without_simplification(self):
        data = self.recipe()
        data['curves'] = [{'id': 'a', 'kind': 'arc', 'start': 1, 'end': 4, 'cuts': [3, 1]}]
        result = DiagramDocument.from_dict(data).to_dict()['curves'][0]
        self.assertEqual(result['cuts'], [3, 1])
        data['curves'][0]['cuts'] = [3, 3, 1]
        with self.assertRaisesRegex(ValueError, 'nonminimal'):
            DiagramDocument.from_dict(data)

    def test_loop_fields_preserved(self):
        data = self.recipe()
        data['curves'] = [{'id': 'loop1', 'kind': 'loop', 'cuts': [0, 4], 'start_up': False}]
        document = DiagramDocument.from_dict(data)
        self.assertEqual(document.to_dict()['curves'][0]['cuts'], [0, 4])
        self.assertFalse(document.to_dict()['curves'][0]['start_up'])
        ET.fromstring(document.render_svg())

    def test_boundary_objects_and_explicit_rim_choices(self):
        data = self.recipe()
        data['surface']['objects'][0]['kind'] = 'boundary'
        data['style']['boundary_shape'] = 'circle'
        data['curves'][0]['start_side'] = 'right'
        document = DiagramDocument.from_dict(data)
        self.assertEqual(document.to_dict()['curves'][0]['start_side'], 'right')
        self.assertIn('inner-boundary-circle', document.render_svg())

    def test_explicit_intersection_overlay(self):
        data = self.recipe()
        data['curves'].append({'id': 'arc2', 'kind': 'arc', 'start': 2, 'end': 4})
        # The schema preserves drafts; geometric rejection belongs to rendering.
        document = DiagramDocument.from_dict(data)
        with self.assertRaises(ValueError):
            document.render_svg()
        data['allow_intersections'] = True
        ET.fromstring(DiagramDocument.from_dict(data).render_svg())

    def test_labels_are_escaped_and_expand_both_export_frames(self):
        data = self.recipe()
        data['title'] = '<study & proof>'
        data['labels'] = [{'id': 'note', 'text': '<tag>&_50%', 'x': 500, 'y': 300, 'size': 16}]
        document = DiagramDocument.from_dict(data)
        drawing = document.drawing(document.style)
        self.assertGreater(drawing.width, 1000)
        self.assertGreater(drawing.height, 600)
        root = ET.fromstring(document.render_svg())
        self.assertIsNone(root.find('.//{http://www.w3.org/2000/svg}tag'))
        self.assertIn('&lt;tag&gt;&amp;_50%', document.render_svg())
        self.assertIn(r'\_50\%', document.render_tikz())
        self.assertIn('<tag>&_50%', [node.text for node in root.iter()])

    def test_color_and_label_injection_rejected(self):
        for style in ({'curve_color': 'url(https://example.com)'}, {'background': 'red'}, {'padding': 201}):
            data = self.recipe(); data['style'].update(style)
            with self.subTest(style=style), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)
        data = self.recipe(); data['labels'] = [{'id': 'x', 'text': 'a\nb', 'x': 0, 'y': 0}]
        with self.assertRaises(ValueError):
            DiagramDocument.from_dict(data)

    def test_preview_coordinates_and_transport(self):
        preview = example_document().preview()
        self.assertEqual([h['number'] for h in preview['handles']], list(range(6)))
        self.assertEqual([c['number'] for c in preview['cuts']], list(range(5)))
        self.assertEqual(preview['handles'][1]['x'], preview['width']/2-120)
        steps = example_document('braid').preview()['steps']
        self.assertEqual(steps[0]['entry'], [1, 2, 3, 4])
        self.assertEqual(steps[0]['exit'], [2, 1, 3, 4])
        for earlier, later in zip(steps, steps[1:]):
            self.assertEqual(earlier['exit'], later['entry'])

    def test_braid_words_and_direction_validate(self):
        for key, value in [('word', [0]), ('word', [4]), ('word', [True]), ('word', [1]*129),
                           ('strands', 0), ('direction', 'sideways'), ('colors', [])]:
            data = self.recipe('braid'); data['braid'][key] = value
            with self.subTest(key=key, value=str(value)[:20]), self.assertRaises(ValueError):
                DiagramDocument.from_dict(data)

    def test_braid_signed_word_is_not_reduced(self):
        data = self.recipe('braid'); data['braid']['word'] = [1, -1, 2, -2]
        document = DiagramDocument.from_dict(data)
        self.assertEqual(document.to_dict()['braid']['word'], [1, -1, 2, -2])
        self.assertEqual(len(document.preview()['steps']), 4)

    def test_generic_serializers_share_document_geometry_and_style(self):
        document = example_document()
        self.assertEqual(render_svg(document, title=document.title), document.render_svg())
        self.assertEqual(render_tikz(document, title=document.title), document.render_tikz())
        self.assertIn('#123456', render_svg(document, style=Style(marked_point_color='#123456')))

    def test_generated_python_reproduces_exports(self):
        for kind in ('planar', 'braid'):
            document = example_document(kind)
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                result = subprocess.run([sys.executable, '-c', document.python_source()],
                                        cwd=directory, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(Path(directory, 'diagram.svg').read_text(), document.render_svg())
                self.assertEqual(Path(directory, 'diagram.tikz').read_text(), document.render_tikz())


if __name__ == '__main__':
    unittest.main()
