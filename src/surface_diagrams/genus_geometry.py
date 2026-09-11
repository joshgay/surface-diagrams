"""Reusable 2-D presentation geometry for the default D3/D2A/E2 surface style.

Rims retain stable IDs, orientation, and a designated hidden half. All visible
output uses existing M/L/C primitives, so exporters do not infer visibility.
This presentation is not yet a cellulation or a certified cut system.
"""

from dataclasses import dataclass
from .primitives import Drawing, Path

_KAPPA = 0.5522847498307936
_FOOTPRINT = 1.2


def _transform(commands, transform):
    return tuple((op, *(z for i in range(0, len(v), 2)
                        for z in transform(v[i], v[i+1])))
                 for op, *v in commands)


@dataclass(frozen=True)
class Rim:
    id: str
    role: str
    x: float
    y: float
    radius: float
    tangent: tuple
    normal: tuple
    hidden_inner: bool

    @property
    def depth(self):
        return self.radius * .25

    def point(self, u, v):
        return (self.x + u*self.tangent[0] + v*self.normal[0],
                self.y + u*self.tangent[1] + v*self.normal[1])

    @property
    def anchors(self):
        return self.point(-self.radius, 0), self.point(self.radius, 0)

    @property
    def extents(self):
        return (abs(self.x) + abs(self.tangent[0])*self.radius + abs(self.normal[0])*self.depth,
                abs(self.y) + abs(self.tangent[1])*self.radius + abs(self.normal[1])*self.depth)

    def half(self, sign):
        # Two quarter-ellipse cubics; endpoints are exact collar attachments.
        r, d, k = self.radius, self.depth*sign, _KAPPA
        commands = (("M", -r, 0), ("C", -r, k*d, -k*r, d, 0, d),
                    ("C", k*r, d, r, k*d, r, 0))
        return _transform(commands, self.point)


@dataclass(frozen=True)
class Presentation:
    width: float
    height: float
    contours: tuple
    handles: tuple
    back_handles: tuple
    rims: tuple
    show_axis: bool

    def drawing(self, style):
        if any(r.depth*2 <= style.outline_width for r in self.rims):
            raise ValueError("boundary rim too small for outline width; use thinner outlines or larger spacing")
        paths = []
        if self.show_axis:
            paths.append(Path((("M", -self.width/2-6, 0), ("L", self.width/2+6, 0)),
                              "#999999", .7, "involution-axis", True))
        for commands in self.contours:
            paths.append(Path(commands, style.outline_color, style.outline_width, "surface-outline"))
        for commands in self.handles:
            paths.append(Path(commands, style.outline_color, style.outline_width, "handle"))
        for commands in self.back_handles:
            paths.append(Path(commands, style.outline_color, style.outline_width*.7, "handle-back"))
        for rim in self.rims:
            for sign in (1, -1):
                hidden = sign == -1 and rim.hidden_inner
                paths.append(Path(rim.half(sign), style.outline_color,
                                  style.outline_width*(.7 if hidden else 1),
                                  rim.role, hidden))
        pad = style.padding + style.outline_width/2 + 6
        ex = max([self.width/2] + [r.extents[0] for r in self.rims])
        ey = max([self.height/2] + [r.extents[1] for r in self.rims])
        return Drawing(2*(ex+pad), 2*(ey+pad), (), tuple(paths))


def _region(pair):
    return pair.side if pair.side in ("left", "right") else "top"


def _placements(surface, region, low, high):
    entries = [(i, p) for i, p in enumerate(surface.type_ii) if _region(p) == region]
    count = len(entries)
    positions = []
    for j, (index, pair) in enumerate(entries):
        fraction = (j+.5)/count if pair.position is None else .08 + .84*pair.position
        positions.append((low+(high-low)*fraction, index, pair))
    positions.sort()
    result = []
    for j, (x, index, pair) in enumerate(positions):
        if pair.radius is None:
            natural = min(surface.handle_spacing*.20, surface.height*.22)
            clearance = min(x-low, high-x)
            if j:
                clearance = min(clearance, (x-positions[j-1][0])/2)
            if j+1 < count:
                clearance = min(clearance, (positions[j+1][0]-x)/2)
            radius = min(natural, clearance*.75)
        else:
            radius = pair.radius
        if radius <= 0 or x-_FOOTPRINT*radius <= low or x+_FOOTPRINT*radius >= high:
            raise ValueError("boundary pair cannot fit in its region; spread positions or reduce radius")
        result.append((x, radius, index))
    if any(b-a <= _FOOTPRINT*(ra+rb) for (a, ra, _), (b, rb, _) in zip(result, result[1:])):
        raise ValueError("boundary necks overlap; spread them out or reduce their radii")
    return result


