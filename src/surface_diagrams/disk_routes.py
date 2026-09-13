"""Exact-incidence routes in certified cut disks, before surface projection.

Segments are chords in convex diagnostic polygons. Paired side parameters are
reversed. Geometry uses floating point with an explicit conservative tolerance;
ambiguous near-intersections fail instead of being silently accepted.
"""

from dataclasses import dataclass, replace
from math import cos, sin, pi, isfinite

from .cut_systems import Cellulation, Face, SidePair, BoundarySide, Mark, SurfaceSpec, validate_cut_system

_TOL = 1e-10


class ItineraryError(ValueError):
    pass


@dataclass(frozen=True)
class Crossing:
    side: str
    position: float = .5


@dataclass(frozen=True)
class BoundaryPoint:
    side: str
    position: float = .5


@dataclass(frozen=True)
class MarkPoint:
    id: str
    corner: str = None


@dataclass(frozen=True)
class DiskRoute:
    crossings: tuple
    start: object = None
    end: object = None
    id: str = 'curve'

    @property
    def closed(self):
        return self.start is None and self.end is None


@dataclass(frozen=True)
class DiskChart:
    id: str
    sides: tuple
    vertices: tuple

    def point(self, side, t):
        i = self.sides.index(side)
        a, b = self.vertices[i], self.vertices[(i+1) % len(self.vertices)]
        return (a[0]+t*(b[0]-a[0]), a[1]+t*(b[1]-a[1]))


@dataclass(frozen=True)
class Chord:
    chart: str
    start: tuple
    end: tuple
    start_locator: object
    end_locator: object
    route: str
    index: int


@dataclass(frozen=True)
class RoutedCurve:
    route: DiskRoute
    pieces: tuple


