"""Versioned, editable diagram recipes. Loading a recipe never executes code.

Version 1 covers planar axis-aligned objects, arcs/loops and signed braid words.
It deliberately does not represent arbitrary SVG, mathematical actions or 3D
surfaces. Unknown fields are errors, not silently discarded future-version data.
"""
from dataclasses import asdict, dataclass, fields, replace
import json
from pprint import pformat
import re

from .model import Boundary, MarkedPoint, PlanarSurface, Style, _number
from .curves import Arc, Loop
from .visuals import BraidDiagram, ColoredCurve, PlanarDiagram, RAINBOW
from .primitives import Text

MAX_DOCUMENT_BYTES = 256 * 1024


def _keys(value, allowed, required, where):
    if not isinstance(value, dict):
        raise ValueError(f'{where} must be an object')
    if set(value)-set(allowed):
        raise ValueError(f'{where}: unknown fields {sorted(set(value)-set(allowed))}')
    if set(required)-set(value):
        raise ValueError(f'{where}: missing fields {sorted(set(required)-set(value))}')


def _text(value, where, maximum=120):
    if not isinstance(value, str) or len(value) > maximum or any(ord(c) < 32 for c in value):
        raise ValueError(f'{where} must be single-line text of at most {maximum} characters')
    return value


def _id(value, where):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,39}', value):
        raise ValueError(f'{where} must start with a letter and use at most 40 letters, digits, _ or -')
    return value


def _list(value, where, maximum):
    if not isinstance(value, list) or len(value) > maximum:
        raise ValueError(f'{where} must be an array of at most {maximum} items')
    return value


def _bounded(value, where, low=-10000, high=10000):
    _number(value, where)
    if not low <= value <= high:
        raise ValueError(f'{where} must be between {low} and {high}')
    return value


def _unique(items, where):
    if len({item['id'] for item in items}) != len(items):
        raise ValueError(f'{where}: IDs must be distinct')


def _objects(spec):
    return tuple((Boundary if o['kind'] == 'boundary' else MarkedPoint)(o['x'], 0, o['radius'])
                 for o in spec['objects'])


def _curve(spec):
    if spec['kind'] == 'loop':
        return Loop(tuple(spec['cuts']), start_up=spec['start_up'])
    return Arc(spec['start'], spec['end'], tuple(spec['cuts']), direction=spec['direction'],
               start_side=spec['start_side'], end_side=spec['end_side'])


