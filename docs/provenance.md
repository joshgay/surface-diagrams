# Drawing references and implementation boundary

Primary visual reference: `C:/Users/Richa/Downloads/RichardBuckmanThesis.pdf`,
69-page PDF dated September 20, 2023. This private source is not copied into
the repository. The gallery uses newly generated drawings.

- PDF page 25, Figure 2.2: the genus-two silhouette, lens handle openings,
  horizontal half-turn axis, fixed and exchanged boundary components.
- PDF pages 36-38, Figures 3.2-3.6: planar dots, curves and colors.
- The PDF's DeviceRGB operands give marked-point RGB (0, 111/255, 1),
  planar boundary RGB (139/255, 139/255, 139/255), and common curve RGB
  (1, 0, 212/255): #006fff, #8b8b8b, #ff00d4 respectively.
- Figure 2.2 also contains #969696 boundary fills, and later figures contain
  several magentas and reds. The defaults consistently follow the planar set.

Algorithm references from Richard's existing local project:

- `legacy/cocalc_python/DrawPlanarArcs.py`: `drawArc`, `indexArcs`,
  `drawWithArcUsingIntersections`, and the horizontal/vertical subdivision code.
- `src/planar_mcg/rendering.py`: shared node slots for repeated cut visits,
  half-plane interleaving rejection, smooth subarcs, and route fidelity handling.

The new renderer adapts the shared-slot/combinatorial approach into a small,
independent planner. It keeps each itinerary exactly, bounds search, and uses
common-aspect half-ellipses instead of the old variable-height Bezier layout.
No algebra, factorization model, route simplification fallback, or independent
endpoint reconnection was imported. Some routes accepted by the old renderer
may therefore be rejected; acceptance there could involve its alternative
reconnection strategy or a simplified fallback.

The vertical subdivision variant has been inspected but is not implemented in
this package. No claim is made that the current coordinates implement Dylan
Thurston's or William Thurston's particular formal coordinate system; the
public convention is the cut itinerary specified by Richard in this project.

The higher-genus renderer is new code: no higher-genus drawing routine was
found among the Python files in the two reviewed projects. The topology is
drawn in the thesis's conventional projection, with true contour openings for
boundary necks. More detailed perspective, front/back curves, and standard
chain overlays remain separate future work.


## TikZ backend (0.1.0a2)

The SVG and TikZ writers consume the same internal Drawing. The TikZ writer
maps the current half-ellipse paths to native arcs and cubic paths to native
Bezier controls; it does not sample or reroute curves. Arbitrary rotated SVG
arc primitives are outside the current internal contract and raise an error.

One unit is 0.75bp in TikZ, corresponding to one CSS pixel at 96 dpi. Coordinates,
line widths, dash lengths, and label sizes all scale together. Text uses the
LaTeX document's Roman font rather than a browser-selected serif font.

Serialization follows the [PGF/TikZ path manual](https://tikz.dev/tikz-paths)
and [transformation behavior](https://tikz.dev/tikz-transformations).
The LaTeX companion only includes generated figures; mathematical layout stays
in Python. No runtime dependencies have been added to the Python package.
