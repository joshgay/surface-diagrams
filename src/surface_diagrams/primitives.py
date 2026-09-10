"""Internal geometry in mathematical coordinates (y upward)."""

from dataclasses import dataclass
from typing import Tuple


@dataclass(frozen=True)
class Ellipse:
    x: float
    y: float
    rx: float
    ry: float
    fill: str
    stroke: str
    stroke_width: float
    role: str


@dataclass(frozen=True)
class Path:
    commands: Tuple[tuple, ...]
    stroke: str
    stroke_width: float
    role: str
    dashed: bool = False


@dataclass(frozen=True)
class Text:
    x: float
    y: float
    text: str
    color: str = "#777777"
    size: float = 9


@dataclass(frozen=True)
class Drawing:
    width: float
    height: float
    ellipses: Tuple[Ellipse, ...]
    paths: Tuple[Path, ...] = ()
    texts: Tuple[Text, ...] = ()