def _normalize(data):
    common = {'format', 'version', 'kind', 'title', 'style', 'labels'}
    if not isinstance(data, dict) or data.get('kind') not in ('planar', 'braid'):
        raise ValueError('kind must be planar or braid')
    planar = data['kind'] == 'planar'
    _keys(data, common | ({'surface', 'curves', 'allow_intersections'} if planar else {'braid'}),
          {'format', 'version', 'kind', 'surface' if planar else 'braid'}, 'document')
    if data['format'] != 'surface-diagrams' or type(data['version']) is not int or data['version'] != 1:
        raise ValueError('expected surface-diagrams document version 1')
    result = {'format': 'surface-diagrams', 'version': 1, 'kind': data['kind'],
              'title': _text(data.get('title', 'Untitled diagram'), 'title')}
    style = data.get('style', {})
    _keys(style, {f.name for f in fields(Style)}, (), 'style')
    result['style'] = asdict(Style(**style))
    for key, value in result['style'].items():
        if type(value) in (int, float):
            _bounded(value, 'style.'+key, 0, 200)
    labels = _list(data.get('labels', []), 'labels', 32)
    result['labels'] = []
    for label in labels:
        _keys(label, {'id', 'text', 'x', 'y', 'color', 'size'}, {'id', 'text', 'x', 'y'}, 'label')
        color = label.get('color', '#000000')
        Style(curve_color=color)
        result['labels'].append({'id': _id(label['id'], 'label.id'),
            'text': _text(label['text'], 'label.text'), 'x': _bounded(label['x'], 'label.x'),
            'y': _bounded(label['y'], 'label.y'), 'color': color,
            'size': _bounded(label.get('size', 12), 'label.size', 1, 48)})
    _unique(result['labels'], 'labels')
    if not planar:
        braid = data['braid']
        _keys(braid, {'strands', 'word', 'spacing', 'step', 'colors', 'direction'}, {'strands', 'word'}, 'braid')
        if type(braid['strands']) is not int or not 1 <= braid['strands'] <= 32:
            raise ValueError('braid.strands must be an integer between 1 and 32')
        _list(braid['word'], 'braid.word', 128)
        colors = braid.get('colors', list(RAINBOW))
        _list(colors, 'braid.colors', 32)
        obj = BraidDiagram(braid['strands'], tuple(braid['word']),
            spacing=_bounded(braid.get('spacing', 40), 'braid.spacing', 5, 300),
            step=_bounded(braid.get('step', 48), 'braid.step', 5, 300), colors=tuple(colors),
            direction=braid.get('direction', 'bottom-to-top'))
        result['braid'] = asdict(obj)
    else:
        surface = data['surface']
        _keys(surface, {'width', 'height', 'objects'}, {'width', 'height', 'objects'}, 'surface')
        objects = []
        for item in _list(surface['objects'], 'surface.objects', 32):
            _keys(item, {'id', 'kind', 'x', 'y', 'radius'}, {'id', 'kind', 'x'}, 'object')
            _bounded(item.get('y', 0), 'object.y')
            if item['kind'] not in ('point', 'boundary') or item.get('y', 0) != 0:
                raise ValueError('planar objects must be point/boundary records on y=0')
            radius = item.get('radius')
            if radius is not None:
                _bounded(radius, 'object.radius', .1, 200)
            objects.append({'id': _id(item['id'], 'object.id'), 'kind': item['kind'],
                            'x': _bounded(item['x'], 'object.x'), 'y': 0, 'radius': radius})
        _unique(objects, 'objects')
        if any(a['x'] >= b['x'] for a, b in zip(objects, objects[1:])):
            raise ValueError('keep objects strictly left-to-right; moving past a neighbor would renumber endpoints and cuts')
        result['surface'] = {'width': _bounded(surface['width'], 'surface.width', 20, 5000),
                             'height': _bounded(surface['height'], 'surface.height', 20, 5000), 'objects': objects}
        PlanarSurface(_objects(result['surface']), surface['width'], surface['height'])
        intersections = data.get('allow_intersections', False)
        if type(intersections) is not bool:
            raise ValueError('allow_intersections must be boolean')
        result['allow_intersections'] = intersections
        result['curves'] = []
        for i, curve in enumerate(_list(data.get('curves', []), 'curves', 16)):
            where = f'curves[{i}]'
            if not isinstance(curve, dict) or curve.get('kind') not in ('arc', 'loop'):
                raise ValueError(where+': kind must be arc or loop')
            arc = curve['kind'] == 'arc'
            _keys(curve, {'id', 'kind', 'color', 'cuts'} | ({'start', 'end', 'direction', 'start_side', 'end_side'}
                  if arc else {'start_up'}), {'id', 'kind'} | ({'start', 'end'} if arc else {'cuts'}), where)
            cuts = _list(curve.get('cuts', []), where+'.cuts', 64)
            if any(type(c) is not int or not 0 <= c <= len(objects) for c in cuts):
                raise ValueError(where+': cut number outside 0..n')
            color = curve.get('color', result['style']['curve_color'])
            Style(curve_color=color)
            normalized = {'id': _id(curve['id'], where+'.id'), 'kind': curve['kind'], 'cuts': cuts, 'color': color}
            if arc:
                for endpoint in ('start', 'end'):
                    if type(curve[endpoint]) is not int or not 0 <= curve[endpoint] <= len(objects)+1:
                        raise ValueError(where+': endpoint outside 0..n+1')
                normalized.update(start=curve['start'], end=curve['end'], direction=curve.get('direction', 'default'),
                                  start_side=curve.get('start_side'), end_side=curve.get('end_side'))
            else:
                normalized['start_up'] = curve.get('start_up', True)
            try:
                _curve(normalized)
            except (ValueError, TypeError) as error:
                raise ValueError(where+': '+str(error)) from error
            result['curves'].append(normalized)
        _unique(result['curves'], 'curves')
    return result


def _duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON field: '+key)
        result[key] = value
    return result


