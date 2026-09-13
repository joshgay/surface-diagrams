# Circular planar boundaries

`Style(boundary_shape="circle")` is the single ordinary option. Its automatic
boundary radius is 12 drawing units, compared with 4 in the default dot mode.
`Boundary` still denotes a topological boundary and `MarkedPoint` still denotes
a point. Switching presentation does not change either object's identity.

```python
from surface_diagrams import PlanarSurface, Style, Arc, Loop, save_svg

style = Style(boundary_shape="circle")
save_svg(PlanarSurface.row("BPBPB"), "mixed.svg", style=style)
surface = PlanarSurface.row("BBBBBB", spacing=55, height=210, margin=60)
save_svg(surface.with_curves(Arc(2, 3), Loop((3, 6))), "curves.svg", style=style)
```

The larger dimensions in the second example leave room for the surrounding
loop. No new arc or loop notation is needed. Adjacent default arcs stay straight;
`direction="up"` or `"down"` selects a curved arc. Endpoints 0 and n+1 still refer
to the outer ellipse tips; objects are numbered 1 through n from left to right.
Arc endpoints attached to circular boundaries terminate on the rims, while
marked-point endpoints retain the existing behavior.

`boundary_radius` changes the default hole radius, and `Boundary(..., radius=...)`
changes an individual radius. Hole outlines use `outline_color`/`outline_width`.
There is no fill in the hole. The existing `background` paints the image canvas;
when it is omitted, a hole reveals whatever lies behind the SVG.

The router includes physical radii in cut-interval spacing and checks analytical
clearance against unrelated objects. Outline thickness contributes to circular
boundary clearance and containment. Impossible or overly crowded inputs raise
an error rather than silently drawing through another hole. The existing
noncrossing contract is preserved; use `PlanarDiagram(..., allow_intersections=True)`
for separately routed intersecting overlays.

Curved and straight arcs meet exact left/right rim positions. By default the
rim faces the first/last route segment. `Arc(..., start_side="left",
end_side="right")` chooses explicitly; either option can be omitted. These
options apply only to circular inner boundaries. The router checks clearance
against the endpoint hole as well: an outward-facing curved anchor may require
more height, and an outward-facing straight segment cannot cross its own hole.

An even-odd clipping path excludes all hole interiors from curve strokes and
guide strokes, including rounded caps. There are no white masking disks.
The clip identifier is derived deterministically from geometry and title.

`show_guides=True` draws the existing horizontal axis and labels. Object labels
are raised above their rims; cut labels sit in the free gaps between rims.
These examples are horizontal routing guides, not the new topological
cut-system certificates planned in P3/P4/P5.

All new scenarios are in [the gallery](../examples/output/circles-gallery.svg):
empty disk, annulus, default row, mixed holes/points, dot comparison, straight
and curved arcs in both directions, mixed endpoints, outer endpoints, closed
curves, numbered guides, explicit radii, and colored backgrounds.

Circular boundary diagrams export to SVG and TikZ, including curved rim anchors,
colored families, guides and mixed Figure panels. TikZ uses an even-odd clipping
scope for path strokes, then draws rims and labels outside that scope. Holes
remain transparent; no white masking disks are introduced. The LaTeX gallery
now includes every circular-boundary scenario, and CI compiles the tutorial
figures as well as the main gallery.
