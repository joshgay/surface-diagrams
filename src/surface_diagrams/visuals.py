"""Presentation-only overlays, braid drawings, and aligned figure panels.

These objects draw supplied data. They do not compute mapping-class actions,
certify a cut system, or verify a correspondence between adjacent panels.
"""
from dataclasses import dataclass, replace

from .model import PlanarSurface, Style, _number
from .curves import Arc, Loop
from .primitives import Drawing, Path, Text

RAINBOW = ('#d73027', '#e08214', '#b59b00', '#23964f', '#168aad', '#5254c8', '#973aa8')


@dataclass(frozen=True)
class ColoredCurve:
    """A stable visual ID, an existing Arc/Loop, and a persistent color."""
    id: str
    curve: object
    color: str

    def __post_init__(self):
        if not isinstance(self.id, str) or not self.id:
            raise ValueError('curve ID must be a nonempty string')
        if not isinstance(self.curve, (Arc, Loop)):
            raise TypeError('ColoredCurve needs a planar Arc or Loop')
        Style(curve_color=self.color)


@dataclass(frozen=True)
class PlanarDiagram:
    """Colored planar curves, routed together unless overlays are requested.

    allow_intersections=True routes each curve independently. It allows visible
    intersections but does not certify their number, transversality, or isotopy.
    It can also produce coincident portions: inspect the result. Each individual
    curve still receives the existing containment and obstacle checks.
    """
    surface: PlanarSurface
    curves: tuple = ()
    allow_intersections: bool = False

    def __post_init__(self):
        if not isinstance(self.surface, PlanarSurface) or self.surface.curves:
            raise ValueError('use a bare PlanarSurface and put curves in ColoredCurve records')
        object.__setattr__(self, 'curves', tuple(self.curves))
        if any(not isinstance(c, ColoredCurve) for c in self.curves):
            raise TypeError('curves must contain ColoredCurve records')
        if len({c.id for c in self.curves}) != len(self.curves):
            raise ValueError('curve IDs must be distinct within a panel')
        if not isinstance(self.allow_intersections, bool):
            raise ValueError('allow_intersections must be boolean')

    def drawing(self, style):
        from .layout import layout
        if not self.allow_intersections:
            drawing = layout(self.surface.with_curves(*(c.curve for c in self.curves)), style)
            colors = iter(c.color for c in self.curves)
            paths = tuple(replace(p, stroke=next(colors)) if p.role in ('arc', 'closed-curve') else p
                          for p in drawing.paths)
            return replace(drawing, paths=paths)
        base = layout(self.surface, style)
        paths = list(base.paths)
        for curve in self.curves:
            layer = layout(self.surface.with_curves(curve.curve),
                           replace(style, curve_color=curve.color, show_guides=False))
            paths.extend(layer.paths)
        return replace(base, paths=tuple(paths))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


