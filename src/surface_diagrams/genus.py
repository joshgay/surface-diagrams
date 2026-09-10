"""Symmetric higher-genus schematics based on the thesis's lens-hole diagrams.

Closed surfaces, fixed-axis boundaries, and paired silhouette necks share the
same geometry. Boundary rims are distinct from the genus holes.
"""

from dataclasses import dataclass
from .model import _number
from .primitives import Drawing, Path, Ellipse, Text


@dataclass(frozen=True)
class TypeIBoundary:
    """A fixed boundary at slot 1..2g+2, ordered along the involution axis."""
    slot: int
    radius: float = 8

    def __post_init__(self):
        if type(self.slot) is not int or self.slot < 1:
            raise ValueError("slot must be a positive integer")
        _number(self.radius, "radius", positive=True)


@dataclass(frozen=True)
class BoundaryPair:
    """Two exchanged boundary components on upper/lower silhouette necks.

    side selects 'left', 'right', or 'top' (also 'bottom'/'top-bottom').
    position is 0..1 within that region. Both members are always generated.
    There is no count limit, but neck footprints must fit without overlap.
    """
    side: str = "top"
    position: float = .5
    radius: float = 7

    def __post_init__(self):
        if self.side not in ("left", "right", "top", "bottom", "top-bottom"):
            raise ValueError("pair side must be left, right, top, bottom, or top-bottom")
        _number(self.position, "position")
        _number(self.radius, "radius", positive=True)
        if not 0 <= self.position <= 1:
            raise ValueError("position must lie in 0..1")


@dataclass(frozen=True)
class GenusSurface:
    genus: int = 2
    handle_spacing: float = 130
    height: float = 140
    handle_style: str = "lens"
    show_axis: bool = False
    type_i: tuple = ()
    type_ii: tuple = ()

    def __post_init__(self):
        if type(self.genus) is not int or self.genus < 1:
            raise ValueError("genus must be a positive integer")
        for name in ("handle_spacing", "height"):
            _number(getattr(self, name), name, positive=True)
        if self.handle_style not in ("lens", "balloon"):
            raise ValueError("handle_style must be 'lens' or 'balloon'")
        if not isinstance(self.show_axis, bool):
            raise ValueError("show_axis must be boolean")
        object.__setattr__(self, "type_i", tuple(self.type_i))
        object.__setattr__(self, "type_ii", tuple(self.type_ii))
        if any(not isinstance(b, TypeIBoundary) for b in self.type_i):
            raise TypeError("type_i must contain TypeIBoundary objects")
        if any(not isinstance(b, BoundaryPair) for b in self.type_ii):
            raise TypeError("type_ii must contain BoundaryPair objects")
        if any(b.slot > 2*self.genus+2 for b in self.type_i):
            raise ValueError("Type I slot exceeds 2g+2")
        if len({b.slot for b in self.type_i}) != len(self.type_i):
            raise ValueError("a fixed slot can have at most one boundary")

    @property
    def width(self):
        return (self.genus + 0.7) * self.handle_spacing

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


