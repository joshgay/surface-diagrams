"""Dependency-free SVG serialization; all layout is computed separately."""

from html import escape
from hashlib import sha256
from pathlib import Path

from .layout import layout
from .model import PlanarSurface, Style, _number
from .genus import GenusSurface
from .cut_diagrams import CutDiskDiagram
from .genus_diagrams import GenusDiagram, BoundaryGuide, BorderedReferenceDiagram
from .visuals import PlanarDiagram, BraidDiagram, Figure
from .factorizations import FactorizationDiagram
from .documents import DiagramDocument


def _n(value):
    return format(value, ".12g")


def render_svg(surface: PlanarSurface, *, style=None, scale=1, title="Planar surface") -> str:
    """Return a standalone SVG. Scale changes display size, not coordinates."""
    if not isinstance(surface, (PlanarSurface, GenusSurface, CutDiskDiagram, GenusDiagram, BoundaryGuide, BorderedReferenceDiagram, PlanarDiagram, BraidDiagram, Figure, FactorizationDiagram, DiagramDocument)):
        raise TypeError("expected a supported surface, diagram, or Figure")
    style = (surface.style if isinstance(surface, DiagramDocument) else Style()) if style is None else style
    if not isinstance(style, Style):
        raise TypeError("style must be a Style")
    _number(scale, "scale", positive=True)
    if not isinstance(title, str):
        raise TypeError("title must be a string")
    drawing = layout(surface, style)
    w, h = drawing.width, drawing.height
    lines = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {_n(w)} {_n(h)}" '
             f'width="{_n(w * scale)}" height="{_n(h * scale)}" role="img">',
             f"<title>{escape(title)}</title>"]
    if style.background is not None:
        lines.append(f'<rect width="100%" height="100%" fill="{style.background}"/>')
    def path_data(commands):
        result = []
        for command in commands:
            op, *values = command
            if op == "A":
                rx, ry, rotation, large, sweep, x, y = values
                values = [rx, ry, -rotation, large, 1-sweep, w/2+x, h/2-y]
            else:
                values = [w/2+v if i % 2 == 0 else h/2-v for i, v in enumerate(values)]
            result.append(op + " " + " ".join(_n(v) for v in values))
        return " ".join(result)
    holes = [s for s in drawing.ellipses if s.role == 'inner-boundary-circle']
    clip = ''
    if holes and drawing.paths:
        clip_id = 'sd-' + sha256((repr(drawing)+title).encode('utf-8')).hexdigest()[:20]
        commands = [('M',-w/2,-h/2),('L',w/2,-h/2),('L',w/2,h/2),('L',-w/2,h/2),('Z',)]
        for s in holes:
            commands.extend((('M',s.x-s.rx,s.y),
                             ('A',s.rx,s.ry,0,1,0,s.x+s.rx,s.y),
                             ('A',s.rx,s.ry,0,1,0,s.x-s.rx,s.y),('Z',)))
        lines.append(f'<defs><clipPath id="{clip_id}" clipPathUnits="userSpaceOnUse">'
                     f'<path d="{path_data(commands)}" clip-rule="evenodd" fill-rule="evenodd"/>'
                     '</clipPath></defs>')
        clip = f' clip-path="url(#{clip_id})"'
    for path in drawing.paths:
        extra = ' stroke-dasharray="3 3"' if path.dashed else ''
        lines.append(f'<path class="{path.role}" d="{path_data(path.commands)}" fill="none" '
                     f'stroke="{path.stroke}" stroke-width="{_n(path.stroke_width)}" '
                     f'stroke-linecap="round" stroke-linejoin="round"{extra}{clip}/>')
    for shape in drawing.ellipses:
        attrs = (f'class="{shape.role}" cx="{_n(w / 2 + shape.x)}" '
                 f'cy="{_n(h / 2 - shape.y)}"')
        if shape.role == 'inner-boundary-circle':
            lines.append(f'<circle {attrs} r="{_n(shape.rx)}" fill="none" '
                         f'stroke="{shape.stroke}" stroke-width="{_n(shape.stroke_width)}"/>')
        elif shape.role not in ("inner-boundary", "marked-point"):
            lines.append(f'<ellipse {attrs} rx="{_n(shape.rx)}" ry="{_n(shape.ry)}" '
                         f'fill="{shape.fill}" stroke="{shape.stroke}" stroke-width="{_n(shape.stroke_width)}"/>')
        else:
            lines.append(f'<circle {attrs} r="{_n(shape.rx)}" fill="{shape.fill}"/>')
    for label in drawing.texts:
        lines.append(f'<text x="{_n(w/2+label.x)}" y="{_n(h/2-label.y)}" '
                     f'fill="{label.color}" font-size="{_n(label.size)}" '
                     f'font-family="serif" text-anchor="middle">{escape(label.text)}</text>')
    lines.append("</svg>")
    return "\n".join(lines) + "\n"


def save_svg(surface: PlanarSurface, path, *, style=None, scale=1, title="Planar surface") -> Path:
    """Save UTF-8 SVG, creating parent directories. An existing file is replaced."""
    document = render_svg(surface, style=style, scale=scale, title=title)
    destination = Path(path)
    if destination.suffix.lower() != ".svg":
        raise ValueError("use an .svg filename; use save_tikz for TikZ output")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(document, encoding="utf-8")
    return destination.resolve()
