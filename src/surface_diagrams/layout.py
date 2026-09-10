"""Internal drawing primitives shared by current SVG and future exporters.

No exporter inheritance or plugin registry is needed. Coordinates remain
mathematical (y upward) until each exporter writes them.
"""

from .model import Boundary, PlanarSurface, Style
from .primitives import Drawing, Ellipse


def layout(surface: PlanarSurface, style: Style) -> Drawing:
    from .genus import GenusSurface, genus_layout
    if isinstance(surface, GenusSurface):
        return genus_layout(surface, style)
    rx, ry = surface.width / 2, surface.height / 2
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
        if any(((item.x + sx * radius) / rx) ** 2 + ((item.y + sy * radius) / ry) ** 2 >= 1
               for sx in (-1, 1) for sy in (-1, 1)):
            raise ValueError("a dot is too large or too close to the ellipse; reduce its radius or enlarge the surface")
        color = style.boundary_color if boundary else style.marked_point_color
        shapes.append(Ellipse(item.x, item.y, radius, radius, color, "none", 0,
                              "inner-boundary" if boundary else "marked-point"))
    # Reserve the same frame even when the outline is hidden.
    padding = style.padding + style.outline_width / 2
    from .curves import curve_primitives
    paths, texts = curve_primitives(surface, style)
    return Drawing(surface.width + 2 * padding, surface.height + 2 * padding, tuple(shapes), paths, texts)
