# Surface diagrams

Browse the [tutorial and gallery](https://richardbuckman-math.github.io/surface-diagrams/)
and planned relation and Lefschetz-fibration catalog. See
[publishing and releases](docs/RELEASING.md) for preview and deployment.

Development roadmap: [implementation plan](docs/IMPLEMENTATION_PLAN.md),
[current handoff](docs/HANDOFF.md), and [original reference diagrams](Figures/README.md).

A Python library for generating diagrams of surfaces for work with mapping class
groups and other relevant low dimensional geometry and topology. SVG and TikZ output allows
for arbitrary enlarging without losing sharpness.

This is extremely experimental for now. It is based on older code I wrote a while ago,
but this is the alpha version, 0.1.0a3. Python 3.9+; no runtime dependencies.
I will finish editing this readme when the software is in a more finished state. For now
what is here may be wrong or not yet implemented.

The default higher-genus presentation now follows the D3/D2A/E2 reference diagrams.
See the [source comparison](examples/output/reference-comparison.svg).

## Illustrated tutorial

Start with the [step-by-step tutorial](docs/TUTORIAL.md) or its
[browser edition](docs/TUTORIAL.html). Run `python examples/tutorial.py` to
regenerate the figures. It explains planar endpoint/cut numbering, closed curves,
rainbow systems, intersection overlays, vertical factors beside braids, and
higher-genus route inputs. Automatic actions and invariants remain later work.

`ColoredCurve`, `PlanarDiagram`, `BraidDiagram`, `Panel`, and `Figure` are
presentation tools for supplied configurations. The planar overlay option is
explicit; the older `with_curves` route remains disjoint by default.

## Install and make an image

From this directory:

```powershell
python -m pip install -e .
python examples/make_images.py
```

Examples should demonstrate all current capabilities but feel free to make requests.
SVG overview sheets and a [linked gallery](examples/output/GALLERY.md) are in
`examples/output/`. The constructors are in [examples/gallery.py](examples/gallery.py).

Run your own scripts with the Python environment where you installed the package.
For a fresh installation, use recent pip/setuptools: Anaconda pip 21.2 cannot
perform the editable installation above.

```python
from surface_diagrams import PlanarSurface, save_svg

# B = an inner boundary, P = a marked point; order is left to right.
surface = PlanarSurface.row("B P B P P")
save_svg(surface, "my-surface.svg", scale=2)
```

![Default planar surface](examples/output/01-thesis-default.svg)

## Edit diagrams in a browser

After installing the package, run:

```sh
surface-diagrams-editor
# Equivalently: python -m surface_diagrams.editor
```

The local editor supports planar arcs and loops, horizontal point/boundary rows,
signed braid words, labels, undo/redo, and editable JSON documents. Download SVG,
TikZ, or a reproducible Python script using the existing geometry engine. No
Godot, JavaScript build step, cloud service, or extra runtime dependency is needed.
See the [editor guide and limitations](docs/EDITOR.md). This is an experimental
first release; browser visual/interaction acceptance remains pending.

## Adjust the appearance

```python
from surface_diagrams import Style

style = Style(
    boundary_radius=6,
    marked_point_radius=3,
    show_outer_ellipse=False,
)
save_svg(surface, "my-points.svg", style=style)
```

The background is transparent by default. Set `background="#ffffff"` for white.
Colors accept `#RGB` or `#RRGGBB`. Defaults were measured directly from vector
painting commands in the thesis's planar figures (PDF pages 36-38):

| Element | Default | Customization |
| --- | --- | --- |
| Marked points | `#006fff` | `marked_point_color` |
| Inner boundary components | `#8b8b8b` | `boundary_color` |
| Curves | `#ff00d4` | `curve_color` |
| Surface outline | `#000000` | `outline_color` |

Some other thesis figures use slightly different grays or magentas. These
defaults follow Figures 3.2-3.6 consistently; see [provenance](docs/provenance.md).

## Choose positions and individual sizes

```python
from surface_diagrams import Boundary, MarkedPoint

surface = PlanarSurface(
    objects=[
        Boundary(-70, 0, radius=6),
        Boundary(70, 0, radius=6),
        MarkedPoint(-25, 20),
        MarkedPoint(-25, -20),
        MarkedPoint(25, 20),
        MarkedPoint(25, -20),
    ],
    width=240,
    height=110,
)
save_svg(surface, "custom-surface.svg")
```

Coordinates use drawing units, with the origin at the center, x to the right,
and y upward. Width and height describe the outer ellipse. Dot radii use the
same units. `scale` changes the displayed image size uniformly. Hiding the
outer ellipse preserves the image frame and positions. Automatic rows accept
`spacing`, `height`, and `margin` (distance from an endpoint dot center to the
horizontal tip of the ellipse).

Centers must lie inside the ellipse. At export time each dot's bounding box
must also fit strictly inside it; oversized dots raise a helpful error. This
conservative check can reject some nearly touching dots. Object overlap is
allowed and positions are never moved silently.

`render_svg(surface, ...)` returns text, and `save_svg(surface, path, ...)` writes
it (replacing that exact file if it already exists). A surface also displays
directly in Jupyter with the default style via `_repr_svg_()`.

## Arcs and closed curves

```python
from surface_diagrams import Arc, Loop

surface = PlanarSurface.row("PPPPPP", spacing=55, height=210, margin=60)
save_svg(surface.with_curves(Arc(2, 5, cuts=(3,), direction="down")), "arc.svg")
save_svg(surface.with_curves(Loop((1, 4))), "loop.svg")
save_svg(surface.with_curves(Loop((0, 6)), Loop((1, 5)), Arc(3, 4)), "nested.svg")
```

The objects must have distinct x coordinates and lie on y=0. Number them 1..n
from left to right, including both boundary dots and marked points. Cut i is
the open horizontal interval between objects i and i+1: the outside intervals
are 0 and n. Arc endpoints 0 and n+1 are the left/right tips of the outer ellipse.
Object endpoints connect to the drawn dot's center, including boundary dots.

`Arc(start, end, cuts=(...), direction="default")` follows the cuts in the
supplied order, alternating sides after every crossing. Default begins above
the axis, except that **arcs with no cuts** join consecutive objects, or an
outer boundary tip and an object, with a straight horizontal segment.
Set `direction="up"` or `direction="down"` to force a curved arc on that side,
even between consecutive objects. An explicit cut itinerary is never shortened.

For example, `Arc(2, 3)` is straight, `Arc(2, 3, direction="up")` curves up,
and `Arc(2, 3, direction="down")` curves down. `Arc(1, 4)` still curves up.
See the [direction comparison gallery](examples/output/directions-gallery.svg).
Existing `start_up=True/False` keywords and fourth positional booleans still
mean explicit up/down; do not combine them with a nondefault `direction`.

A straight arc cannot pass through unrelated dots or another curve's cut
crossing, or overlap another straight arc. In particular, a direct outer-tip
arc to a nonnearest object is rejected if intervening dots obstruct it: choose
`"up"` or `"down"` to go around them. Adjacent equal cuts and terminal cuts
adjacent to their endpoint are rejected as nonminimal. Start and end must differ.

`Loop((c0, c1, ...), start_up=True)` starts at the first cut and returns to it
after the final cut. A loop needs an even number of crossings and no cyclic
cancellation. `Loop((i-1, j))` surrounds consecutive objects i..j; e.g.
`Loop((0, 6, 5, 1))` draws a nonconsecutive example around the two end objects.

Use `Style(show_guides=True)` to display the symmetry line, object numbers above
it, and cut numbers below it. `curve_width`, `curve_color`, and `curve_height`
(a fraction in (0,1]) control the curves' appearance. Multiple curves are
routed together and must be disjoint except for shared arc endpoints.

Minimality alone does not imply a simple curve. The renderer searches for a
noninterleaving ordering of repeated visits to each interval, retaining the
same visit position above and below. Curved pieces are nested half-ellipses under a
common vertical scaling: this preserves disjoint centerlines and places them
inside the outer ellipse. Joins have matching vertical tangent directions.
Straight segments also participate in intersection checks. An analytic distance
check prevents either kind of segment from entering unrelated dots.

Unsupported or impossible routes raise `RoutingError`. A failure may mean
insufficient spacing, no noncrossing ordering, or a search limit; the message
distinguishes these. It never silently changes the itinerary. Search is capped
at 20,000 attempted slot assignments, with 64 cuts per curve and 128 route nodes
per diagram. Very dense curves may need thinner strokes, smaller dots, or more
space. This is a drawing convention, not a full isotopy-class classifier or
an implementation of a specifically attributed Thurston coordinate system.

## Higher genus: closed surfaces, then boundary placements

```python
from surface_diagrams import GenusSurface, TypeIBoundary, BoundaryPair

save_svg(GenusSurface(genus=2, show_axis=True), "genus-two.svg")
save_svg(GenusSurface(
    genus=2,
    type_i=(TypeIBoundary(6),),
    type_ii=(BoundaryPair("left"), BoundaryPair("top", position=.65)),
), "genus-two-with-five-boundaries.svg")
```

The low horizontal contour and shallow handle openings follow the D3/D2A/E2
source diagrams. `GenusSurface(2)` needs no appearance settings.
`handle_spacing` and `height` adjust their proportions when needed. These are
surface schematics; handle openings are not counted as boundary components.

Type I boundaries occupy fixed slots 1..2g+2 along the horizontal involution
axis. Slot 1 is the left outer tip; each handle contributes its left and right
tip in order; slot 2g+2 is the right outer tip. For genus 2, all six slots are
available. `TypeIBoundary(slot)` replaces a contour tip with an oval boundary
rim connected to the upper/lower outlines. Its radius is automatic: larger at
outer ends, smaller in handle openings. An explicit radius overrides that size.
Duplicate slots are errors.

Each `BoundaryPair(side)` produces **two** Type II
boundary components, exchanged by the modeled half-turn. Choose `left`, `right`,
or `top`; `bottom` and `top-bottom` are aliases of `top`, because both members
are always drawn. Omitted positions and radii are distributed and sized
automatically. For example, `GenusSurface(3, type_ii=(BoundaryPair(),)*6)` draws
six top/bottom pairs without tuning. Explicit `position` ranges from 0 to 1
within the selected region; an explicit radius must fit. Side pairs open
sideways, and top/bottom collars protrude only slightly. Extremely dense rims
that cannot be distinguished at the selected stroke width raise an error.
Neck attachments
are made by splitting the actual contour, so transparent output works without
white masking patches. Type I and Type II radii are geometric boundary sizes,
independent of the planar dot-size settings.

Choose `view_vertical="above"` or `"below"` and `view_horizontal="left"` or
`"right"`. The default is above/right; below/right remains available. Facing rims
are fully visible and opposite rims have a dashed inward half. Handle openings
have overlapping edges that reverse with the view. Side pairs automatically get
a taller body and larger, farther-separated openings. See the
[four viewing directions](examples/output/views-gallery.svg).
See [presentation details](docs/genus-presentation.md). This geometric
presentation does not yet implement genus curve routing or certified cut systems.

## Circular planar boundaries

Use one style option to show actual circular holes instead of gray dots:

```python
surface = PlanarSurface.row("BPBPB")
save_svg(surface, "circles.svg", style=Style(boundary_shape="circle"))
```

The automatic circle radius is 12; marked points remain blue dots. An explicit
`boundary_radius` or a `Boundary(..., radius=...)` overrides the size. Existing
`Arc` and `Loop` inputs work on horizontal rows: arcs end on the circle rims,
and curves and guide lines stay out of the holes. Use `show_guides=True` for
numbered horizontal guides. Circle outlines use `outline_color` and
`outline_width`. The default dot presentation remains unchanged.

See the [circle gallery](examples/output/circles-gallery.svg) and
[geometry and limitations](docs/circular-boundaries.md). Circular-hole export
supports SVG and TikZ with transparent hole clipping. Curves on general
nonhorizontal arrangements are a later stage.

## TikZ and LaTeX

```python
from surface_diagrams import Arc, PlanarSurface, save_tikz

surface = PlanarSurface.row("BPPB").with_curves(Arc(2, 3))
save_tikz(surface, "figure.tikz")
```

`render_tikz(surface, style=..., scale=...)` returns text; `save_tikz` writes it.
No LaTeX installation is needed to generate these files. To compile them, load
TikZ in your document and include the generated picture:

```tex
\usepackage{tikz}
% Inside the document:
\input{figure.tikz}
```

The optional [LaTeX companion](latex/README.md) provides
`\SurfaceDiagram[0.6]{figure.tikz}` for convenient uniform scaling.
Both exporters share geometry, palette, drawing order, and framing. TikZ uses
0.75bp per drawing unit, matching SVG at 96 dpi. Python's `scale` also scales
strokes, dashes, and labels. Guide labels use the document's Roman font.

Generate the supported TikZ examples and a compilable gallery:

```powershell
python examples/make_latex.py
cd examples/output
pdflatex -interaction=nonstopmode -halt-on-error latex-gallery.tex
```

The companion is in `latex/` in this repository and is also included in Python
installations under `share/surface-diagrams/latex` beneath the installation prefix.
Copy it beside your LaTeX document, or use TikZ directly without the companion.

## Command line

```powershell
python -m surface_diagrams --row "B P B P" figure.svg
python -m surface_diagrams --genus 2 --scale 1.5 genus-two.tikz
```

After installation, `surface-diagrams` is an equivalent command. The filename
chooses the output format. Use the Python API for curves, styles, or custom
boundary placements; the CLI deliberately covers only basic rows and closed
higher-genus surfaces.

## Scope and next steps

Implemented: planar surfaces, row/custom positioning, adjustable dots/colors,
minimal arcs/loops, noncrossing multicurves, coordinate guides, higher genus,
all fixed boundary slots and left/right/top-bottom paired boundaries, circular
planar holes with rim-ended arcs, SVG, TikZ,
a LaTeX inclusion companion, and a small command-line entry point.

Later: standard chain curves on higher-genus surfaces, marked points on them,
Type II boundaries inside handle holes or at front/back locations, asymmetric
layouts. PNG/PDF
export is not built in; SVGs can be converted externally when needed.

`model.py` holds planar inputs/styles and `curves.py` plans planar routes.
`genus.py` holds genus inputs and `genus_geometry.py` builds their presentation.
`layout.py` assembles format-independent primitives;
`svg.py` and `tikz.py` serialize the same geometry into their respective formats.

The internal [cut-system validator](docs/cut-systems.md) reconstructs explicit
polygon cellulations and checks whether selected cuts leave unmarked disks.
Worked examples cover a disk, annulus, marked disk, torus, genus two, pair of
pants, and a two-disk complement. This certifies abstract topology; integration
with numbered genus drawings and generalized routes is the next stage.

## Development

```powershell
python -m unittest discover -s tests -v
```

Tests use Python's standard `unittest` suite, including coordinate validation,
visit-order preservation, seeded geometric checks, palette and SVG behavior,
boundary symmetry and joins, TikZ geometry and scaling, CLI validation, and gallery
smoke tests.

GitHub Actions runs Python tests on 3.9 and 3.12, checks gallery regeneration,
and compiles every TikZ gallery example with pdfLaTeX.
