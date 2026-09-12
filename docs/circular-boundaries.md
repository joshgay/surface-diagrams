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
noncrossing contract is preserved; intersecting daisy overlays come in P5.

An analytical ellipse/circle intersection trims the first and last route
segments. SVG endpoint-form arc flags preserve the original ellipse center.
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

Circular boundary diagrams currently export to SVG only. `render_tikz` and
`save_tikz` explicitly raise `NotImplementedError` for a planar diagram containing
circular holes; saving does not overwrite an existing file on this error.
The LaTeX gallery gives a placeholder for those scenarios. Existing dot and
genus export remains available. Extending all new TikZ geometry is P7.