@dataclass(frozen=True)
class BraidDiagram:
    """Draw signed adjacent crossings, read top to bottom.

    +i: the strand in position i passes OVER position i+1 (positions are 1-based).
    -i: it passes UNDER. Colors track starting strand IDs through crossings.
    The empty word draws the identity. No braid equality or lifting is computed.
    """
    strands: int
    word: tuple = ()
    spacing: float = 30
    step: float = 36
    colors: tuple = RAINBOW

    def __post_init__(self):
        if type(self.strands) is not int or self.strands < 1:
            raise ValueError('strands must be a positive integer')
        object.__setattr__(self, 'word', tuple(self.word))
        if any(type(i) is not int or not 1 <= abs(i) < self.strands for i in self.word):
            raise ValueError('each crossing must be a nonzero signed index smaller than strands')
        _number(self.spacing, 'spacing', positive=True)
        _number(self.step, 'step', positive=True)
        object.__setattr__(self, 'colors', tuple(self.colors))
        if not self.colors:
            raise ValueError('provide at least one strand color')
        for color in self.colors:
            Style(curve_color=color)

    def drawing(self, style):
        paths, texts = [], []
        levels = max(1, len(self.word))
        h = levels*self.step
        xs = [(i-(self.strands-1)/2)*self.spacing for i in range(self.strands)]
        order = list(range(self.strands))
        # Straight crossing segments with a genuine gap in the underpass:
        # transparent backgrounds work without white masks.
        if style.curve_width*4 >= min(self.spacing, self.step):
            raise ValueError('braid strokes are too wide; increase spacing/step or reduce curve_width')
        gap = min(.24, max(.10, style.curve_width*1.6/self.spacing))
        for level in range(levels):
            crossing = self.word[level] if self.word else None
            left = abs(crossing)-1 if crossing else -2
            y0, y1 = h/2-level*self.step, h/2-(level+1)*self.step
            for pos, identity in enumerate(order):
                dest = left+1 if pos == left else left if pos == left+1 else pos
                under = (pos == left+1 if crossing and crossing > 0 else pos == left)
                x0, x1 = xs[pos], xs[dest]
                def point(t):
                    return x0+(x1-x0)*t, y0+(y1-y0)*t
                commands = [('M', x0, y0)]
                if under:
                    commands.extend((('L', *point(.5-gap)), ('M', *point(.5+gap))))
                commands.append(('L', x1, y1))
                paths.append(Path(tuple(commands), self.colors[identity % len(self.colors)],
                                  style.curve_width, 'braid-strand'))
            if crossing:
                order[left], order[left+1] = order[left+1], order[left]
        for pos in range(self.strands):
            texts.append(Text(xs[pos], h/2+8, str(pos+1), self.colors[pos % len(self.colors)], 9))
            identity = order[pos]
            texts.append(Text(xs[pos], -h/2-14, str(identity+1), self.colors[identity % len(self.colors)], 9))
        return Drawing(max(self.spacing, (self.strands-1)*self.spacing)+2*style.padding,
                       h+40+2*style.padding, (), tuple(paths), tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


@dataclass(frozen=True)
class Panel:
    diagram: object
    title: str = ''
    style: object = None

    def __post_init__(self):
        if not isinstance(self.title, str):
            raise TypeError('panel title must be a string')
        if self.style is not None and not isinstance(self.style, Style):
            raise TypeError('panel style must be a Style')
        if self.style is not None and self.style.background is not None:
            raise ValueError('set background on the whole Figure export, not a Panel')


def _shift(drawing, dx, dy):
    def commands(items):
        result = []
        for op, *v in items:
            if op == 'A':
                v[-2] += dx
                v[-1] += dy
            else:
                v = [value+(dx if i % 2 == 0 else dy) for i, value in enumerate(v)]
            result.append((op, *v))
        return tuple(result)
    return Drawing(drawing.width, drawing.height,
                   tuple(replace(s, x=s.x+dx, y=s.y+dy) for s in drawing.ellipses),
                   tuple(replace(p, commands=commands(p.commands)) for p in drawing.paths),
                   tuple(replace(t, x=t.x+dx, y=t.y+dy) for t in drawing.texts))


@dataclass(frozen=True)
class Figure:
    """Aligned rows of Panels; one panel per row makes a vertical stack.

    Titles support explicit newlines. Column widths and row heights are automatic;
    diagrams retain their drawing units and are not silently rescaled.
    """
    rows: tuple
    gap: float = 24

    def __post_init__(self):
        object.__setattr__(self, 'rows', tuple(tuple(row) for row in self.rows))
        if not self.rows or any(not row for row in self.rows):
            raise ValueError('provide nonempty rows of Panels')
        if any(not isinstance(p, Panel) for row in self.rows for p in row):
            raise TypeError('Figure rows must contain Panels')
        _number(self.gap, 'gap')
        if self.gap < 0:
            raise ValueError('gap must be nonnegative')

    def drawing(self, style):
        from .layout import layout
        drawings = [[layout(p.diagram, p.style or style) for p in row] for row in self.rows]
        widths = [max(max(ds[j].width, max((len(t)*6 for t in row[j].title.splitlines()), default=0)+12)
                      for row, ds in zip(self.rows, drawings) if j < len(row))
                  for j in range(max(map(len, self.rows)))]
        headers = [max((len(p.title.splitlines())*15+8 if p.title else 0 for p in row)) for row in self.rows]
        heights = [max(d.height for d in row)+head for row, head in zip(drawings, headers)]
        w = sum(widths)+self.gap*(len(widths)-1)
        h = sum(heights)+self.gap*(len(heights)-1)
        ellipses, paths, texts = [], [], []
        top = h/2
        for row, ds, head, height in zip(self.rows, drawings, headers, heights):
            left = -w/2
            for panel, d, width in zip(row, ds, widths):
                x = left+width/2
                moved = _shift(d, x, top-head-(height-head)/2)
                ellipses.extend(moved.ellipses)
                paths.extend(moved.paths)
                texts.extend(moved.texts)
                for i, line in enumerate(panel.title.splitlines()):
                    texts.append(Text(x, top-12-i*15, line, style.outline_color, 10))
                left += width+self.gap
            top -= height+self.gap
        return Drawing(w+2*style.padding, h+2*style.padding, tuple(ellipses), tuple(paths), tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)
