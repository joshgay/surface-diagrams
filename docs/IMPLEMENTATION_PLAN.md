# Visualization-first development plan

Controlling plan, updated September 12, 2026. Richard's latest instruction makes
**all requested visualizations, including cut systems, higher priority than the
calculation engines**. The earlier R0-R7 calculation-led sequence is superseded.
The shared core/calculation/rendering separation remains useful, but building a
general exact core is not a gate before improving drawings.

Read the [tutorial](TUTORIAL.md), [architecture](ARCHITECTURE.md),
[research notes](RESEARCH_NOTES.md), and [handoff](HANDOFF.md). The older
[P0-P8 visual plan](archive/IMPLEMENTATION_PLAN-visual-cycle-2026-09-12.md) preserves
reference-specific acceptance criteria. Preserve all original reference SVGs.

## Surface spacing guideline (Richard's latest refinement)

Use roughly comparable visible widths for the strips between consecutive genus
holes, between a hole and the outer end, and between holes and the top/bottom
surface edges. Boundary openings should have a comparable visual scale. Exact
equality is unnecessary; avoid a squeezed strip next to an otherwise roomy
surface. In particular, a Type I end rim must not be pulled inward by an adjacent
top/bottom collar. Measure the strip from the rim's inner edge to the nearest
hole, and compare it with the inter-hole gap and opposite end clearance.

Immediate work: correct both ends and verify all four viewing directions,
including the current four-view gallery fixture, mixed boundaries and changed
proportions. Preserve boundary IDs, actual contour attachments and transparency.
A gently undulating top/bottom contour that follows the genus holes is a desired
minor refinement, explicitly lower priority than spacing, endpoint controls and
cut-system drawings. No exact scalloping amplitude is prescribed now.

After this correction continue V1-V3 visual work; calculation engines remain later.

## User-facing priorities

| Use case | Visual deliverable first | Calculation deliverable later |
| --- | --- | --- |
| 1: planar mapping classes | Arcs/loops, colored reference cuts and supplied images, intersecting families, vertical factors and adjacent braids | Automatic twist/half-twist actions, identity/equality checks and covering correspondences |
| 2: standard nonplanar surfaces | Standard rainbow cut systems, arcs/loops, all standard boundary placements, vertical supplied action states | Automatically act on a rigid reference system and compare products |
| 3: transformations of products | Before/after Hurwitz moves, substitutions and admissible cyclic shifts with explicit supplied factors | Compute transformed support curves and verify the relation/equivalence involved |
| 4: homology and fundamental group | Colored basis and supplied matrix/generator illustrations | Exact homology, basis changes, induced actions, fundamental-group presentations |
| 5: Lefschetz fibrations | Factorizations with vanishing-cycle labels and space for a calculation trace | Signature and other invariants under explicit fibration hypotheses |

Braids are also drawings: do not defer their visual representation until braid
normal forms are implemented. The same applies to manually specified factor
substitutions, cut-system images and cover correspondences.

## Visualization milestones

| Stage | Work | Acceptance gate |
| --- | --- | --- |
| V0: tutorial and immediate corrections | Runnable illustrated tutorial; remove the nonsensical extra handle arc; document actual input conventions and gaps | Every displayed recipe runs; no pretend calculation APIs; removed option absent from active gallery |
| V1: planar diagrams | Left/right boundary anchors for curved arcs, intersecting families, colored cut systems, labels and input previews | Point-to-point, boundary-to-point and boundary-to-boundary examples; standard endpoints at left/right rims; preserve route and color identities |
| V2: nonplanar diagrams | Finish standard Type I/II cut bindings and routes; smooth practical route drawing; more accessible numbered-side locators | All requested standard templates carry their cuts and curves with correct front/back geometry; both surface and cut-disk previews agree |
| V3: factors and visual transformations | Thesis-style vertical factor/action rows, adjacent braid/base/lifted views, supplied Hurwitz/substitution/cyclic-move sequences | Stable factor IDs, grouping and cut colors across rows; explicit multiplication convention; accurate supplied correspondences |
| V4: exports and further visual families | SVG/TikZ parity for shipped visuals; requested Heegaard, bridge, trisection/relative and Kirby data/drawing examples | Each diagram family has the necessary labels, crossings, framing or boundary data; representability is distinguished from validity/equivalence |

V1-V3 can be improved incrementally together when a single worked example needs
them. Calculations must not pull effort away from unfinished requested visuals.
Each batch names a concrete drawing and its acceptance examples, rather than
attempting every future diagram family in one universal abstraction.

## What this tutorial delivery adds

