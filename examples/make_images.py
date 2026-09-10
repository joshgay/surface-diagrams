"""Run after installing: python examples/make_images.py."""

from pathlib import Path
from surface_diagrams import Boundary, MarkedPoint, PlanarSurface, Style, save_svg


def main():
    out = Path(__file__).resolve().parent / "output"
    row = PlanarSurface.row("B P B P P")
    examples = [
        ("01-thesis-default", row, Style()),
        ("02-no-outer-ellipse", row, Style(show_outer_ellipse=False)),
        ("03-adjustable-sizes", row, Style(boundary_radius=7, marked_point_radius=3)),
        ("04-custom-positions", PlanarSurface([
            Boundary(-70, 0, radius=6), Boundary(70, 0, radius=6),
            MarkedPoint(-25, 20), MarkedPoint(-25, -20),
            MarkedPoint(25, 20), MarkedPoint(25, -20),
        ], width=240, height=110), Style()),
        ("05-empty-disk", PlanarSurface(width=180, height=80), Style()),
    ]
    for name, surface, style in examples:
        print(save_svg(surface, out / f"{name}.svg", style=style, scale=2, title=name))
    from gallery import make_gallery
    print(make_gallery(out))


if __name__ == "__main__":
    main()
