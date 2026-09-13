"""Numbered cut-disk diagnostics; each polygon is an actual certified disk."""

from dataclasses import dataclass
from math import hypot

from .disk_routes import CutAtlas
from .primitives import Drawing, Ellipse, Path, Text


@dataclass(frozen=True)
class CutDiskDiagram:
    system: object
    routes: tuple = ()
    intersections: tuple = ()
    show_ids: bool = False
    show_segments: bool = False

    def drawing(self, style):
        atlas = CutAtlas.build(self.system)
        routed = atlas.family(self.routes, intersections=self.intersections)
        by_side = {s: pair for pair in self.system.cellulation.pairs for s in (pair.first, pair.second)}
        numbers = {by_side[s].id: parent.number for parent in self.system.cellulation.parents for s in parent.walk}
        segments = {by_side[s].id: (parent.number, i)
                    for parent in self.system.cellulation.parents
                    for i, s in enumerate(parent.walk, 1)}
        boundaries = {b.side: b.boundary for b in self.system.cellulation.boundaries}
        radii = [max(80, 7*len(chart.sides)) for chart in atlas.charts]
        widths = [2*r+100 for r in radii]
        width, height = sum(widths), 2*max(radii)+100
        paths, texts, marks, cursor = [], [], [], -width/2
        report = self.system.validate()
        for chart, radius, panel_width in zip(atlas.charts, radii, widths):
            cx = cursor+panel_width/2
            cursor += panel_width
            def point(p):
                return cx+radius*p[0], radius*p[1]
            texts.append(Text(cx, radius+38, chart.id, style.outline_color, 12))
            for i, side in enumerate(chart.sides):
                a, b = chart.vertices[i], chart.vertices[(i+1)%len(chart.sides)]
                boundary = side in boundaries
                color = style.outline_color if boundary else '#9c83a4'
                paths.append(Path((('M', *point(a)), ('L', *point(b))), color,
                                  style.outline_width, 'disk-boundary' if boundary else 'cut-side'))
                if boundary:
                    label = boundaries[side]
                elif self.show_ids:
                    label = side
                else:
                    pair = by_side[side]
                    prefix = ('.'.join(map(str, segments[pair.id]))
                              if self.show_segments and pair.id in segments
                              else str(numbers.get(pair.id, pair.id)))
                    label = prefix+('+' if side == pair.first else '-')
                x, y = (a[0]+b[0])/2, (a[1]+b[1])/2
                length = hypot(x, y)
                label_point = point((x+12/radius*x/length, y+12/radius*y/length))
                texts.append(Text(*label_point, label, color, 8))
            for mark in self.system.cellulation.marks:
                vertex = next(v for v in report.vertices if mark.corner in v.corners)
                for corner in vertex.corners:
                    if corner in chart.sides:
                        p = chart.point(corner, 0)
                        x, y = point(p)
                        marks.append(Ellipse(x, y, 2.5, 2.5, style.marked_point_color, 'none', 0, 'marked-point'))
                        texts.append(Text(*point((p[0]*.86, p[1]*.86)), mark.id, style.marked_point_color, 9))
            for curve in routed:
                for piece in curve.pieces:
                    if piece.chart == chart.id:
                        paths.append(Path((('M', *point(piece.start)), ('L', *point(piece.end))),
                                          style.curve_color, style.curve_width, 'disk-route'))
        return Drawing(width, height, tuple(marks), tuple(paths), tuple(texts))

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)