- Eleven main SVG tutorial figures, one detailed cut-disk SVG and ten TikZ counterparts; circular-hole
  TikZ remains unsupported, and new TikZ outputs are not yet TeX-compiled here.
- `ColoredCurve` and `PlanarDiagram`: disjoint colored families by default;
  independently routed overlays with explicit `allow_intersections=True`.
- `BraidDiagram`: signed crossings with transparent underpass gaps and persistent
  strand colors/labels. This draws words; it does not solve equality.
- `Panel` and `Figure`: aligned columns and vertical rows, including mixed genus,
  planar, disk-chart and braid panels, using the existing exporters.
- Rainbow numbered genus cut systems. The old extra handle arc, its constructor
  option and gallery example are removed.

Current limitations are explicit: overlay mode does not certify pairwise
intersections and may produce coincident pieces; curved circular-boundary arcs
still land where the old ellipse trimming meets the rim; Type I/II route bindings
are unsupported. Mesh side IDs remain technical and chart-dependent. Automatic
mapping-class action, Hurwitz transformations, homology and signature engines
are not implemented by these presentation features.

## Endpoint and identity requirements

Most ordinary arcs join marked points. Cut systems additionally need
boundary-to-point and boundary-to-boundary arcs. Standard boundary attachments
should be at the leftmost/rightmost rim positions, not top/bottom. Nonstandard
configurations may later request arbitrary explicit anchors. Treat a circle
rim, a dot marker and a notched boundary as different endpoint conventions.

Keep stable cut IDs and rainbow colors across supplied action states; do not
reassign a cut's color from its changing position or endpoint order. Labels remain
necessary for larger systems. Factor identity is separate from its support curve,
exponent, product, and its position in the displayed sequence.

A drawing of a twist-support curve does not apply the twist. A caption does not
prove identity. The image-of-reference-system/torsor idea remains the proposed
future equality mechanism when its stabilizer is proved trivial, with a supported
isotopy/normalization algorithm. An ordinary Heegaard meridian system does not
have that rigidity merely because it is called a cut system.

## Later calculation roadmap

| Stage | Input and deliverable | Required care |
| --- | --- | --- |
| C1 | Exact curve actions, braids, mapping classes and reference-system images | Declare endpoint/isotopy conventions and supported normalization domains; compare known relations and nontrivial actions |
| C2 | Hurwitz/substitution checks, factorizations, general cover/lift machinery | Distinguish same product, conjugacy and Hurwitz equivalence; cyclic shifts need conditions; liftability and boundary admissibility are separate |
| C3 | Homology, basis changes and surface fundamental-group presentations | Exact integer matrices, basepoints, ordered oriented bases and retained versus removed marked points |
| C4 | Lefschetz signature and related invariants | Oriented fiber/base, vanishing cycles, signs, global monodromy and completion data; begin with a referenced algorithm and known examples |

Signature computation is a concrete algorithmic prospect, not a promise that
arbitrary factor lists specify a Lefschetz fibration. Ozbagci and the
Cengel-Karakurt reformulation are candidates recorded in RESEARCH_NOTES.md.
Computing a presentation for a specified surface fundamental group is feasible;
recognizing arbitrary 4-manifold groups is a separate problem and not promised.

## Architecture and research that remain useful

Keep one repository and distribution, with core records shared by rendering and
calculation. Introduce records only as actual drawings/operations need them; avoid
a package-wide move or a plugin framework. Coordinate investigations (normal
strands, Dehn-Thurston, Dylan Thurston's note) can inform future contracts without
blocking present visualization work. Richard's separately reported work is still
to be located; do not overwrite it or claim to have reviewed it.

Preserve the notched-boundary proposal: allowed fractional rotations can admit
lifts excluded by pointwise-fixed boundary conventions. Retain full twist and
endpoint transport, and specify isotopies before asserting a relation. Covers may
have arbitrary genus bases and marked points; separate their eventual computation
from a supplied diagram of a concrete example.

Heegaard/trisection systems reuse surface curves; bridge and Kirby diagrams also
need tangles/crossing/framing data. Relative versions need explicit structures,
not a universal `relative=True`. Their visualizations do not require automatic
manifold recognition or a move-search engine.

## Checks and completion discipline

Preserve reference geometry, topology, transparency and endpoint requirements.
Run relevant tests and inspect regenerated images. Verify TikZ only after SVG
geometry is correct; compile examples when a TeX toolchain is available. Keep
unsupported cases explicit. Continue scoped commits and pushes under Richard's
standing authorization, and update HANDOFF.md with actual progress.