def presentation(surface):
    spacing, hy = surface.handle_spacing, surface.height/2
    rx = surface.width/2
    left, right = -surface.genus*spacing/2, surface.genus*spacing/2
    base = hy*.88
    fixed = {}
    for boundary in surface.type_i:
        outer = boundary.slot in (1, 2*surface.genus+2)
        radius = boundary.radius
        if radius is None:
            radius = min(hy*(.50 if outer else .24), spacing*(.25 if outer else .12))
        limit = min(hy*(.65 if outer else .33), spacing*(.30 if outer else .14))
        if radius >= limit:
            raise ValueError("Type I boundary too large; increase height/spacing or reduce radius")
        fixed[boundary.slot] = radius
    lr, rr = fixed.get(1, 0), fixed.get(2*surface.genus+2, 0)
    # Smooth sides and an almost flat top, with no scalloping at each handle.
    # Side charts use u=y and outward v=+/-x, so collars open sideways.
    left_chain = [((lr, rx), (hy*.7, rx), (base, -left+spacing*.22), (base, -left))]
    right_chain = [((rr, rx), (hy*.7, rx), (base, right+spacing*.22), (base, right))]
    top_chain = [((left, base), (left+(right-left)/3, base*.99),
                  (right-(right-left)/3, base*.99), (right, base))]
    contours, rims = [], []
    for region, chain, transform, tangent, normal in (
        ("left", left_chain, lambda u,v: (-v,u), (0,1), (-1,0)),
        ("top", top_chain, lambda u,v: (u,v), (1,0), (0,1)),
        ("right", right_chain, lambda u,v: (v,u), (0,1), (1,0)),
    ):
        low, high = chain[0][0][0], chain[-1][-1][0]
        necks = _placements(surface, region, low, high)
        parts, attachments = _neck_contour(chain, necks)
        for commands in parts:
            upper = _transform(commands, transform)
            contours.extend((upper, _transform(upper, lambda x,y: (x,-y))))
        for u, v, radius, index in attachments:
            x, y = transform(u, v)
            # Fixed viewing convention follows the references: inward halves
            # of upper and left-facing rims are hidden, lower/right openings
            # expose the full rim. Reflection changes geometry, not this view.
            for sign, suffix in ((1,"upper"), (-1,"lower")):
                rims.append(Rim(f"pair-{index+1}-{suffix}", "type-ii-boundary",
                                x, sign*y, radius, (tangent[0],sign*tangent[1]),
                                (normal[0],sign*normal[1]),
                                region == "left" or (region == "top" and sign == 1)))
    for slot, x, radius, normal in ((1, -rx, lr, (-1,0)),
                                   (2*surface.genus+2, rx, rr, (1,0))):
        if radius:
            rims.append(Rim(f"fixed-{slot}", "type-i-boundary", x, 0, radius,
                            (0,1), normal, normal[0] < 0))
    handles, back_handles = [], []
    hr, hh = spacing*.30, hy*.27
    for index in range(surface.genus):
        x = left+(index+.5)*spacing
        rleft, rright = fixed.get(2*index+2, 0), fixed.get(2*index+3, 0)
        for sign in (1,-1):
            handles.append((("M", x-hr, sign*rleft),
                            ("C", x-hr*.52, sign*hh, x+hr*.52, sign*hh, x+hr, sign*rright)))
        for slot, bx, br, normal in ((2*index+2, x-hr, rleft, (1,0)),
                                     (2*index+3, x+hr, rright, (-1,0))):
            if br:
                rims.append(Rim(f"fixed-{slot}", "type-i-boundary", bx, 0, br,
                                (0,1), normal, normal[0] < 0))
        if surface.handle_style == "balloon" and not (rleft or rright):
            back_handles.append((("M", x-hr*1.06, -hh*.12),
                                 ("C", x-hr*.70, -hh*1.65, x+hr*.70, -hh*1.65, x+hr*1.06, -hh*.12)))
    return Presentation(surface.width, surface.height, tuple(contours), tuple(handles),
                        tuple(back_handles), tuple(rims), surface.show_axis)


def _split(cubic, t):
    def mix(a, b):
        return tuple((1-t)*x+t*y for x,y in zip(a,b))
    a,b,c,d = cubic
    ab,bc,cd = mix(a,b),mix(b,c),mix(c,d)
    abc,bcd = mix(ab,bc),mix(bc,cd)
    mid = mix(abc,bcd)
    return (a,ab,abc,mid),(mid,bcd,cd,d)


def _at_x(cubic, x):
    lo,hi = 0.,1.
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
    """Split a monotone contour and join each true opening to its rim."""
    cursor = chain[0][0][0]
    commands = [("M", *chain[0][0])]
    parts, rims = [], []
    for x,radius,index in necks:
        a,b = x-radius*_FOOTPRINT, x+radius*_FOOTPRINT
        before = _trim(chain,cursor,a)
        after = _trim(chain,b,chain[-1][-1][0])
        for _,c1,c2,end in before:
            commands.append(("C", *c1,*c2,*end))
        ya,yb = before[-1][-1][1],after[0][0][1]
        y = max(ya,yb)+.45*radius
        # Match the existing contour tangent at each cut. The other end is
        # tangent to the collar axis, so there is no kink at the rim anchor.
        end_control = before[-1][-2]
        start_control = after[0][1]
        slope_a = (ya-end_control[1])/(a-end_control[0])
        slope_b = (start_control[1]-yb)/(start_control[0]-b)
        step = (_FOOTPRINT-1)*radius*.65
        commands.append(("C", a+step,ya+slope_a*step, x-radius,y-radius*.25, x-radius,y))
        parts.append(tuple(commands))
        commands = [("M",x+radius,y), ("C",x+radius,y-radius*.25,b-step,yb-slope_b*step,b,yb)]
        rims.append((x,y,radius,index))
        cursor=b
    for _,c1,c2,end in _trim(chain,cursor,chain[-1][-1][0]):
        commands.append(("C",*c1,*c2,*end))
    parts.append(tuple(commands))
    return parts,rims
