# Default genus presentation

The default now follows the D3/D2A/E2 reference SVGs in Figures/. It uses a low
horizontal body, shallow openings, broad short collars, and visible/hidden rim
halves. A [reproducible comparison](../examples/output/reference-comparison.svg)
shows original abbreviated panels beside finite generated surfaces.

Ordinary calls need only genus and mathematical boundary data:

```python
from surface_diagrams import GenusSurface, TypeIBoundary, BoundaryPair, save_svg

save_svg(GenusSurface(2), "closed.svg")
save_svg(GenusSurface(3, type_i=(TypeIBoundary(8),),
                      type_ii=(BoundaryPair(),)*6), "d3.svg")
save_svg(GenusSurface(3, type_ii=(BoundaryPair("left"), BoundaryPair("right"),
                                BoundaryPair(), BoundaryPair())), "e2.svg")
```

The automatic body dimensions are 110 units per handle plus end margins, with
height 100, or 150 when side pairs need more room. An explicit height overrides
that choice. Side pairs have larger openings with more separation and rounded
recesses between them. These are optional appearance settings. The default radius of a
fixed boundary depends on its slot; end openings are larger than openings at
handle tips. Automatic pairs are spread across their side in input order, and
their radii are reduced as necessary to fit the spacing. Explicit positions or
radii are honored and must fit. Mixed explicit/automatic positions can conflict;
in that case the renderer reports the overlap instead of moving an explicit rim.

Internally `genus_geometry.Presentation` separates outline/handle curves and
oriented `Rim` objects from the surface input. Rims retain stable IDs, anchor
points, tangent and outward-normal directions, and hidden-half information.
The paths join those anchors with matching tangent directions. Elliptical rims
are represented by the usual quarter-ellipse cubic approximation.

Choose the viewing direction with two independent options:

```python
surface = GenusSurface(3, view_vertical="above", view_horizontal="left")
```

The defaults are `view_vertical="below"` and `view_horizontal="right"`, as in
D3. `view_vertical="above"` matches the D2A panel. A top-facing rim is fully
visible from above and has a hidden inward half from below; bottom-facing rims
reverse this. The horizontal choice similarly controls left/right-facing rims,
including fixed boundaries inside handle openings. Stable boundary IDs and
topology do not change with the view. See the
[four-view examples](../examples/output/views-gallery.svg).

Each handle opening has a longer near edge, with the shorter far edge ending
on it just inside the tips. The near edge is lower when viewed from below and
upper when viewed from above. The small side-dependent overlap reverses when
the horizontal view reverses. This uses trimmed geometry and requires no white
masking, including on colored backgrounds. Boundaries occupying handle tips
retain their exact attachments. In D3-style rows, the outer contour connects
directly to the outermost collars; a fixed end boundary has a short neck.

`Presentation.faces_viewer(normal)` exposes the convention for future genus
curve routing. A curve segment's local surface normal must be known before
assigning its hidden style; vertical screen position alone is insufficient.

Changes from the previous alpha default:

- Height is automatic (100, or 150 with side pairs); openings are shallow.
- The top/bottom contour no longer scallops once per handle.
- Left/right pairs open sideways rather than sitting near the top corners.
- Omitted boundary radii and pair positions are automatic; explicit numerical
  values remain supported. The `lens` and `balloon` style names remain valid.

The result is presentation geometry only. It is not yet a topological
cellulation, cut-system certificate, or genus curve router. Those are later
stages in the implementation plan. The existing SVG and TikZ writers consume
the same M/C paths, so this stage required no new exporter logic.
