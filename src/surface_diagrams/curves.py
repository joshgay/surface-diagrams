"""Minimal cut-interval itineraries, with ordered crossings retained exactly.

This is the convention from the user's legacy DrawPlanarArcs.py. It is not
advertised as a complete implementation of any named Thurston coordinate system.
"""

from dataclasses import dataclass
from itertools import permutations
from math import cos, sin, pi, sqrt

from .primitives import Path, Text


def _integer(value, name):
    if type(value) is not int or value < 0:
        raise ValueError(f"{name} must be a nonnegative integer")


def _validate_common(curve):
    object.__setattr__(curve, "cuts", tuple(curve.cuts))
    for cut in curve.cuts:
        _integer(cut, "cut")
    if not isinstance(curve.start_up, bool):
        raise ValueError("start_up must be boolean")
    if len(curve.cuts) > 64:
        raise ValueError("at most 64 cut visits are supported per curve")
    if any(a == b for a, b in zip(curve.cuts, curve.cuts[1:])):
        raise ValueError("consecutive equal cuts are nonminimal")


@dataclass(frozen=True)
class Arc:
    """Arc(start, end, cuts=(), start_up=True).

    Objects are numbered 1..n by x position; 0 and n+1 mean the outer ellipse
    tips. Cut i is the open interval between objects i and i+1. The first
    segment is above the axis when start_up=True; every cut changes sides.
    """
    start: int
    end: int
    cuts: tuple = ()
    start_up: bool = True

    def __post_init__(self):
        _validate_common(self)
        _integer(self.start, "start")
        _integer(self.end, "end")
        if self.start == self.end:
            raise ValueError("an arc needs distinct endpoints; use Loop for a closed curve")
        if self.cuts and (self.cuts[0] in (self.start - 1, self.start)
                          or self.cuts[-1] in (self.end - 1, self.end)):
            raise ValueError("a terminal cut adjacent to its endpoint is nonminimal")


@dataclass(frozen=True)
class Loop:
    """A closed itinerary. Start at cuts[0], then travel above/below the axis.

    There must be a positive even number of crossings, and the final cut
    must differ from the first. Loop((i-1,j)) surrounds consecutive objects
    i..j. Reversing all traversal directions changes no unoriented picture.
    """
    cuts: tuple
    start_up: bool = True

    def __post_init__(self):
        _validate_common(self)
        if len(self.cuts) < 2 or len(self.cuts) % 2:
            raise ValueError("a loop needs a positive even number of cut visits")
        if self.cuts[-1] == self.cuts[0]:
            raise ValueError("equal first and last cuts form a cyclic cancellation")


class RoutingError(ValueError):
    """The supplied itinerary or requested spacing could not be rendered safely."""


@dataclass(frozen=True)
class HalfEllipse:
    start: float
    end: float
    up: bool
    aspect: float
    owner: int
    start_node: int
    end_node: int

    def point(self, t):
        middle = (self.start + self.end) / 2
        radius = abs(self.end - self.start) / 2
        direction = 1 if self.end > self.start else -1
        return (middle - direction * radius * cos(pi * t),
                (1 if self.up else -1) * radius * self.aspect * sin(pi * t))


def _conflict(a, b):
    """Exact combinatorial obstruction for chords in the same half-plane."""
    if a[2] != b[2]:
        return False
    l, r = sorted(a[:2]); s, t = sorted(b[:2])
    return (l < s < r < t or s < l < t < r or (l == s and r == t))


