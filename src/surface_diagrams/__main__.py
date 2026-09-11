"""Small command-line entry point; use Python for curves and custom placements."""
import argparse
from pathlib import Path

from . import GenusSurface, PlanarSurface, save_svg, save_tikz


def main(argv=None):
    parser = argparse.ArgumentParser(description="Draw a planar row or closed genus surface as SVG or TikZ.")
    kind = parser.add_mutually_exclusive_group(required=True)
    kind.add_argument("--row", help="left-to-right B/P pattern, e.g. 'B P B P'")
    kind.add_argument("--genus", type=int, help="positive genus")
    parser.add_argument("output", type=Path, help="destination ending in .svg or .tikz")
    parser.add_argument("--scale", type=float, default=1, help="uniform display scale (default: 1)")
    args = parser.parse_args(argv)
    writers = {".svg": save_svg, ".tikz": save_tikz}
    writer = writers.get(args.output.suffix.lower())
    if writer is None:
        parser.error("output must end in .svg or .tikz")
    try:
        surface = PlanarSurface.row(args.row) if args.row is not None else GenusSurface(args.genus)
        destination = writer(surface, args.output, scale=args.scale)
    except (TypeError, ValueError, OSError) as error:
        parser.error(str(error))
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
