# LaTeX companion

Generate figures in Python, then include the generated TikZ in LaTeX.
No shell escape or Python execution inside LaTeX is required.

Put surface-diagrams.sty and your generated figure.tikz beside your document:

~~~tex
\documentclass{article}
\usepackage{surface-diagrams}
\begin{document}
\SurfaceDiagram{figure.tikz}
\SurfaceDiagram[0.6]{figure.tikz} % uniformly scale the complete figure
\end{document}
~~~

The companion only loads TikZ and graphicx and provides this inclusion command.
It does not parse a model or calculate geometry. It is optional: you can instead
load tikz and use \input{figure.tikz} directly. Do not nest an exported picture
inside another tikzpicture.

From the repository root:

~~~powershell
python examples/make_latex.py
cd examples/output
pdflatex -interaction=nonstopmode -halt-on-error latex-gallery.tex
~~~

LuaLaTeX, XeLaTeX, or Tectonic may be used instead. The generated document includes
the supported gallery examples and a page demonstrating multiple inclusions.
Plain-text guide labels use the document's Roman font, so their glyphs can differ
from those in a browser. Geometry, colors, strokes, and framing are shared.

One drawing unit is 0.75 PDF points (bp), matching an SVG pixel at 96 dpi.
Use the Python scale option or the inclusion macro to scale uniformly.
The package itself remains dependency-free; a TeX installation is only needed
when compiling a document. The companion is shipped in Python distributions at
share/surface-diagrams/latex beneath the installation prefix.
