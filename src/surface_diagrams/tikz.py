"""Dependency-free TikZ serialization of the same geometry used by SVG."""

from math import isclose
from pathlib import Path

from .genus import GenusSurface
from .cut_diagrams import CutDiskDiagram
from .genus_diagrams import GenusDiagram, BoundaryGuide, BorderedReferenceDiagram
from .visuals import PlanarDiagram, BraidDiagram, Figure
from .factorizations import FactorizationDiagram
from .documents import DiagramDocument
from .layout import layout
from .model import PlanarSurface, Style, _number


def _n(value):
    return format(value, ".12g")


def _point(x, y):
    return f"({_n(x)},{_n(y)})"


def _text(value):
    escapes = {"\\": r"\textbackslash{}", "{": r"\{", "}": r"\}",
               "#": r"\#", "$": r"\$", "%": r"\%", "&": r"\&",
               "_": r"\_", "^": r"\textasciicircum{}", "~": r"\textasciitilde{}"}
    return "".join(escapes.get(c, c) for c in value)


def _path(commands):
    """Serialize current primitives; A commands are axis-aligned half-ellipses."""
    result, current, beginning = [], None, None
    for op, *v in commands:
        if op == "M":
            current = beginning = tuple(v)
            result.append(_point(*v))
        elif op == "L":
            result.append("-- " + _point(*v))
            current = tuple(v)
        elif op == "C":
            result.append(f".. controls {_point(*v[:2])} and {_point(*v[2:4])} .. {_point(*v[4:])}")
            current = tuple(v[4:])
        elif op == "A":
            rx, ry, rotation, large, sweep, x, y = v
            if (current is None or rotation != 0 or large != 0 or sweep not in (0, 1)
                    or rx <= 0 or ry <= 0 or not isclose(current[1], y, abs_tol=1e-10)
                    or not isclose(abs(x-current[0]), 2*rx)):
                raise ValueError("TikZ expects an axis-aligned half-ellipse primitive")
            start = 180 if x > current[0] else 0
            end = start + (180 if sweep else -180)
            result.append(f"arc[start angle={start},end angle={end},x radius={_n(rx)},y radius={_n(ry)}]")
            current = (x, y)
        elif op == "Z":
            result.append("-- cycle")
            current = beginning
        else:
            raise ValueError(f"unsupported TikZ path command: {op}")
    return " ".join(result)


def render_tikz(surface, *, style=None, scale=1, title="Surface diagram") -> str:
    """Return an includable tikzpicture; the document must load the tikz package.

    One drawing unit is 0.75bp (one SVG pixel at 96 dpi). Scale changes all
    dimensions, including strokes, dashes and labels. No TeX installation is
    needed to generate this string. Labels are plain text, not TeX commands.
    """
    if not isinstance(surface, (PlanarSurface, GenusSurface, CutDiskDiagram, GenusDiagram, BoundaryGuide, BorderedReferenceDiagram, PlanarDiagram, BraidDiagram, Figure, FactorizationDiagram, DiagramDocument)):
        raise TypeError("expected a supported surface, diagram, or Figure")
    style = (surface.style if isinstance(surface, DiagramDocument) else Style()) if style is None else style
    if not isinstance(style, Style):
        raise TypeError("style must be a Style")
    _number(scale, "scale", positive=True)
    if not isinstance(title, str):
        raise TypeError("title must be a string")
    drawing = layout(surface, style)
    holes = tuple(e for e in drawing.ellipses if e.role == 'inner-boundary-circle')
    unit = .75 * scale
    colors = {}

    def color(value):
        if value == "none":
            return value
        code = value.lstrip("#").upper()
        if len(code) == 3:
            code = "".join(c*2 for c in code)
        if code not in colors:
            colors[code] = f"sdcolor{len(colors)}"
        return colors[code]

    def length(value):
        return _n(value*unit) + "bp"

    corner1 = _point(-drawing.width/2, -drawing.height/2)
    corner2 = _point(drawing.width/2, drawing.height/2)
    frame = f"{corner1} rectangle {corner2}"
    body = [f"\\path[use as bounding box] {frame};", f"\\clip {frame};"]
    if style.background is not None:
        body.append(f"\\fill[{color(style.background)}] {frame};")
    if holes:
        # Clip strokes only. Boundary rims and labels are drawn outside this scope.
        # The even-odd rule leaves genuine transparent holes without white masks.
        cutouts = ' '.join(f"{_point(e.x, e.y)} ellipse ({_n(e.rx)} and {_n(e.ry)})"
                           for e in holes)
        body.extend([r"\begin{scope}", r"\pgfseteorule", f"\\clip {frame} {cutouts};"])
    for path in drawing.paths:
        options = f"draw={color(path.stroke)},line width={length(path.stroke_width)}"
        if path.dashed:
            options += f",dash pattern=on {length(3)} off {length(3)}"
        body.extend([f"% {path.role}", f"\\draw[{options}] {_path(path.commands)};"])
    if holes:
        body.append(r"\end{scope}")
    for shape in drawing.ellipses:
        options = f"fill={color(shape.fill)},draw={color(shape.stroke)},line width={length(shape.stroke_width)}"
        body.extend([f"% {shape.role}",
                     f"\\path[{options}] {_point(shape.x, shape.y)} ellipse [x radius={_n(shape.rx)},y radius={_n(shape.ry)}];"])
    for label in drawing.texts:
        options = (f"anchor=base,inner sep=0pt,outer sep=0pt,text={color(label.color)},"
                   f"font=\\rmfamily\\fontsize{{{length(label.size)}}}{{{length(label.size*1.2)}}}\\selectfont")
        body.append(f"\\node[{options}] at {_point(label.x, label.y)} {{{_text(label.text)}}};")
    # Keep palette definitions local so multiple figures can share a document.
    lines = ["% Generated by surface-diagrams; requires \\usepackage{tikz}."]
    lines.extend("% " + line.replace("^", r"	extasciicircum{}") for line in title.splitlines())
    lines.append(r"\begingroup")
    lines.extend(f"\\definecolor{{{name}}}{{HTML}}{{{code}}}" for code, name in colors.items())
    lines.append(f"\\begin{{tikzpicture}}[x={_n(unit)}bp,y={_n(unit)}bp,line cap=round,line join=round]")
    lines.extend(body)
    lines.extend([r"\end{tikzpicture}", r"\endgroup"])
    return "\n".join(lines) + "\n"


def save_tikz(surface, path, *, style=None, scale=1, title="Surface diagram") -> Path:
    """Write UTF-8 .tikz, creating parents and replacing that exact file."""
    destination = Path(path)
    if destination.suffix.lower() != ".tikz":
        raise ValueError("use a .tikz filename")
    document = render_tikz(surface, style=style, scale=scale, title=title)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(document, encoding="utf-8")
    return destination.resolve()
