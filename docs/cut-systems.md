# Cut systems: combinatorial specification (P3a)

Status: P3 abstract-cellulation validator implemented in
`src/surface_diagrams/cut_systems.py`; its records remain internal and are not
exported from the package root. The existing horizontal `Arc`/`Loop` interface
is unchanged. P4 still needs standard chain constructions, numbered drawings,
presentation bindings, and routing.

## Surface first, cuts second

A cut system is an embedded graph whose complementary components are disks
with no interior marked points. Several disks are allowed. Graph edges can
belong to intersecting numbered closed curves or properly embedded arcs.

Supply a finite oriented polygon cellulation of the surface independently of
which edges are selected as cuts. A polygon is an actual combinatorial disk:
its corner and side *occurrences* are distinct before gluing. Repeated vertex
names must never identify corners implicitly. Every identification is induced
by an explicit side pairing. Unpaired sides are genuine surface boundary.

Select whole paired edges of that cellulation as the cut graph. Subdivide the
cellulation before representing a cut through a face or a mark. Auxiliary
paired edges are permitted and are essential: they let an incomplete candidate
leave an annulus or handle instead of automatically treating every face as a
complementary disk. A certificate reconstructs both the full surface and the
surface obtained by omitting only the selected pairings.

This is a certificate relative to the supplied cellulation. Matching genus and
boundary count does not certify that an unrelated drawing embeds this graph.
A custom configuration supplies this topology explicitly. A standard rendered
preset must additionally provide a checked binding to this same cellulation;
until P4 implements that binding, reports must say `abstract_cellulation`, not
claim validation of a genus SVG presentation.

## Proposed minimal records

The implementation follows these records with two simplifications: a selected
`SidePair.id` is the cut-edge ID (`Cellulation.cuts`), and `ParentCut.walk`
assigns its selected edges to a parent, so no separate `CutEdge` object is needed.
`PresentationBinding` is reserved for P4; requesting a rendered certification
scope currently returns `unsupported_binding`. Do not export these names from
the package root yet.

| Record | Fields and meaning |
| --- | --- |
| `SurfaceSpec` | Stable surface ID, expected genus, ordered boundary IDs, ordered mark IDs; initially one connected orientable surface |
| `Face` | Stable ID and a cyclic ordered tuple of at least three distinct side-occurrence IDs; each consecutive pair determines one corner occurrence |
| `SidePair` | Two distinct side occurrences; always glue their boundary directions oppositely |
| `BoundarySide` | One unpaired side occurrence and its stable boundary ID |
| `Mark` | Stable ID with either a corner occurrence or a face-interior locator |
| `CutEdge` | Stable ID, a paired edge, parent cut ID, and direction relative to the first paired side |
| `ParentCut` | Positive stable display number, kind `arc` or `closed`, ordered oriented cut-edge walk, endpoint locators for arcs |
| `VertexIncidence` | Expected cyclic order (interior vertex) or linear order (boundary vertex) of oriented edge ends, checked against recovered links |
| `PresentationBinding` | Cellulation ID and mappings to charts, seam transitions, projected paths and explicitly declared genuine intersections |
| `CutReport` | Recovered full topology, per-complement topology, mark locations, binding scope, structured diagnostics, and certification status |

IDs are unique within their record type. Parent cut numbering is independent
of screen position and styling. Chart coordinates, path control points, color,
scale and visibility never determine corner identifications or numbering.
A mark at a vertex is stored once, even if gluing gives it many corner copies.
Different mark IDs may not describe the same topological point in the initial
supported model. Face-interior marks are legal surface data but obstruct a
successful cut certificate until the cellulation is refined to reach them.

All oriented edge walks must be continuous in the reconstructed surface.
Closed walks close; arc endpoints are specified boundary points or marks.
Reject repeated edges or self-incidence inconsistent with an embedded parent
curve. Distinct parents may meet at explicitly declared genuine vertices;
verify their half-edge incidence and cyclic order there. Initial shared-edge
parents and tangencies are unsupported and must be rejected explicitly.

