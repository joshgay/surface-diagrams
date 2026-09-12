"""Generate supported gallery examples as TikZ and a compilable document.

SVG-only circular-hole scenarios get labeled placeholders until P7.

Run from the repository root: python examples/make_latex.py
Then change to examples/output and run: pdflatex latex-gallery.tex
"""
from pathlib import Path
import shutil

from gallery import gallery_examples
from surface_diagrams import Boundary, PlanarSurface, save_tikz
from surface_diagrams.tikz import _text


def make_latex(destination=None):
    root = Path(__file__).resolve().parents[1]
    out = Path(destination) if destination else root / "examples" / "output"
    out.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "latex" / "surface-diagrams.sty", out / "surface-diagrams.sty")
    # Paths are relative to this document's folder (also supported by Tectonic).
    lines = [r"\documentclass{article}", r"\usepackage[margin=20mm]{geometry}",
             r"\usepackage{surface-diagrams}", r"\pagestyle{empty}", r"\begin{document}"]
    for category, examples in gallery_examples().items():
        for name, caption, surface, style in examples:
            if (isinstance(surface, PlanarSurface) and style.boundary_shape == 'circle'
                    and any(isinstance(p, Boundary) for p in surface.objects)):
                lines.extend([r'\begin{center}', _text(caption)+r'\par',
                              'SVG example available; circular-boundary TikZ support is planned for P7.',
                              r'\end{center}',r'\clearpage'])
                continue
            filename = f"{category}-{name}.tikz"
            save_tikz(surface, out/filename, style=style, title=caption)
            lines.extend([r"\begin{center}", r"\Large " + _text(caption) + r"\par\bigskip",
                          r"\resizebox{0.95\linewidth}{!}{\SurfaceDiagram{" + filename + "}}",
                          r"\end{center}", r"\clearpage"])
    # Exercise the optional scaling macro and two local palettes on one page.
    lines.extend([r"\begin{center}", r"Two figures in one document\par\bigskip",
                  r"\SurfaceDiagram[0.6]{directions-adjacent-up.tikz}\par",
                  r"\SurfaceDiagram[0.6]{directions-adjacent-down.tikz}",
                  r"\end{center}", r"\end{document}"])
    path = out / "latex-gallery.tex"
    path.write_text("\n".join(lines)+"\n", encoding="utf-8")
    return path


if __name__ == "__main__":
    print(make_latex())