def route(surface, style, *, max_states=20000):
    """Return half-ellipses preserving every crossing of every itinerary.

    Adapted from the legacy renderer's node-slot search. Visits to the same
    cut get distinct ordered positions, shared across the upper/lower sides.
    Endpoints are never reconnected and itineraries are never simplified.
    Search is lazy and bounded (including permutations rejected early).

    Noninterleaving intervals are disjoint or nested. Semicircles over nested
    diameters are disjoint; the common vertical scaling preserves this.
    Thus accepted routes cannot cross geometrically, without a sampling claim.
    """
    objects = sorted(surface.objects, key=lambda p: p.x)
    if any(p.y != 0 for p in objects) or any(a.x == b.x for a, b in zip(objects, objects[1:])):
        raise RoutingError("cut coordinates require distinct object positions on y=0")
    n = len(objects)
    xs = [-surface.width / 2] + [p.x for p in objects] + [surface.width / 2]
    radii = [0] + [p.radius if p.radius is not None else (
        style.boundary_radius if type(p).__name__ == "Boundary" else style.marked_point_radius
    ) for p in objects] + [0]
    groups, fixed, edges, owners = {}, {}, [], []
    node_count = 0
    for owner, curve in enumerate(surface.curves):
        if any(cut > n for cut in curve.cuts):
            raise ValueError(f"cuts must lie in 0..{n}")
        if isinstance(curve, Arc) and max(curve.start, curve.end) > n + 1:
            raise ValueError(f"arc endpoints must lie in 0..{n+1}")
        nodes = []
        if isinstance(curve, Arc):
            fixed[node_count] = xs[curve.start]; nodes.append(node_count); node_count += 1
        for cut in curve.cuts:
            groups.setdefault(cut, []).append(node_count)
            nodes.append(node_count); node_count += 1
        if isinstance(curve, Arc):
            fixed[node_count] = xs[curve.end]; nodes.append(node_count); node_count += 1
        pairs = list(zip(nodes, nodes[1:]))
        if isinstance(curve, Loop):
            pairs.append((nodes[-1], nodes[0]))
        for index, (a, b) in enumerate(pairs):
            edges.append((a, b, curve.start_up if index % 2 == 0 else not curve.start_up))
            owners.append(owner)
    if node_count > 128:
        raise RoutingError("a diagram supports at most 128 route nodes; split it into panels")
    # More constrained groups first; keep ordering deterministic.
    ordered = sorted(groups.items(), key=lambda pair: (-len(pair[1]), pair[0]))
    slots = {}
    for cut, nodes in ordered:
        left = xs[cut] + radii[cut] + style.curve_width
        right = xs[cut + 1] - radii[cut + 1] - style.curve_width
        if right - left < (len(nodes) + 1) * style.curve_width:
            raise RoutingError("too many visits in a cut interval; increase point spacing or reduce dot/curve sizes")
        slots[cut] = [left + (right - left) * (i + 1) / (len(nodes) + 1) for i in range(len(nodes))]
    states = 0
    def valid_partial(positions):
        realized = [(positions[a], positions[b], up) for a, b, up in edges if a in positions and b in positions]
        return all(not _conflict(a, b) for i, a in enumerate(realized) for b in realized[i+1:])
    def solve(index, positions):
        nonlocal states
        if not valid_partial(positions):
            return None
        if index == len(ordered):
            return dict(positions)
        cut, nodes = ordered[index]
        for order in permutations(nodes):
            states += 1
            if states > max_states:
                raise RoutingError("route ordering search limit reached; this does not prove the curve impossible")
            positions.update(zip(order, slots[cut]))
            result = solve(index + 1, positions)
            if result is not None:
                return result
            for node in nodes:
                del positions[node]
        return None
    positions = solve(0, dict(fixed))
    if positions is None:
        raise RoutingError("no noncrossing ordering realizes these itineraries together")
    aspect = surface.height / surface.width * style.curve_height
    segments = tuple(HalfEllipse(positions[a], positions[b], up, aspect, owner, a, b)
                     for (a, b, up), owner in zip(edges, owners))
    # Protect unrelated dots using the analytic minimum distance from an
    # axis point to a half ellipse (a quadratic in cos(theta)).
    for segment in segments:
        for point, dot_radius in zip(objects, radii[1:-1]):
            if point.x in (segment.start, segment.end):
                continue
            if _axis_distance(segment, point.x) <= dot_radius + style.curve_width / 2:
                raise RoutingError("curve clearance is too small near a dot; increase ellipse height or reduce dot/curve sizes")
    return segments


def _axis_distance(segment, x):
    radius = abs(segment.end-segment.start)/2
    d = (segment.start+segment.end)/2-x
    best = min((d-radius)**2, (d+radius)**2)
    coefficient = radius**2 * (1-segment.aspect**2)
    if coefficient > 0:
        z = -d*radius/coefficient
        if -1 < z < 1:
            best = min(best, (d+radius*z)**2 + (radius*segment.aspect)**2*(1-z*z))
    return sqrt(max(0, best))


def curve_primitives(surface, style):
    segments = route(surface, style) if surface.curves else ()
    paths = []
    for owner, curve in enumerate(surface.curves):
        pieces = [p for p in segments if p.owner == owner]
        commands = [("M", pieces[0].start, 0)]
        for p in pieces:
            radius = abs(p.end - p.start) / 2
            # Mathematical sweep is reversed by the SVG serializer's y flip.
            sweep = int((p.end < p.start) == p.up)
            commands.append(("A", radius, radius * p.aspect, 0, 0, sweep, p.end, 0))
        if isinstance(curve, Loop):
            commands.append(("Z",))
        paths.append(Path(tuple(commands), style.curve_color, style.curve_width,
                          "closed-curve" if isinstance(curve, Loop) else "arc"))
    texts = []
    if style.show_guides:
        xs = [-surface.width/2] + sorted(p.x for p in surface.objects) + [surface.width/2]
        paths.insert(0, Path((("M", xs[0], 0), ("L", xs[-1], 0)), "#aaaaaa", 0.6, "axis", True))
        for i, (a, b) in enumerate(zip(xs, xs[1:])):
            texts.append(Text((a+b)/2, -12, str(i)))
        for i, x in enumerate(xs[1:-1], 1):
            texts.append(Text(x, 10, str(i), "#333333"))
    return tuple(paths), tuple(texts)