## Worked decompositions

The compact words below abbreviate polygon boundaries in their positive
boundary direction. `a` and `-a` pair with reversed boundary directions.
`B0`, `B1`, etc. are unpaired sides with the corresponding boundary ID.
A boundary side may begin and end at the same *recovered* vertex. Split any
word shorter than three sides using extra boundary subdivisions. Splitting
sides must preserve their boundary IDs, not introduce new boundary components.
The counts below use the compact words before such optional subdivision.

| Surface | One disk's side word | Selected cut pairs | Recovered (V,E,F), chi | Complement |
| --- | --- | --- | --- | --- |
| Disk | `B0a B0b B0c` (all ID B0) | None | (3,3,1), 1 | One disk |
| Annulus | `a B1 -a B0` | a | (2,3,1), 0 | One disk |
| Marked disk | `B0 a -a` | a | (2,2,1), 1 | One disk; mark on slit boundary |
| Torus | `a b -a -b` | a,b | (1,2,1), 0 | One disk |
| Genus two | `a b -a -b c d -c -d` | a,b,c,d | (1,4,1), -2 | One disk |
| Pair of pants | `a B1 -a B0a c B2 -c B0b` | a,c | (4,6,1), -1 | One disk |

For the marked disk put mark M at the corner between `a` and `-a`.
In the full surface this is the interior tip of a slit, with a circular
vertex link. After omitting the a pairing it has an interval link and lies
on the complementary disk boundary. Leaving a paired instead yields a disk
with an interior mark: topology passes but the cut-system certificate fails.

In the annulus, a joins distinct boundary components B0 and B1. No selected
cuts leaves the reconstructed annulus intact: genus 0, two boundaries.
The pair-of-pants arcs a and c separately join B1 and B2 to B0. Selecting only
a leaves one annulus; selecting neither leaves a three-boundary sphere.
The two B0 side occurrences must recover one boundary cycle, not two IDs.

The torus a,b loops meet at the single recovered vertex. Its cyclic order
is alternating. Selecting only a leaves an annulus; selecting neither leaves
a closed torus. The genus-two example is a polygonal spine with one high-valence
vertex. It is a topology fixture, not the future numbered chain preset and
not a claim that all its parent loops are pairwise transverse at that vertex.
Use its edges as an unlabelled cut graph; subdivide/refine before claiming a
particular chain realization. The P4 standard chain needs its own incidence
and presentation binding, verified by the same validator.

For a multi-disk positive fixture split the disk by one properly embedded
boundary-to-boundary cut: two triangular faces with one reversed paired side
and all other sides labelled B0. The full quotient is one disk. Removing that
pair produces two disks, each accepted. This prevents an accidental one-disk
restriction in the validator.

## Reconstruction and certification algorithm

1. Validate finite records, uniqueness and references. Every side occurs in
   exactly one face and belongs to exactly one reversed pair or boundary
   declaration. A side cannot pair with itself or have multiple partners.
   Reject an orientation-preserving pairing rather than silently fixing it.
2. Make separate corner occurrences for every face. Pairing sides identifies
   the start corner of each with the other's end, and vice versa. Union-find
   recovers vertices; face adjacency through paired sides recovers components.
3. Check vertex links, not just corner counts. Each polygon corner contributes
   a link interval whose ends correspond to its adjacent sides. Each side
   gluing pairs the appropriate link ends at its two endpoints. Every recovered
   vertex link must be one circle (interior) or one interval (boundary).
   Disconnected links, branching and inconsistent boundary incidence are
   invalid. Recover the cyclic/linear edge-end order from this construction
   and compare declared incidences up to cyclic rotation, preserving orientation.
