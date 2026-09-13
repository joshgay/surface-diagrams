"""Surface images and planar curves. Coordinates have x rightward and y upward."""

from .model import Boundary, MarkedPoint, PlanarSurface, Style
from .curves import Arc, Loop, RoutingError
from .genus import GenusSurface, TypeIBoundary, BoundaryPair
from .svg import render_svg, save_svg
from .tikz import render_tikz, save_tikz

__all__ = ["Boundary", "MarkedPoint", "PlanarSurface", "Style", "Arc", "Loop", "RoutingError", "GenusSurface", "TypeIBoundary", "BoundaryPair", "render_svg", "save_svg", "render_tikz", "save_tikz"]

from .visuals import ColoredCurve, PlanarDiagram, BraidDiagram, Panel, Figure, RAINBOW
__all__ += ["ColoredCurve", "PlanarDiagram", "BraidDiagram", "Panel", "Figure", "RAINBOW"]

from .genus_diagrams import MarkedArc
__all__ += ["MarkedArc"]

from .factorizations import FactorPanel, FactorizationDiagram
__all__ += ["FactorPanel", "FactorizationDiagram"]

from .documents import DiagramDocument
__all__ += ["DiagramDocument"]