def genus_layout(surface, style):
    spacing = surface.handle_spacing
    rx, hy = surface.width / 2, surface.height / 2
    left, right = -rx + spacing * .35, rx - spacing * .35
    base, peak = hy * .77, hy * .96
    # Cubic top silhouette, reflected in reverse order to close the underside.
    fixed = {b.slot: b.radius for b in surface.type_i}
    if any(r >= min(hy*.16, spacing*.1) for r in fixed.values()):
        raise ValueError("Type I boundary too large; increase surface height/spacing or reduce its radius")
    lr, rr = fixed.get(1, 0), fixed.get(2*surface.genus+2, 0)
    lx, rrx = -rx+lr*.4, rx-rr*.4
    top = [((lx, lr), (lx, base*.65), (left-spacing*.27, base), (left, base))]
    for i in range(surface.genus):
        x = left + i * spacing
        top.extend([
            ((x, base), (x+spacing*.18, base), (x+spacing*.32, peak), (x+spacing*.5, peak)),
            ((x+spacing*.5, peak), (x+spacing*.68, peak), (x+spacing*.82, base), (x+spacing, base)),
        ])
    top.append(((right, base), (right+spacing*.27, base), (rrx, base*.65), (rrx, rr)))
    necks = []
    for pair in surface.type_ii:
        if pair.side == "left":
            x = -rx + spacing * (.14 + .18*pair.position)
        elif pair.side == "right":
            x = rx - spacing * (.32 - .18*pair.position)
        else:
            x = left + (right-left)*(.08+.84*pair.position)
        necks.append((x, pair.radius))
    necks.sort()
    if any(x-1.4*r <= lx+lr or x+1.4*r >= rrx-rr for x, r in necks):
        raise ValueError("boundary pair too close to an end; reduce radius or move it inward")
    if any(b-a <= 1.4*(ra+rb) for (a, ra), (b, rb) in zip(necks, necks[1:])):
        raise ValueError("boundary necks overlap; spread them out or reduce their radii")
    contour_parts, rims = _neck_contour(top, necks)
    paths, ellipses = [], []
    for commands in contour_parts:
        for sign in (1, -1):
            mirrored = tuple((op, *(v if i % 2 == 0 else sign*v for i, v in enumerate(values)))
                             for op, *values in commands)
            paths.append(Path(mirrored, style.outline_color, style.outline_width, "surface-outline"))
    for x, y, radius in rims:
        for sign in (1, -1):
            ellipses.append(Ellipse(x, sign*y, radius, radius*.32, "none", style.outline_color,
                                    style.outline_width, "type-ii-boundary"))
    for x, r in ((lx, lr), (rrx, rr)):
        if r:
            ellipses.append(Ellipse(x, 0, r*.4, r, "none", style.outline_color, style.outline_width, "type-i-boundary"))
    centers = [left + (i+.5)*spacing for i in range(surface.genus)]
    hr, hh = spacing*.24, hy*.22
    for index, x in enumerate(centers):
        rleft, rright = fixed.get(2*index+2, 0), fixed.get(2*index+3, 0)
        for sign in (1, -1):
            commands = (("M", x-hr, sign*rleft),
                        ("C", x-hr*.55, sign*hh, x+hr*.55, sign*hh, x+hr, sign*rright))
            paths.append(Path(commands, style.outline_color, style.outline_width, "handle"))
        for bx, br in ((x-hr, rleft), (x+hr, rright)):
            if br:
                ellipses.append(Ellipse(bx, 0, br*.4, br, "none", style.outline_color, style.outline_width, "type-i-boundary"))
        if surface.handle_style == "balloon" and not (rleft or rright):
            paths.append(Path((("M", x-hr*1.13, -hh*.25),
                               ("C", x-hr*.8, -hh*1.6, x+hr*.8, -hh*1.6, x+hr*1.13, -hh*.25)),
                              style.outline_color, style.outline_width*.7, "handle-back"))
    if surface.show_axis:
        paths.insert(0, Path((("M", -rx-6, 0), ("L", rx+6, 0)), "#999999", .7, "involution-axis", True))
    pad = style.padding + style.outline_width/2 + 6
    extent = max([hy] + [y+r*.32 for _, y, r in rims])
    return Drawing(surface.width+2*pad, 2*extent+2*pad, tuple(ellipses), tuple(paths))


def _split(cubic, t):
    def mix(a, b):
        return tuple((1-t)*x+t*y for x, y in zip(a, b))
    a, b, c, d = cubic
    ab, bc, cd = mix(a,b), mix(b,c), mix(c,d)
    abc, bcd = mix(ab,bc), mix(bc,cd)
    mid = mix(abc,bcd)
    return (a,ab,abc,mid), (mid,bcd,cd,d)


def _at_x(cubic, x):
    lo, hi = 0., 1.
    for _ in range(45):
        t = (lo+hi)/2
        if _split(cubic,t)[0][-1][0] < x:
            lo = t
        else:
            hi = t
    return (lo+hi)/2


def _trim(chain, low, high):
    result = []
    for cubic in chain:
        if cubic[-1][0] <= low or cubic[0][0] >= high:
            continue
        if high < cubic[-1][0]:
            cubic = _split(cubic, _at_x(cubic, high))[0]
        if low > cubic[0][0]:
            cubic = _split(cubic, _at_x(cubic, low))[1]
        result.append(cubic)
    return result


def _neck_contour(chain, necks):
    """Cut true silhouette openings and join each to an elliptical rim.

    Cubics are split geometrically, not hidden with white paint, so export
    remains transparent and a future backend receives identical geometry.
    """
    cursor = chain[0][0][0]
    commands = [("M", *chain[0][0])]
    parts, rims = [], []
    for x, radius in necks:
        a, b = x-radius*1.4, x+radius*1.4
        before = _trim(chain, cursor, a)
        after = _trim(chain, b, chain[-1][-1][0])
        for _, c1, c2, end in before:
            commands.append(("C", *c1, *c2, *end))
        ya, yb = before[-1][-1][1], after[0][0][1]
        y = max(ya,yb) + 1.7*radius
        commands.append(("C", a, ya+radius, x-radius, y-radius*.7, x-radius, y))
        parts.append(tuple(commands))
        commands = [("M", x+radius, y), ("C", x+radius, y-radius*.7, b, yb+radius, b, yb)]
        rims.append((x, y, radius))
        cursor = b
    for _, c1, c2, end in _trim(chain, cursor, chain[-1][-1][0]):
        commands.append(("C", *c1, *c2, *end))
    parts.append(tuple(commands))
    return parts, rims
