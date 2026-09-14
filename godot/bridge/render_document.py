"""Render one validated recipe through the repository's Python geometry API.

This is a fixed local adapter, not an extension point. It accepts JSON data and
writes SVG/TikZ data. It never imports a path supplied by the document or runs a
shell command.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src"
MAX_OUTPUT_BYTES = 4 * 1024 * 1024


def render(input_path: Path, svg_path: Path, tikz_path: Path) -> dict[str, object]:
    if SOURCE.is_dir():
        sys.path.insert(0, str(SOURCE))
    from surface_diagrams import DiagramDocument

    source = input_path.read_text(encoding="utf-8")
    document = DiagramDocument.from_json(source)
    svg = document.render_svg()
    tikz = document.render_tikz()
    encoded_size = len(svg.encode("utf-8")) + len(tikz.encode("utf-8"))
    if encoded_size > MAX_OUTPUT_BYTES:
        raise ValueError("rendered output exceeds 4 MiB")
    svg_path.parent.mkdir(parents=True, exist_ok=True)
    tikz_path.parent.mkdir(parents=True, exist_ok=True)
    svg_path.write_text(svg, encoding="utf-8")
    tikz_path.write_text(tikz, encoding="utf-8")
    return {
        "ok": True,
        "kind": document.to_dict()["kind"],
        "svg_bytes": len(svg.encode("utf-8")),
        "tikz_bytes": len(tikz.encode("utf-8")),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a Surface Diagrams JSON recipe")
    parser.add_argument("input", type=Path)
    parser.add_argument("svg", type=Path)
    parser.add_argument("tikz", type=Path)
    args = parser.parse_args()
    try:
        result = render(args.input, args.svg, args.tikz)
    except Exception as error:  # The caller needs a bounded, machine-readable failure.
        print(json.dumps({"ok": False, "error": f"{type(error).__name__}: {error}"}))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
