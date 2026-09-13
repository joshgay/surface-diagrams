# Standard chain systems (P4 work in progress)

`standard_cuts.chain_system(g, boundaries=(), marks=())` constructs an explicit
2g+1 chain, split at its 2g genuine intersections. The rotation at each vertex
alternates the two incident parents. Face walks recover two complementary
disks; the existing validator checks genus, all parent walks, and incidence.
Genus one has three chain members, including the distinct parallel end curves.

Each supplied boundary or mark is inserted into a complementary disk with a
numbered spoke. The anchor chain edge is subdivided, preserving its parent
number. A new `Attachment` record distinguishes a spoke ending on a cut from
a transverse intersection. Omitting a boundary spoke leaves an annulus;
omitting a marked-point spoke leaves an interior mark. Both are tested.

This is the topological portion of P4a, not yet a binding to genus drawings.
Default decorations alternate between the two disks. A physical presentation
must use an embedding consistent with those placements or construct an explicit
compatible cellulation. Matching surface counts is not enough.

The standard odd-chain neighborhood convention agrees with the chain relation
in [A Note on the Generating Sets for the Mapping Class Groups](https://dergipark.org.tr/en/download/article-file/1481705).
The implementation checks its own cellulation rather than using that convention
as a substitute for certification.

Verification: six new tests cover genera 1,2,3,5,8, boundary/mark cross-products,
stable numbers, missing spokes and false attachments. Next: disk routing and
numbered diagnostics, followed by checked bindings to the surface presentation.
## Disk routing and diagnostics checkpoint

`CutAtlas.build(system)` creates convex diagnostic charts for the certified
complementary disks. `DiskRoute` uses explicit `Crossing(side, position)`
locators; the opposite occurrence has parameter `1-position`. Arcs have explicit
`BoundaryPoint` or `MarkPoint` endpoints. Repeated visits must use distinct
positions. Number-only resolution fails with candidate sides when ambiguous.

Routes consist of chords inside these disks. Self-intersections, coincident
seam visits, boundary-following degeneracies and invalid face jumps fail.
Families are disjoint by default; intentional transverse intersections must
name the exact route/piece pair. Geometry uses doubles and a conservative
1e-10 diagnostic-chart tolerance, not an exact-arithmetic intersection claim.
No isotopy or minimal-intersection classification is promised.

`cut_along_route(atlas, route)` subdivides crossed seams consistently, splits
the cut disks along the route, glues the original cut graph back and reconstructs
the surface cut only along that route. Its components establish separation and
residual genus. Tests cover a nonseparating torus curve and an annular return arc
that separates, as well as repeated crossings and reversal invariance.

`system.diagram(*routes)` displays numbered complementary disks, oriented side
copies, original boundary IDs and marked-point copies. Use `show_ids=True` for
full side locators. `examples/make_cut_disks.py` generates six SVG diagnostics.
These use existing line/text primitives, so existing TikZ serialization also
works without a geometry extension. This is not completion of P7.

Surface projection and presentation binding remain unfinished. The diagnostic
polygons are valid cut disks, not a replacement for the requested genus drawings.


## Closed presentation binding checkpoint

`GenusSurface(g).with_cut_system()` draws the actual numbered chain on the
reference silhouette. `GenusSurface(g).cut_system()` returns its triangulated
cellulation, whose side IDs can be used by `DiskRoute`. This is a different
subdivision from `chain_system(g)`; side locators cannot be transferred between
them. Numbers identify the same chain members. Use `NamedCut(number)` from
`surface_diagrams.genus_diagrams` to draw a chain member directly.

The closed default mesh currently supports genus 1 through 7. Type I/II
boundaries are rejected explicitly while their chart extensions are unfinished.
Each sheet is a holed planar domain; seams identify its front and back copies.
The curved edge carriers use a Bernstein positivity check over each complete
cubic. Tangent sampling only proposes cell centers; it never substitutes for
that final check. The complementary disk charts solve a positive-weight graph
Dirichlet problem and reject any flipped or degenerate triangle. Rendering
flattens projected pieces with a whole-segment rational Bezier convex-hull bound:
positive homogeneous weights enclose every projected segment. This uses floating
point tolerances and is distinct from the local curved-triangle orientation
certificate. An S-bend regression prevents a zero midpoint deviation from hiding
a nonstraight segment.

Run `python examples/make_genus_cuts.py` for numbered genus 1/2/3/5, each genus-two
chain member, and a torus loop with its matching complementary-disk itinerary.
The torus example chooses an explicit side whose mate is in the same cut disk;
it does not guess a side from an ambiguous parent number.


Automatic front-sheet marks can be supplied as stable string IDs:
`GenusSurface(2, marks=('P', 'Q'))`. Up to `2g+1` marks are placed in the upper
outer mesh band. Their positions are automatic; arbitrary point coordinates
are not accepted by this constructor. Supplementary arcs are numbered after
the chain in input mark order. Their combinatorial walks use mesh-edge counts,
so changing the viewing direction does not choose a different cut.

`DiskRoute((), MarkPoint('P'), MarkPoint('Q'))` routes between these two marks
inside their common complementary disk and projects back to their exact surface
vertices. The example generator saves the ordinary arc, numbered cuts, and
matching cut-disk route. These marks remain mathematical points; they do not
create puncture boundary circles.


The genus-two examples now also include `genus-multiple-handles.svg`,
`genus-separating.svg`, `genus-repeated-crossings.svg`, `genus-disjoint.svg`, and
`genus-intersection.svg` with a matching intersection disk diagram. Tests
reconstruct the separating route as two genus-one components with one boundary
each; the multiple-handle route leaves a connected genus-one component with two
boundaries. Repeated visits use different positions on the same cut edge.

Declare genuine overlay crossings with
`surface.with_curves(a, b, intersections=((('a', 0), ('b', 0)),))`, where each
pair contains route IDs and zero-based disk-piece indices. Missing or extra
records fail. Projected front/back overlaps are not additional intersections.
The mesh projection is continuous and piecewise smooth; tangent changes between
carriers remain visible in some routed examples. It does not promise globally
smooth routes or minimal intersection representatives.

## Updated reference appearance

The default camera is above/right. Odd chain members run solid below and dashed
above; even members closely surround the openings, solid above and dashed below.
The below view reverses this pattern. Even-wrap visibility is a named-curve
presentation convention, separate from the underlying topological mesh sheet;
the chart incidence, cut membership and certificates are unchanged by dash style.
The tighter curve geometry is incorporated in the checked mesh, not merely drawn
over a different mesh. General DiskRoute strokes retain their sheet visibility.

For a straight supplied visual arc between automatic marks, use
`MarkedArc('P', 'Q')`. It checks the clear upper corridor and other marks.
`DiskRoute` remains the choice for a particular cut itinerary, whose projection
may bend. A straight MarkedArc has no automatic conversion to a disk itinerary.
