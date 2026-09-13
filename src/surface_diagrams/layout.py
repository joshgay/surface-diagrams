"""Internal drawing primitives shared by SVG and TikZ exporters.

No exporter inheritance or plugin registry is needed. Coordinates remain
mathematical (y upward) until each exporter writes them.
"""

from math import hypot
from .model import Boundary, PlanarSurface, Style
from .primitives import Drawing, Ellipse


def layout(surface: PlanarSurface, style: Style) -> Drawing:
    from .visuals import PlanarDiagram, BraidDiagram, Figure
    from .factorizations import FactorizationDiagram
    from .documents import DiagramDocument
    if isinstance(surface, (PlanarDiagram, BraidDiagram, Figure, FactorizationDiagram, DiagramDocument)):
        return surface.drawing(style)
    from .genus import GenusSurface, genus_layout
    from .cut_diagrams import CutDiskDiagram
    from .genus_diagrams import GenusDiagram, BoundaryGuide, BorderedReferenceDiagram
    if isinstance(surface, (GenusDiagram, BoundaryGuide, BorderedReferenceDiagram)):
        return surface.drawing(style)
    if isinstance(surface, CutDiskDiagram):
        return surface.drawing(style)
    if isinstance(surface, GenusSurface):
        return genus_layout(surface, style)
    rx, ry = surface.width / 2, surface.height / 2
    if style.boundary_shape == "circle":
        # A circular boundary is a real hole; it cannot contain another object
        # or meet another hole. Dot-mode overlap behavior remains unchanged.
        for i, a in enumerate(surface.objects):
            for b in surface.objects[i+1:]:
                if not isinstance(a, Boundary) and not isinstance(b, Boundary):
                    continue
                ar = a.radius if a.radius is not None else (style.boundary_radius if isinstance(a, Boundary) else style.marked_point_radius)
                br = b.radius if b.radius is not None else (style.boundary_radius if isinstance(b, Boundary) else style.marked_point_radius)
                if hypot(a.x-b.x, a.y-b.y) <= ar+br+style.outline_width:
                    raise ValueError("circular boundaries must be disjoint from other holes and marked points")
    shapes = []
    if style.show_outer_ellipse:
        shapes.append(Ellipse(0, 0, rx, ry, "none", style.outline_color, style.outline_width, "outer-boundary"))
    for item in surface.objects:
        boundary = isinstance(item, Boundary)
        radius = item.radius if item.radius is not None else (
            style.boundary_radius if boundary else style.marked_point_radius
        )
        # Conservative containment: all four corners of the marker's bounding
        # box must lie inside the convex ellipse. Keeps oversized dots visible
        # and off the outline; it is intentionally stricter than disk fitting.
        extent = radius + (style.outline_width if boundary and style.boundary_shape == 'circle' else 0)
        if any(((item.x + sx * extent) / rx) ** 2 + ((item.y + sy * extent) / ry) ** 2 >= 1
               for sx in (-1, 1) for sy in (-1, 1)):
            raise ValueError("an object is too large or too close to the ellipse; reduce its radius or enlarge the surface")
        if boundary and style.boundary_shape == "circle":
            shapes.append(Ellipse(item.x, item.y, radius, radius, "none", style.outline_color,
                                  style.outline_width, "inner-boundary-circle"))
        else:
            color = style.boundary_color if boundary else style.marked_point_color
            shapes.append(Ellipse(item.x, item.y, radius, radius, color, "none", 0,
                                  "inner-boundary" if boundary else "marked-point"))
    # Reserve the same frame even when the outline is hidden.
    padding = style.padding + style.outline_width / 2
    from .curves import curve_primitives
    paths, texts = curve_primitives(surface, style)
    return Drawing(surface.width + 2 * padding, surface.height + 2 * padding, tuple(shapes), paths, texts)
