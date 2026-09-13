"""Default hyperelliptic surface presentation, following the D3/D2A/E2 figures.

Boundary topology and user inputs live here; genus_geometry holds the reusable
projection geometry. Boundary rims are distinct from handle openings.
"""

from dataclasses import dataclass
from typing import Optional

from .model import _number


@dataclass(frozen=True)
class TypeIBoundary:
    """A fixed boundary at slot 1..2g+2; omit radius for a size suited to its slot."""
    slot: int
    radius: Optional[float] = None

    def __post_init__(self):
        if type(self.slot) is not int or self.slot < 1:
            raise ValueError("slot must be a positive integer")
        if self.radius is not None:
            _number(self.radius, "radius", positive=True)


@dataclass(frozen=True)
class BoundaryPair:
    """Two exchanged boundary components, one above and one below the axis.

    Side is left, right, or top (bottom/top-bottom are aliases of top).
    Omit position and radius for automatic spacing and collar size. Explicit
    position is 0..1 within the region; explicit geometry must fit without overlap.
    """
    side: str = "top"
    position: Optional[float] = None
    radius: Optional[float] = None

    def __post_init__(self):
        if self.side not in ("left", "right", "top", "bottom", "top-bottom"):
            raise ValueError("pair side must be left, right, top, bottom, or top-bottom")
        if self.position is not None:
            _number(self.position, "position")
            if not 0 <= self.position <= 1:
                raise ValueError("position must lie in 0..1")
        if self.radius is not None:
            _number(self.radius, "radius", positive=True)


@dataclass(frozen=True)
class GenusSurface:
    """A finite genus surface with an attractive default horizontal presentation.

    Only genus and boundary data are normally needed. Height is automatic:
    100 normally, 150 with side pairs. Spacing and height are optional
    appearance overrides. Independent vertical and
    horizontal views default to above/right.
    """
    genus: int = 2
    handle_spacing: float = 110
    height: Optional[float] = None
    show_axis: bool = False
    type_i: tuple = ()
    type_ii: tuple = ()
    view_vertical: str = "above"
    view_horizontal: str = "right"
    marks: tuple = ()

    def __post_init__(self):
        if type(self.genus) is not int or self.genus < 1:
            raise ValueError("genus must be a positive integer")
        object.__setattr__(self, "marks", tuple(self.marks))
        if any(not isinstance(name,str) or not name for name in self.marks) or len(set(self.marks)) != len(self.marks):
            raise ValueError("marks must have distinct nonempty string IDs")
        if len(self.marks) > 2*self.genus+1:
            raise ValueError("the automatic presentation supports at most 2g+1 marks")
        object.__setattr__(self, "type_ii", tuple(self.type_ii))
        if self.height is None:
            side_pairs = any(isinstance(p, BoundaryPair) and p.side in ("left", "right")
                             for p in self.type_ii)
            object.__setattr__(self, "height", 150 if side_pairs else 100)
        for name in ("handle_spacing", "height"):
            _number(getattr(self, name), name, positive=True)
        if self.view_vertical not in ("above", "below"):
            raise ValueError("view_vertical must be 'above' or 'below'")
        if self.view_horizontal not in ("left", "right"):
            raise ValueError("view_horizontal must be 'left' or 'right'")
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

    def cut_system(self):
        """The checked cut system for this finite surface presentation."""
        from .genus_mesh import genus_binding
        return genus_binding(self).system

    def with_cut_system(self):
        """Display the numbered standard chain (closed surfaces currently supported)."""
        from .genus_diagrams import GenusDiagram
        return GenusDiagram(self,show_cuts=True)

    def with_curves(self, *curves, intersections=()):
        from .genus_diagrams import GenusDiagram
        return GenusDiagram(self,tuple(curves),intersections=tuple(intersections))

    @property
    def width(self):
        return (self.genus + 0.7) * self.handle_spacing

    def _repr_svg_(self):
        from .svg import render_svg
        return render_svg(self)


def genus_layout(surface, style):
    if surface.marks:
        from .genus_diagrams import GenusDiagram
        return GenusDiagram(surface).drawing(style)
    from .genus_geometry import presentation
    return presentation(surface).drawing(style)