4. Traverse unpaired sides through those boundary vertex links to enumerate
   actual boundary cycles. In the full surface each cycle has exactly one
   declared boundary ID; an ID labels exactly one cycle. Reject mixed IDs,
   missing IDs, and an ID reused on separate cycles. Recover marked vertices
   and face-interior marks and compare the complete mark inventory.
5. For each component compute V-E+F from the quotient cells. With validated
   orientable manifold structure and enumerated boundary cycles, recover
   genus from `2 - 2g - b = chi`. Require a nonnegative integer genus and
   compare the full connected surface against SurfaceSpec. These counts are
   a cross-check after gluing and link validation, not a stand-alone proof.
6. Validate cut-edge membership, parent walks, endpoint incidences and declared
   genuine intersections against the recovered cellulation. Projection-only
   crossings must not identify vertices. For a requested rendered certificate,
   require a compatible checked PresentationBinding; absence is unsupported.
7. Repeat reconstruction with selected pairings removed. Their side copies
   are new cut boundary, retaining parent edge and side IDs. Auxiliary pairs
   stay glued. Recompute corner equivalence and links from scratch: full-surface
   vertex equivalence cannot be reused after cutting. Original boundary labels
   may now split or share a complementary boundary cycle, so do not apply
   the full-surface one-ID-per-cycle rule to the complement.
8. Report each complementary component's genus, boundary cycles and interior
   marks. Accept only genus 0, exactly one boundary cycle and no interior
   marks in every component. A formerly interior marked vertex is permitted
   precisely when all of its resulting copies have boundary interval links.
   Give stable face/edge/mark IDs in failure diagnostics.

The initial implementation must bound input size explicitly. It does not need
an exponential search: the supplied cellulation and cut selection determine
all quotients. Never silently repair pairings, infer an absent cut, or discard
marks to make validation succeed.

## Negative fixtures required before P3 completion

| Fixture | Required diagnostic |
| --- | --- |
| Annulus with no selected seam | Residual component has two boundaries |
| Torus with no cuts | Residual genus 1 and zero boundaries |
| Marked disk with a left auxiliary | Interior mark M remains |
| Declared torus incidence has nonalternating a,b ends | Vertex rotation does not match recovered link |
| Missing, duplicate or same-direction side pairing | Unresolved/nonmanifold/nonorientable gluing, before certification |
| Pair of pants with only a selected | B2 remains unconnected by cuts; residual annulus identified |
| Two genuine boundary cycles assigned the same boundary ID | Boundary identity mismatch |
| Two projected paths intersect, but no common cellulation vertex | Cannot use projection crossing as genuine incidence |
| Correct aggregate Euler count with invalid vertex link | Reject invalid local surface structure |
| Cellulation reconstructs a torus but SurfaceSpec requests a disk | Full surface topology mismatch |

Some invalid inputs fail earlier than the residual-topology phase. Reports
must distinguish invalid cellulation, mismatched requested surface, incomplete
cut system and unsupported presentation binding. No Boolean field such as
`face_is_disk` or caller-supplied residual genus can substitute for computation.

## Route coordinates reserved for P4

A crossing locator identifies a cut edge (not only its parent number), the
source face-side occurrence, and an ordered crossing slot on that edge.
Pairing transports the slot to the opposite side in reversed boundary order.
Starting face, oriented crossing sequence and terminal/closing locator determine
which disks contain the intervening pieces. Repeated visits are retained.

For the torus word, crossing source occurrence a arrives at occurrence -a;
both happen to belong to the same face. For the split-disk example it arrives
in the other face. Thus a face change is not a substitute for a side locator.
At intersecting parent cuts, a number may name several segments: the convenient
number-only syntax is accepted only if the omitted segment and source side
are uniquely determined. Otherwise report candidate locators; never choose one.

An arc endpoint specifies a boundary-side occurrence and position, or a marked
vertex explicitly admitted as an endpoint. Initially boundary positions are
fixed normalized parameters in the open side interval. Movable endpoints and
vertex passage require a later explicit contract. Closing data must match both
face and position. A named cut is requested through a separate named-curve
reference, not an empty itinerary. No isotopy classification or minimal
intersection promise follows from these coordinates.

