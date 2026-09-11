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
height 100. These are optional appearance settings. The default radius of a
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

The viewing convention follows the source sheets: inward halves of upper and
left-facing collars are hidden; lower and right-facing openings show full rims.
This asymmetry is a projection convention, not asymmetric boundary topology.
Reflecting a diagram does not imply that the viewer changes sides. No white
masking shapes are used; the outlines have actual openings.

Changes from the previous alpha default:

- Height 100 replaces 170; openings are shallow rather than tall pointed lenses.
- The top/bottom contour no longer scallops once per handle.
- Left/right pairs open sideways rather than sitting near the top corners.
- Omitted boundary radii and pair positions are automatic; explicit numerical
  values remain supported. The `lens` and `balloon` style names remain valid.

The result is presentation geometry only. It is not yet a topological
cellulation, cut-system certificate, or genus curve router. Those are later
stages in the implementation plan. The existing SVG and TikZ writers consume
the same M/C paths, so this stage required no new exporter logic.