@dataclass(frozen=True)
class CutAtlas:
    system: object
    charts: tuple

    @classmethod
    def build(cls, system):
        report = system.validate()
        if not report.certified:
            raise ItineraryError('route needs certified cut disks: '+str(report.diagnostics))
        charts = []
        for component in report.complement:
            sides = component.boundary_cycles[0]
            n = len(sides)
            if n < 3:
                raise ItineraryError('subdivide the cut boundary to at least three sides')
            # Stable side order comes from the validator, independent of style.
            vertices = tuple((cos(2*pi*i/n), sin(2*pi*i/n)) for i in range(n))
            charts.append(DiskChart(component.faces[0], sides, vertices))
        return cls(system, tuple(charts))

    @property
    def sides(self):
        return {s: c for c in self.charts for s in c.sides}

    @property
    def pairs(self):
        return {s: p for p in self.system.cellulation.pairs for s in (p.first, p.second)
                if p.id in self.system.cellulation.cuts}

    def cross(self, locator):
        _position(locator.position)
        pair = self.pairs.get(locator.side)
        if pair is None:
            raise ItineraryError('crossing must name a selected cut side: '+str(locator.side))
        other = pair.second if locator.side == pair.first else pair.first
        return Crossing(other, 1-locator.position)

    def crossing_on_cut(self, number, *, segment=1, bank='+', position=.5):
        """Select an explicit numbered segment/bank from the cut-disk guide.

        Segment numbers are 1-based in ParentCut.walk order. Banks match the
        side pair's first (+) and second (-) sides. These are coordinates for
        this cellulation, not coordinates invariant under mesh changes.
        """
        _position(position)
        if type(number) is not int or type(segment) is not int or segment < 1:
            raise ItineraryError('cut and segment numbers must be positive integers')
        if bank not in ('+', '-'):
            raise ItineraryError("bank must be '+' or '-'")
        parents = [p for p in self.system.cellulation.parents if p.number == number]
        if len(parents) != 1 or segment > len(parents[0].walk):
            raise ItineraryError('unknown cut or segment number')
        edge = parents[0].walk[segment-1]
        pair = self.pairs.get(edge)
        if pair is None:
            raise ItineraryError('segment is not a selected cut side')
        return Crossing(pair.first if bank == '+' else pair.second, position)

    def resolve_number(self, number, *, source_chart=None):
        parents = [p for p in self.system.cellulation.parents if p.number == number]
        if len(parents) != 1:
            raise ItineraryError('unknown cut number: '+str(number))
        parent = parents[0]
        pair_map = {s: p for p in self.system.cellulation.pairs for s in (p.first, p.second)}
        candidates = [s for edge in parent.walk for s in (pair_map[edge].first, pair_map[edge].second)
                      if source_chart is None or self.sides[s].id == source_chart]
        if len(candidates) != 1:
            raise ItineraryError('ambiguous cut number; choose a side: '+', '.join(candidates))
        return candidates[0]

    def endpoint(self, endpoint):
        if isinstance(endpoint, BoundaryPoint):
            _position(endpoint.position)
            if endpoint.side not in {b.side for b in self.system.cellulation.boundaries}:
                raise ItineraryError('endpoint must name a genuine boundary side')
            chart = self.sides[endpoint.side]
            return chart, chart.point(endpoint.side, endpoint.position), endpoint
        if isinstance(endpoint, MarkPoint):
            cell = self.system.cellulation
            marks = [m for m in cell.marks if m.id == endpoint.id]
            if len(marks) != 1 or marks[0].corner is None:
                raise ItineraryError('endpoint must name a mark reached by the cut system')
            report = self.system.validate()
            full_vertex = next(v for v in report.vertices if marks[0].corner in v.corners)
            # After auxiliary gluing, a marked corner may have several equivalent
            # copies in a disk. Only boundary occurrences are valid locators.
            candidates = [s for s in full_vertex.corners if s in self.sides]
            if endpoint.corner is None:
                if len(candidates) != 1:
                    raise ItineraryError('ambiguous marked endpoint; choose a corner: '+', '.join(candidates))
                endpoint = replace(endpoint, corner=candidates[0])
            if endpoint.corner not in candidates:
                raise ItineraryError('marked endpoint corner does not represent that mark')
            chart = self.sides[endpoint.corner]
            return chart, chart.point(endpoint.corner, 0), endpoint
        raise ItineraryError('arc endpoints must be BoundaryPoint or MarkPoint')

    def route(self, route):
        if not isinstance(route.id, str) or not route.id:
            raise ItineraryError('a route needs a nonempty ID')
        crossings = tuple(route.crossings)
        if len(crossings) > 256:
            raise ItineraryError('at most 256 crossings per route are supported')
        if (route.start is None) != (route.end is None):
            raise ItineraryError('an arc needs both endpoints')
        if route.closed and not crossings:
            raise ItineraryError('an empty itinerary is not a named cut or a specified disk loop')
        if any(not isinstance(c, Crossing) for c in crossings):
            raise ItineraryError('crossings must give explicit side locators')
        seen = set()
        for crossing in crossings:
            opposite = self.cross(crossing)
            pair = self.pairs[crossing.side]
            t = crossing.position if crossing.side == pair.first else opposite.position
            for edge, position in seen:
                if edge == pair.id and abs(t-position) <= _TOL:
                    raise ItineraryError('repeated visits need distinct crossing positions on each edge')
            seen.add((pair.id, t))
        pieces = []

        def add(chart, start, end, start_locator, end_locator):
            if _distance2(start, end) <= _TOL*_TOL:
                raise ItineraryError('zero-length or ambiguous disk segment')
            if any(abs(_orient(a, b, start)) <= _TOL and abs(_orient(a, b, end)) <= _TOL
                   for a, b in zip(chart.vertices, chart.vertices[1:]+chart.vertices[:1])):
                raise ItineraryError('route follows a cut-disk boundary; give an interior itinerary')
            pieces.append(Chord(chart.id, start, end, start_locator, end_locator, route.id, len(pieces)))

        if route.closed:
            first = crossings[0]
            current = self.cross(first)
            chart = self.sides[current.side]
            point = chart.point(current.side, current.position)
            for target in crossings[1:]+crossings[:1]:
                if self.sides[target.side].id != chart.id:
                    raise ItineraryError('crossing order jumps between cut disks')
                end = chart.point(target.side, target.position)
                add(chart, point, end, current, target)
                current = self.cross(target)
                chart = self.sides[current.side]
                point = chart.point(current.side, current.position)
        else:
            chart, point, current = self.endpoint(route.start)
            for target in crossings:
                if self.sides[target.side].id != chart.id:
                    raise ItineraryError('crossing order jumps between cut disks')
                add(chart, point, chart.point(target.side, target.position), current, target)
                current = self.cross(target)
                chart = self.sides[current.side]
                point = chart.point(current.side, current.position)
            end_chart, end, endpoint = self.endpoint(route.end)
            if end_chart.id != chart.id:
                raise ItineraryError('terminal endpoint lies in a different cut disk')
            add(chart, point, end, current, endpoint)
        for i, a in enumerate(pieces):
            for b in pieces[i+1:]:
                if a.chart == b.chart and _intersection(a, b):
                    raise ItineraryError('route intersects itself inside a cut disk')
        return RoutedCurve(route, tuple(pieces))

    def family(self, routes, *, intersections=()):
        """Validate disjoint curves or exactly declared transverse chord crossings.

        Declarations are ((route_id, piece_index), (route_id, piece_index)).
        They identify actual crossings; missing, extra, tangent and coincident
        intersections are rejected. Each individual route must remain embedded.
        """
        routes = tuple(routes)
        if len(routes) > 128 or len({r.id for r in routes}) != len(routes):
            raise ItineraryError('supply at most 128 routes with distinct IDs')
        routed = tuple(self.route(r) for r in routes)
        declared = {frozenset(tuple(x) for x in pair) for pair in intersections}
        if len(declared) != len(intersections) or any(len(p) != 2 for p in declared):
            raise ItineraryError('duplicate or invalid intersection declarations')
        actual = set()
        for i, first in enumerate(routed):
            for second in routed[i+1:]:
                # Seam coincidences cannot be hidden by looking only in disks.
                for a in first.route.crossings:
                    for b in second.route.crossings:
                        pair = self.pairs[a.side]
                        if self.pairs[b.side].id == pair.id:
                            t = b.position if a.side == b.side else 1-b.position
                            if abs(a.position-t) <= _TOL:
                                raise ItineraryError('two curves coincide at a cut crossing; choose distinct positions')
                for a in first.pieces:
                    for b in second.pieces:
                        if a.chart != b.chart:
                            continue
                        kind = _intersection(a, b)
                        if kind == 'transverse':
                            actual.add(frozenset(((a.route, a.index), (b.route, b.index))))
                        elif kind:
                            raise ItineraryError('tangent/coincident disk segments are unsupported')
        if declared != actual:
            raise ItineraryError('declared intersections do not match actual disk crossings: '+str(actual))
        return routed

    def reversed(self, route):
        return replace(route, crossings=tuple(self.cross(c) for c in reversed(route.crossings)),
                       start=route.end, end=route.start)


