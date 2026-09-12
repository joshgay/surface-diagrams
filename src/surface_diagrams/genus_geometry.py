"""Reusable 2-D presentation geometry for the default D3/D2A/E2 surface style.

Rims retain stable IDs, orientation, and a designated hidden half. All visible
output uses existing M/L/C primitives, so exporters do not infer visibility.
This presentation is not yet a cellulation or a certified cut system.
"""

from dataclasses import dataclass
from .primitives import Drawing, Path

_KAPPA = 0.5522847498307936
_FOOTPRINT = 1.32


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
    rims: tuple
    show_axis: bool
    view_vertical: str
    view_horizontal: str

    def faces_viewer(self, normal):
        """Shared visibility convention for rims and future projected curves."""
        vx = 1 if self.view_horizontal == "right" else -1
        vy = 1 if self.view_vertical == "above" else -1
        return normal[0]*vx + normal[1]*vy > 0

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
        if (pair.position is None and region == "top" and count == 2
                and any(p.side in ("left", "right") for p in surface.type_ii)):
            fraction = .16 + .68*j
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
            radius = min(natural, clearance*.70)
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
    vx = 1 if surface.view_horizontal == "right" else -1
    vy = 1 if surface.view_vertical == "above" else -1
    def hidden(normal):
        return normal[0]*vx + normal[1]*vy < 0
    # Smooth sides and an almost flat top, with no scalloping at each handle.
    # Side charts use u=y and outward v=+/-x, so collars open sideways.
    def side_chain(radius, end):
        if radius:
            # The rim has a short horizontal neck before flaring into the body.
            return [((radius, rx), (radius, rx-spacing*.17),
                     (base, end+spacing*.19), (base, end))]
        return [((0, rx), (hy*.48, rx),
                 (base, end+spacing*.20), (base, end))]
    left_chain = side_chain(lr, -left)
    right_chain = side_chain(rr, right)
    top_chain = [((left, base), (left+(right-left)/3, base*.99),
                  (right-(right-left)/3, base*.99), (right, base))]
    contours, rims = [], []
    has_top = any(_region(p) == "top" for p in surface.type_ii)
    direct_ends = {side: has_top and not any(_region(p) == side for p in surface.type_ii)
                   for side in ("left", "right")}
    end_x = {"left": -rx, "right": rx}
    if has_top:
        top_necks = _placements(surface, "top", left, right)
        a,ra,_ = top_necks[0]
        b,rb,_ = top_necks[-1]
        direct_ends["left"] &= a-ra < left+spacing*.31
        direct_ends["right"] &= b+rb > right-spacing*.31
        if direct_ends["left"]:
            end_x["left"] = a-ra-spacing*.20
        if direct_ends["right"]:
            end_x["right"] = b+rb+spacing*.20
    for region, chain, transform, tangent, normal in (
        ("left", left_chain, lambda u,v: (-v,u), (0,1), (-1,0)),
        ("top", top_chain, lambda u,v: (u,v), (1,0), (0,1)),
        ("right", right_chain, lambda u,v: (v,u), (0,1), (1,0)),
    ):
        if direct_ends.get(region, False):
            continue
        entries = [(i,p) for i,p in enumerate(surface.type_ii) if _region(p) == region]
        if (region in ("left", "right") and len(entries) == 1
                and entries[0][1].position is None and chain[0][0][0] == 0):
            # A side pair straddles the body's shoulder, not a tiny slot in it.
            # This permits the broad end openings and deep middle recess in E2.
            index, pair = entries[0]
            radius = min(spacing*.26, hy*.36) if pair.radius is None else pair.radius
            center = hy*.68
            if radius >= center*.85:
                raise ValueError("boundary pair cannot fit in its region; reduce radius")
            inner, outer = center-radius, center+radius
            end = chain[-1][-1][1]
            parts = [(("M", 0, rx-spacing*.16),
                      ("C", inner*_KAPPA, rx-spacing*.16,
                       inner, rx-spacing*.16*_KAPPA, inner, rx)),
                     (("M", outer, rx),
                      ("C", outer, rx-spacing*.18, base, end+spacing*.18, base, end))]
            attachments = [(center, rx, radius, index)]
        else:
            low, high = chain[0][0][0], chain[-1][-1][0]
            necks = _placements(surface, region, low, high)
            parts, attachments = _neck_contour(chain, necks)
        if region == "top" and attachments:
            if direct_ends["left"]:
                u,v,r,_ = attachments[0]
                tip = end_x["left"]
                control = (tip+spacing*.12, lr) if lr else (tip, hy*.36)
                parts[0] = (("M", tip, lr),
                            ("C", *control, u-r, v-hy*.34, u-r, v))
            if direct_ends["right"]:
                u,v,r,_ = attachments[-1]
                tip = end_x["right"]
                control = (tip-spacing*.12, rr) if rr else (tip, hy*.36)
                parts[-1] = (("M", u+r, v),
                             ("C", u+r, v-hy*.34, *control, tip, rr))
        for commands in parts:
            upper = _transform(commands, transform)
            contours.extend((upper, _transform(upper, lambda x,y: (x,-y))))
        for u, v, radius, index in attachments:
            x, y = transform(u, v)
            for sign, suffix in ((1,"upper"), (-1,"lower")):
                outward = (normal[0],sign*normal[1])
                rims.append(Rim(f"pair-{index+1}-{suffix}", "type-ii-boundary",
                                x, sign*y, radius, (tangent[0],sign*tangent[1]),
                                outward, hidden(outward)))
    for slot, x, radius, normal in ((1, end_x["left"], lr, (-1,0)),
                                   (2*surface.genus+2, end_x["right"], rr, (1,0))):
        if radius:
            rims.append(Rim(f"fixed-{slot}", "type-i-boundary", x, 0, radius,
                            (0,1), normal, hidden(normal)))
    handles = []
    hr, hh = spacing*.30, min(hy*.22, spacing*.13)
    for index in range(surface.genus):
        x = left+(index+.5)*spacing
        rleft, rright = fixed.get(2*index+2, 0), fixed.get(2*index+3, 0)
        # The near edge extends beyond the far edge, whose endpoints terminate
        # on it. Trimming geometry (rather than painting white) keeps the
        # occlusion correct on transparent and colored backgrounds.
        near = ((x-hr, vy*rleft if rleft else -vy*hh*.20),
                (x-hr*.70, vy*hh*1.4), (x+hr*.70, vy*hh*1.4),
                (x+hr, vy*rright if rright else -vy*hh*.20))
        a = (x-hr, -vy*rleft) if rleft else _split(near, .085+.02*vx)[0][-1]
        b = (x+hr, -vy*rright) if rright else _split(near, .915+.02*vx)[0][-1]
        far = (a, (x-hr*.50, -vy*hh*1.1), (x+hr*.50, -vy*hh*1.1), b)
        handles.extend((("M", *c[0]), ("C", *c[1], *c[2], *c[3])) for c in (near, far))
        for slot, bx, br, normal in ((2*index+2, x-hr, rleft, (1,0)),
                                     (2*index+3, x+hr, rright, (-1,0))):
            if br:
                rims.append(Rim(f"fixed-{slot}", "type-i-boundary", bx, 0, br,
                                (0,1), normal, hidden(normal)))
    return Presentation(surface.width, surface.height, tuple(contours), tuple(handles),
                        tuple(rims), surface.show_axis,
                        surface.view_vertical, surface.view_horizontal)


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
        y = max(ya,yb)+.52*radius
        # Match the existing contour tangent at each cut. The other end is
        # tangent to the collar axis, so there is no kink at the rim anchor.
        end_control = before[-1][-2]
        start_control = after[0][1]
        slope_a = (ya-end_control[1])/(a-end_control[0])
        slope_b = (start_control[1]-yb)/(start_control[0]-b)
        step = (_FOOTPRINT-1)*radius*.90
        commands.append(("C", a+step,ya+slope_a*step, x-radius,y-radius*.25, x-radius,y))
        parts.append(tuple(commands))
        commands = [("M",x+radius,y), ("C",x+radius,y-radius*.25,b-step,yb-slope_b*step,b,yb)]
        rims.append((x,y,radius,index))
        cursor=b
    for _,c1,c2,end in _trim(chain,cursor,chain[-1][-1][0]):
        commands.append(("C",*c1,*c2,*end))
    parts.append(tuple(commands))
    return parts,rims
