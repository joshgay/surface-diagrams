"""Small immutable inputs; no output-format or algebra dependencies."""

from dataclasses import dataclass, replace
from math import isfinite
from typing import Optional, Tuple


def _number(value, name, positive=False):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{name} must be a finite number")
    if not isfinite(value) or (positive and value <= 0):
        raise ValueError(f"{name} must be {'positive and ' if positive else ''}finite")


def _point_check(point):
    _number(point.x, "x")
    _number(point.y, "y")
    if point.radius is not None:
        _number(point.radius, "radius", positive=True)


@dataclass(frozen=True)
class Boundary:
    """An inner boundary shown as a gray dot. Radius is in drawing units."""

    x: float
    y: float = 0
    radius: Optional[float] = None

    def __post_init__(self):
        _point_check(self)


@dataclass(frozen=True)
class MarkedPoint:
    """A marked point shown as a blue dot."""

    x: float
    y: float = 0
    radius: Optional[float] = None

    def __post_init__(self):
        _point_check(self)


@dataclass(frozen=True)
class Style:
    """Thesis conventions; dimensions and dot radii use drawing units.

    A transparent background fits both white paper and other documents.
    Individual objects can override the two default dot radii.
    """

    boundary_radius: float = 4
    marked_point_radius: float = 4
    boundary_color: str = "#8b8b8b"
    marked_point_color: str = "#006fff"
    outline_color: str = "#000000"
    outline_width: float = 1.5
    background: Optional[str] = None
    padding: float = 12
    show_outer_ellipse: bool = True
    curve_color: str = "#ff00d4"
    curve_width: float = 2
    curve_height: float = 0.85
    show_guides: bool = False

    def __post_init__(self):
        for name in ("boundary_radius", "marked_point_radius", "outline_width", "curve_width", "curve_height"):
            _number(getattr(self, name), name, positive=True)
        _number(self.padding, "padding")
        if self.padding < 0:
            raise ValueError("padding must be nonnegative")
        if not isinstance(self.show_outer_ellipse, bool):
            raise ValueError("show_outer_ellipse must be a boolean")
        if not isinstance(self.show_guides, bool) or self.curve_height > 1:
            raise ValueError("show_guides must be boolean and curve_height must be at most 1")
        # Restrict paint values to literals: no URLs, CSS injection, or resources.
        import re
        for name in ("boundary_color", "marked_point_color", "outline_color", "background", "curve_color"):
            value = getattr(self, name)
            if value is None and name == "background":
                continue
            if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?", value):
                raise ValueError(f"{name} must be a #RGB or #RRGGBB color")


@dataclass(frozen=True)
class PlanarSurface:
    """An ellipse centered at (0, 0), with freely positioned interior objects.

    Width and height describe the ellipse, excluding export padding.
    Hiding its outline does not change coordinates or crop the image.
    """

    objects: Tuple[object, ...] = ()
    width: float = 240
    height: float = 100
    curves: Tuple[object, ...] = ()

    def __post_init__(self):
        _number(self.width, "width", positive=True)
        _number(self.height, "height", positive=True)
        object.__setattr__(self, "objects", tuple(self.objects))
        from .curves import Arc, Loop
        object.__setattr__(self, "curves", tuple(self.curves))
        if any(not isinstance(curve, (Arc, Loop)) for curve in self.curves):
            raise TypeError("curves must contain Arc or Loop instances")
        for item in self.objects:
            if not isinstance(item, (Boundary, MarkedPoint)):
                raise TypeError("objects must contain Boundary or MarkedPoint instances")
            if (item.x / (self.width / 2)) ** 2 + (item.y / (self.height / 2)) ** 2 >= 1:
                raise ValueError("every object's center must lie strictly inside the ellipse")

    @classmethod
    def row(cls, pattern="", *, spacing=36, height=80, margin=30):
        """Place B (boundary) and P (marked point) objects left to right.

        Example: PlanarSurface.row("B P B P P"). Whitespace is ignored.
        An empty pattern makes an empty disk. Margin is measured from the
        outermost dot center to the horizontal tip of the ellipse.
        """
        if not isinstance(pattern, str):
            raise TypeError("pattern must be a string containing B and P")
        _number(spacing, "spacing", positive=True)
        _number(margin, "margin", positive=True)
        letters = "".join(pattern.upper().split())
        if any(letter not in "BP" for letter in letters):
            raise ValueError("row pattern accepts only B (boundary), P (point), and whitespace")
        span = max(0, len(letters) - 1) * spacing
        objects = tuple(
            (Boundary if letter == "B" else MarkedPoint)(index * spacing - span / 2)
            for index, letter in enumerate(letters)
        )
        return cls(objects, width=span + 2 * margin, height=height)

    def with_curves(self, *curves):
        """Return a new surface with the supplied arcs/loops appended."""
        return replace(self, curves=self.curves + tuple(curves))

    def _repr_svg_(self):
        """Display directly in Jupyter using the default style."""
        from .svg import render_svg
        return render_svg(self)