@dataclass(frozen=True)
class DiagramDocument:
    """An immutable, validated recipe; geometric routing is checked on render.

    Construct with from_dict/from_json. to_dict returns an independent copy.
    Save invalid *drafts* in the UI as JSON; image export requires valid geometry.
    """
    source: str

    def __post_init__(self):
        if not isinstance(self.source, str) or len(self.source.encode('utf-8')) > MAX_DOCUMENT_BYTES:
            raise ValueError('document exceeds 256 KiB or is not JSON text')
        try:
            data = json.loads(self.source, object_pairs_hook=_duplicate_keys)
            normalized = _normalize(data)
        except (RecursionError, OverflowError) as error:
            raise ValueError('document is too deeply nested or contains oversized numbers') from error
        object.__setattr__(self, 'source', json.dumps(normalized, sort_keys=True, ensure_ascii=True, allow_nan=False))

    @classmethod
    def from_json(cls, text):
        return cls(text)

    @classmethod
    def from_dict(cls, data):
        return cls(json.dumps(data, allow_nan=False))

    def to_dict(self):
        return json.loads(self.source)

    def to_json(self):
        return json.dumps(self.to_dict(), sort_keys=True, indent=2)+'\n'

    @property
    def style(self):
        return Style(**self.to_dict()['style'])

    @property
    def title(self):
        return self.to_dict()['title']

    def diagram(self):
        data = self.to_dict()
        if data['kind'] == 'braid':
            return BraidDiagram(**data['braid'])
        surface = data['surface']
        return PlanarDiagram(PlanarSurface(_objects(surface), surface['width'], surface['height']),
            tuple(ColoredCurve(c['id'], _curve(c), c['color']) for c in data['curves']),
            allow_intersections=data['allow_intersections'])

    def drawing(self, style):
        from .layout import layout
        drawing = layout(self.diagram(), style)
        labels = tuple(Text(l['x'], l['y'], l['text'], l['color'], l['size']) for l in self.to_dict()['labels'])
        # Labels may sit outside the surface but never silently fall off the
        # exported canvas. Enlarging the frame leaves mathematical coordinates.
        width = max([drawing.width]+[2*(abs(t.x)+len(t.text)*t.size*.5+style.padding) for t in labels])
        height = max([drawing.height]+[2*(abs(t.y)+t.size+style.padding) for t in labels])
        return replace(drawing, width=width, height=height, texts=drawing.texts+labels)

    def render_svg(self):
        from .svg import render_svg
        return render_svg(self, style=self.style, title=self.title)

    def render_tikz(self):
        from .tikz import render_tikz
        return render_tikz(self, style=self.style, title=self.title)

    def python_source(self):
        return ('# Generated editable recipe; requires surface-diagrams.\n'
                'from surface_diagrams import DiagramDocument, save_svg, save_tikz\n\n'
                'document = DiagramDocument.from_dict('+pformat(self.to_dict(), sort_dicts=False)+')\n\n'
                'save_svg(document, "diagram.svg", title=document.title)\n'
                'save_tikz(document, "diagram.tikz", title=document.title)\n')

    def preview(self):
        data = self.to_dict()
        drawing = self.drawing(self.style)
        handles, cuts, steps = [], [], []
        if data['kind'] == 'planar':
            surface = data['surface']
            points = [(-surface['width']/2, 'outer-left')]
            points.extend((o['x'], o['id']) for o in surface['objects'])
            points.append((surface['width']/2, 'outer-right'))
            handles = [{'number': i, 'id': id, 'x': x+drawing.width/2, 'y': drawing.height/2,
                        'kind': 'endpoint'} for i, (x, id) in enumerate(points)]
            cuts = [{'number': i, 'x': (a[0]+b[0])/2+drawing.width/2, 'y': drawing.height/2}
                    for i, (a, b) in enumerate(zip(points, points[1:]))]
        else:
            order = list(range(1, data['braid']['strands']+1))
            for index, generator in enumerate(data['braid']['word']):
                entry = order[:]
                left = abs(generator)-1
                order[left], order[left+1] = order[left+1], order[left]
                steps.append({'index': index, 'generator': generator, 'entry': entry, 'exit': order[:]})
        handles.extend({'id': l['id'], 'kind': 'label', 'x': l['x']+drawing.width/2,
                        'y': drawing.height/2-l['y']} for l in data['labels'])
        return {'document': data, 'svg': self.render_svg(), 'width': drawing.width, 'height': drawing.height,
                'handles': handles, 'cuts': cuts, 'steps': steps}


def example_document(kind='planar'):
    data = {'format': 'surface-diagrams', 'version': 1, 'kind': kind, 'labels': [], 'style': {}}
    if kind == 'planar':
        data.update(title='Planar study', surface={'width': 400, 'height': 210,
            'objects': [{'id': 'p'+str(i+1), 'kind': 'point', 'x': x} for i, x in enumerate((-120, -40, 40, 120))]},
            curves=[{'id': 'arc1', 'kind': 'arc', 'start': 1, 'end': 3, 'cuts': []}])
    else:
        data.update(title='Braid study', braid={'strands': 4, 'word': [1, -2, 3, 1], 'direction': 'bottom-to-top'})
    return DiagramDocument.from_dict(data)