def _position(t):
    if isinstance(t, bool) or not isinstance(t, (int, float)) or not isfinite(t) or not _TOL < t < 1-_TOL:
        raise ItineraryError('side positions must lie strictly between 0 and 1, away from vertices')


def _distance2(a, b):
    return sum((x-y)**2 for x, y in zip(a, b))


def _orient(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def _intersection(a, b):
    o = (_orient(a.start, a.end, b.start), _orient(a.start, a.end, b.end),
         _orient(b.start, b.end, a.start), _orient(b.start, b.end, a.end))
    if o[0]*o[1] < -_TOL*_TOL and o[2]*o[3] < -_TOL*_TOL and min(abs(x) for x in o) > _TOL:
        return 'transverse'
    if (max(a.start[0], a.end[0])+_TOL < min(b.start[0], b.end[0])
        or max(b.start[0], b.end[0])+_TOL < min(a.start[0], a.end[0])
        or max(a.start[1], a.end[1])+_TOL < min(b.start[1], b.end[1])
        or max(b.start[1], b.end[1])+_TOL < min(a.start[1], a.end[1])):
        return None
    if (min(o[:2]) <= _TOL and max(o[:2]) >= -_TOL
            and min(o[2:]) <= _TOL and max(o[2:]) >= -_TOL):
        return 'touch'
    return None

@dataclass(frozen=True)
class RouteTopology:
    components: tuple

    @property
    def separating(self):
        return len(self.components) > 1


def cut_along_route(atlas, route):
    """Reconstruct the surface cut along one embedded route.

    Refine all crossed sides on both partners, split each disk along its chords,
    glue the original system back, then cut only along the new route edges.
    This computes separation and residual genus without an isotopy claim.
    """
    routed = atlas.route(route)
    original = atlas.system.cellulation
    positions = {s: [] for s in atlas.sides}
    for crossing in route.crossings:
        positions[crossing.side].append(crossing.position)
        opposite = atlas.cross(crossing)
        positions[opposite.side].append(opposite.position)
    for endpoint in (route.start, route.end):
        if isinstance(endpoint, BoundaryPoint):
            positions[endpoint.side].append(endpoint.position)
    for side in positions:
        positions[side] = sorted(set(positions[side]))
    names = set(atlas.sides) | {p.id for p in original.pairs}
    def fresh(stem):
        name, i = stem, 0
        while name in names:
            i += 1
            name = stem+':'+str(i)
        names.add(name)
        return name
    fragments = {s: tuple(fresh('fragment:'+s+':'+str(i)) for i in range(len(ts)+1))
                 for s, ts in positions.items()}
    words = [tuple(f for s in c.sides for f in fragments[s]) for c in atlas.charts]
    pairs = []
    for pair in original.pairs:
        if pair.id not in original.cuts:
            continue
        a, b = fragments[pair.first], fragments[pair.second]
        if len(a) != len(b):
            raise ItineraryError('crossed seam subdivisions do not match')
        pairs.extend(SidePair(fresh('seam:'+pair.id+':'+str(i)), s, t)
                     for i, (s, t) in enumerate(zip(a, reversed(b))))
    boundaries = tuple(BoundarySide(s, item.boundary) for item in original.boundaries
                       for s in fragments[item.side])
    marks = []
    for mark in original.marks:
        endpoint = MarkPoint(mark.id, mark.corner if mark.corner in atlas.sides else None)
        _, _, resolved = atlas.endpoint(endpoint)
        marks.append(Mark(mark.id, corner=fragments[resolved.corner][0]))

    def corner(locator):
        if isinstance(locator, MarkPoint):
            return fragments[locator.corner][0]
        # A split position is the start of the next fragment in side direction.
        return fragments[locator.side][positions[locator.side].index(locator.position)+1]

    route_edges = []
    for piece in routed.pieces:
        a, b = corner(piece.start_locator), corner(piece.end_locator)
        candidates = [i for i, word in enumerate(words) if a in word and b in word]
        if len(candidates) != 1:
            raise ItineraryError('route chords cannot be embedded consistently in the refined disks')
        i = candidates[0]
        word = words.pop(i)
        start = word.index(a)
        word = word[start:]+word[:start]
        end = word.index(b)
        edge = fresh('route:'+route.id+':'+str(piece.index))
        plus, minus = fresh(edge+'+'), fresh(edge+'-')
        words.extend((word[:end]+(minus,), word[end:]+(plus,)))
        pairs.append(SidePair(edge, plus, minus))
        route_edges.append(edge)
    cell = Cellulation(tuple(Face('route-face-'+str(i), word) for i, word in enumerate(words)),
                       tuple(pairs), boundaries, tuple(marks), tuple(route_edges))
    report = validate_cut_system(cell, atlas.system.surface)
    if any(d.code not in ('residual_topology', 'interior_marks') for d in report.diagnostics) or not report.complement:
        raise ItineraryError('refined route topology failed: '+str(report.diagnostics))
    return RouteTopology(report.complement)