## Implementation sequence

P3a specified the model. P3b now implements full and partial gluing, vertex
links, boundary cycles, mark copies, parent walks, transverse intersections,
and diagnostics. All table examples and failure categories are executable in
`tests/test_cut_systems.py`. P4 supplies standard chain constructions, numbered
diagnostics and presentation bindings; P7 extends TikZ after SVG integration.

## Running the implementation

```powershell
python examples/cut_system_examples.py
python -m unittest discover -s tests -p test_cut_systems.py -v
```

The example command emits JSON. The checked-in result is
[cut-systems.json](../examples/output/cut-systems.json). Seven fixtures each have
a selected-cut and an uncut report. The disk passes with no cuts, as does the
split disk when its diagonal is left auxiliary. Other uncut fixtures fail with
the computed residual topology or interior mark. An uncut marked disk remains
a topological disk, which is why mark validation is a separate check.

For an internal torus certificate:

```python
from surface_diagrams.cut_systems import (
    Cellulation, Face, SidePair, SurfaceSpec, validate_cut_system,
)

cell = Cellulation(
    faces=(Face("F", ("a", "b", "-a", "-b")),),
    pairs=(SidePair("a", "a", "-a"), SidePair("b", "b", "-b")),
    cuts=("a", "b"),
)
report = validate_cut_system(cell, SurfaceSpec("torus", genus=1))
assert report.certified
assert report.complement[0].genus == 0
assert len(report.complement[0].boundary_cycles) == 1
```

A corner locator names its outgoing side occurrence. Pair edge-end labels use
`(pair_id, "start")` or `(pair_id, "end")` relative to `SidePair.first`.
Boundary edge-end labels use the unpaired side ID. Link order follows polygon
corner intervals from incoming to outgoing sides and crosses the glued outgoing
side to the next corner. Interior order is compared up to rotation, preserving
this orientation; boundary order is an interval with fixed first and last ends.
`VertexIncidence.corners`, when supplied, asserts the exact recovered corner
class. It never creates extra identifications.

The side-pairing schema forbids pinches by construction: corners are distinct
until their side gluings identify them. Links are nevertheless reconstructed
and checked. A negative fixture asserting a merged vertex with disconnected
interval links fails `vertex_identity`, despite the unchanged disk Euler count.
Duplicate seam use and invalid orientation fail before reconstruction. No
caller-supplied face or vertex topology is trusted.

A face-interior mark denotes a distinct named point in that face, with no
geometric coordinate promise. A vertex mark is transported to every corner
copy after cutting. All those copies must be boundary points. Distinct mark
IDs on the same full-surface vertex are rejected.

The initial bound is 4096 faces, 16384 side occurrences, 16384 records per
collection, 16384 parent edge visits, and 65536 incidence entries. Inputs must
use the typed records and finite sequences. A connected orientable surface is
required. No arbitrary extra corner gluing, nonorientable surface, shared parent
edge, tangency, shared parent endpoint, triple parent intersection, or rendering
binding is accepted. An arc cannot revisit its start vertex; same-boundary arcs
with distinct endpoint vertices remain representable. Empty parents certify
only the selected unlabelled graph; if parents are present every selected edge
must have exactly one parent. These explicit limits do not weaken the older
planar noncrossing router.

Verification on September 12: 26 topology tests and all 67 preexisting tests
pass on Python 3.9.7 and 3.12.14. Coverage includes all genus-two cut subsets,
spines through genus eight, transverse and tangent parent loops, false projection
vertices, auxiliary cell subdivision, reversed edge references, reordered faces,
and preservation of every marked-vertex copy. JSON report regeneration is
deterministic. No SVG geometry changed, and no new visual certification is
claimed at this stage.
