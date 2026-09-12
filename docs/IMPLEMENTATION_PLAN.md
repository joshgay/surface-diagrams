# Surface diagrams: reference-driven implementation plan

This is the controlling plan for the next development cycle. Read it together
with [HANDOFF.md](HANDOFF.md) and the [reference index](../Figures/README.md).
Richard's latest instructions supersede the older broad roadmap where they differ.

## Current checkpoint

- Baseline: commit `1af585c` (merged documentation), package `0.1.0a2`.
- Verified at planning time: all **44 tests pass** using the existing `.venv`.
- Already implemented: planar dots and mixed rows, fixed custom dot positions,
  planar arcs/loops in horizontal cut coordinates, direct default arcs,
  higher-genus schematics, Type I/II boundaries, SVG/TikZ, LaTeX inclusion, CLI.
- Already implemented does not mean visually approved: the current higher-genus
  silhouettes and handle openings must be redesigned using the supplied SVGs.
- P1 implements the reference-based genus presentation, including the September
  11 refinement: independent above/below and left/right views, overlapping hole
  edges, direct end collars, and roomier side pairs. See HANDOFF.md for checks.
- P2 now implements circular planar holes, rim endpoints, clipping, clearance,
  and 14 examples. The saved partial patch has been incorporated and removed.
  P3 now implements the internal abstract-cellulation validator, parent incidence
  checks and worked examples. P4 has started with standard chain cellulations; P5-P8 remain. The P3 checkpoint had 93 tests passing on
  Python 3.9/3.12; see HANDOFF.md and docs/cut-systems.md for the supported scope.
  An abstract certificate is not a rendered presentation certificate.
- Existing TikZ/LaTeX support stays available. Extend it for the new features
  **only after the SVG geometry, topology, routing, examples, and tests work**.

| Stage | Work | Status | Depends on |
| --- | --- | --- | --- |
| P0 | Preserve references, inspect priorities, write portable plan | Complete |
| P1 | Replace default higher-genus visual geometry | Complete | P0 |
| P2 | True circular planar boundaries, horizontal arrangement first | Complete | P0 |
| P3 | Specify and validate disk-complement cut systems | Complete for explicit abstract cellulations; presentation binding remains P4 | P0 |
| P4 | Standard numbered genus cut systems and arc/curve routing | In progress: closed-genus mesh binding, smooth chains and disk-route projection | P1, P3 |
| P5 | General planar configurations, cut systems, daisy overlays | Not started | P2, P3 |
| P6 | Secondary surface presentations and complete SVG integration | Not started | P4, P5 |
| P7 | Extend TikZ/LaTeX for all new features | Not started | P6 |
| P8 | Release audit, documentation, packaging, check-in | Not started | P7 |

Recommended execution order: P1, P2, P3, P4, P5, P6, P7, P8. Each stage ends
with a useful, tested checkpoint. Do not mark a stage complete merely because
its API exists or its images look plausible. P4 and P5 are the substantial
mathematical implementation stages; split them into commits as described below.

## Requirements that must survive a handoff

1. The ordinary constructor must produce the prettiest standard diagram.
   Users supply mathematical content (genus, boundaries, marks, curves), not
   a long list of spacing, neck, hole, or curvature settings. Compute attractive
   proportions automatically. Advanced overrides are optional and grouped.
2. Primary nonplanar visual references, in Richard's stated order:
   `D3HyperellipticLifted.svg`, `D2AHyperellipticSurfaces.svg`,
   `E2MCKHOddGenusLifted.svg`, `E2MCKHOddGenusLiftedWithBoundaries.svg`.
   Secondary presentations: `E3BMCKHEvenGenus.svg`,
   `D1HyperellipticTorus.svg`, `F3BBKHGenusTwo.svg`.
3. Support arcs and closed curves on standard nonplanar and nonstandard planar
   surfaces. Richard clarified that this means **arcs and closed curves**, not
   shading or highlighting subsurface regions.
4. Standard genus presentations get an automatic numbered chain of closed
   curves, supplemented by arcs to boundary components and marked points as
   necessary. Custom configurations declare their cut system when configured.
5. Cutting along the entire system must leave a union of disks with **no
   interior marked points**. Marks on the resulting boundaries are permitted.
   Residual annuli, positive-genus pieces, or interior marks are failures.
6. Supply both ordinary diagrams and diagrams showing the numbered cut system,
   and include the latter in the complete test suite. Numbering must remain
   stable when only styling, scale, or layout parameters change.
7. Add actual circular planar boundary components, first in a horizontal row,
   then in more general configurations inspired by `C3ADaisyRelation.svg`.
   Keep gray/colored dot presentations available. A hollow marker for a marked
   point is not automatically a boundary component; topology follows the model.
8. Daisy diagrams and chain systems contain intended intersections. Support
   these explicitly; preserve the existing default noncrossing contract for
   the old planar multicurve API. Do not silently weaken its checks.
9. Keep the package small and drawing-focused. No mapping-class equality,
   factorization search, homology engine, automatic lift calculation, arbitrary
   SVG topology inference, or general 3-D renderer is requested in this cycle.
10. Preserve all 114 supplied SVGs as references, including apparent variants
    and duplicates. Archiving them does not mean reimplementing every relation
    or every panel in all 114 files in this cycle.
11. September 11 viewing requirements: support independent above/below and
    left/right views. D3 is below/right; D2A is above/right. Facing boundaries
    show full rims, opposite boundaries have hidden inward halves. Handle holes
    have a longer near edge and a partially occluded shorter far edge. Future
    overlaid arcs and closed curves must use the same local visibility convention.
    Keep the original reference contours as the visual standard: direct smooth
    left attachments, an actual right collar, rounder transitions, and broad,
    well-separated side pairs on a taller E2-style body.
12. Stop at tested, committed, pushed checkpoints with a precise portable handoff
    before compute is exhausted. Preserve unfinished work explicitly; do not
    leave a future AI to recover its status from the transcript.

## Visual specification from inspected sources

The primary sheets contain several panels, so reproduce their visual language
and finite representative surfaces rather than copying the complete page as a
single model. In D2A, the bottom lifted-surface panel is especially relevant.

- Use a low horizontal body, smooth long upper/lower contours, shallow oval
  handle openings, and delicate black outlines. Current tall pointed lenses
  and scalloping at every handle are not the default to preserve.
- Keep collars short and rims broad enough to read as openings. Top/bottom and
  side/end boundaries require their own natural attachment directions.
- Solid front portions and dashed back portions occur in both curves and rims.
  They carry projection meaning; dashing must not depend only on vertical
  screen position or on arbitrary path order.
- Use restrained outline weights and magenta curve accents. Green/red curves
  in reference sheets demonstrate distinctions; retain configurable colors.
- Preserve white space for curves around and between handles. Build genus 1,
  2, 3, and 5 as finite explicit examples before adding any abbreviated display.
- Ellipsis marks in the references stand for omitted repeated pieces.
  A finite model must have actual genus and boundary counts. Do not invent
  topology from the number of holes drawn on an abbreviated sheet.
- The D1 torus has a much larger central oval opening. E3B has a more undulating
  body and angled side collars. F3B has more rounded lobes and boundaries at
  handle openings. These are optional presentations, not default parameters.
- C3A contains both a fan-like arrangement and a radial daisy arrangement,
  actual circular boundary holes, and genuinely intersecting colored loops.

## Mathematical design before routing code (P3)

### What is a cut system here?

Use Richard's definition above. The permitted numbered system can contain
intersecting closed chain curves and boundary arcs. Internally it is an
embedded graph on the surface, split at its genuine intersections, together
with the surface boundary and incidences of marks. Do not impose the narrower
convention that every cut must be disjoint or that the complement is one disk.

A crossing in the drawing is not necessarily an intersection on the surface:
front and back sheets can overlap in projection. Store that distinction.

### Minimal representation to prototype

Use a small explicit disk decomposition with oriented sides and pairing data
(equivalently a suitable combinatorial map), plus an embedding in the supplied
surface presentation. Record stable surface/boundary/mark IDs, vertices and
cyclic order, graph edges, numbered parent curves/arcs, complementary faces,
and front/back chart transitions. Keep visual control points separate.

Do not accept an arbitrary rotation system, attach disks to every face, and
then declare it a cut system for the requested surface. Validate the recovered
surface against the requested genus, boundary components, marks, and incidence
data, and against the supplied presentation's cellulation/embedding. Custom
topology must be explicitly supplied or derived from that representation;
pixels and names such as `face_is_disk=True` are not a certificate.

Required validation:

- All references resolve; side pairings, orientations, boundary cycles, and
  vertex links describe an actual orientable surface with the intended topology.
- Distinguish genuine boundary sides from paired cut sides. Recover the intended
  connected components, genus, boundary IDs, and marked-point incidences.
- Cut along the embedded graph and enumerate complementary components. Each
  must have genus zero, one boundary component, and no interior marked points.
- Cross-check Euler characteristic against the intended surface. A correct
  total Euler characteristic alone is not a sufficient validation.
- Reject unsupported configurations explicitly; do not claim validation when
  only geometric sampling or a curve-count heuristic was performed.

### Numbering and route coordinates

Standard presets number chain curves left to right, then supplementary boundary
arcs in a documented stable boundary order. Custom presets set the order once.
The usual `2g+1` chain is a candidate, not a universal proof of completeness;
check genus-one conventions, boundary arrangements, and marked points.

Preserve a convenient list-of-numbered-crossings interface where unambiguous.
A parent curve number alone may be ambiguous when it meets other cuts. The
internal route must identify an oriented cut segment/side, crossing order,
starting face or boundary endpoint, and terminal/closing data. Resolve omitted
fields only when unique; provide an explicit locator for ambiguous cases.
Specify the convention in `docs/cut-systems.md` with worked examples before
freezing public class names. Never guess which face, side, or winding was meant.

Route inside the cut disks, then glue and project. Match both sides of every
crossing and preserve the entire itinerary, including repeated visits. Display
curves that coincide with a named cut using an explicit named-curve reference
or a documented canonical offset, not an invented empty crossing itinerary.
Routes must avoid cut vertices unless vertex incidence is explicitly supported.
Boundary endpoints lie on rims, not in hole centers. Document whether endpoint
position is fixed or movable along the boundary and how winding is recorded.

For disjoint families, reject unintended crossings. For intentional overlays,
route each curve as an embedded curve and record its intersections with other
curves; initially support the chain/daisy cases and explicit crossing data.
Do not add a blanket `allow_crossings` switch that conceals routing failures.
Do not promise isotopy classification or minimal intersection numbers merely
because routes can be drawn.

Background: [filling systems and decorated fat graphs](https://arxiv.org/abs/1503.04559)
support the combinatorial viewpoint. Terminology varies: some definitions allow
peripheral annuli ([example](https://arxiv.org/abs/1906.02577)); Richard's required
disk-only complement takes precedence here.

## Stage deliverables and acceptance gates

### P1: Attractive default nonplanar geometry

- Isolate a reusable surface presentation from topological surface data.
  Revise `genus.py` using D3/D2A/E2 proportions; use existing APIs where sensible.
- Add correct rim visibility and front/back contour pieces without background
  paint hiding errors. Keep short collars and auto-sized curve corridors.
- Examples: closed genus 1/2/3/5; Type I slots; top/bottom and left/right pairs;
  a D3-style many-boundary example; an E2-style mixed end/top/bottom example.
- For every preset show a no-tuning constructor and, separately, one advanced
  override. Boundaries and genus are mathematical content, not appearance knobs.
- Gate: inspect generated/reference comparisons; test continuity, boundary counts,
  symmetry where specified, spacing, scale, transparency, and invalid sizes.
  Keep a visual-review checkpoint before spending effort on curve routing.

### P2: Actual circular planar boundary components

- Add one simple boundary presentation choice and useful automatic circle sizes.
  Preserve existing dot-mode behavior and point/boundary identity.
- Make the physical boundary radius participate in containment and clearance.
  Curves and cut arcs end on the rim and never travel through a hole interior.
- Adjust path generation/clipping so transparent circular holes stay empty;
  a white disk pasted over a curve is not sufficient.
- Examples: horizontal circle row; mixed circles/marked points; empty disk;
  annulus; arcs from/to outer and inner rims; loops around circles; dot/circle
  comparison; one explicit radius override. General layouts wait until P5.
- Gate: endpoint-on-circle checks, no-hole traversal, straight adjacent default
  behavior and explicit up/down, no masks on colored backgrounds, containment,
  too-large-hole errors, regression coverage for existing dotted diagrams.

### P3: Cut-system specification and validator

- First commit: worked disk, annulus, marked disk, torus, genus-two and
  pair-of-pants decompositions; `docs/cut-systems.md`; proposed minimal data types.
- Second commit: implement orientation/gluing/incidence validation and reports
  identifying residual topology and interior marks.
- Include negative fixtures: incomplete annulus cuts, an uncut handle, a disk
  with an interior mark, wrong cyclic order, mismatched seam, missing boundary
  connection, and a projection crossing falsely counted as a vertex.
- Gate: reconstruct the intended surface, certify every complementary disk,
  verify marks lie on cut boundaries, and explain specific failures. Do not
  build the generalized router until these fixtures pass.

### P4: Standard genus cuts and routes

- P4a: build automatic cut systems for the default genus/boundary/mark presets.
  Use the chain plus necessary supplemental arcs. Verify completeness rather
  than assuming any placement of the same number of curves will work.
- P4b: add a cut-system display with stable numbers, an ID legend, optional
  orientation marks, and views of the complementary disks. Pure surface output
  stays uncluttered; one option produces the complete numbered diagnostic view.
- P4c: implement disk-by-disk routes and gluing, then front/back projection.
  Support closed curves, arcs between boundaries, return arcs to the same
  boundary with explicit endpoint data, marked endpoints, repeated crossings,
  disjoint multicurves, and deliberate chain intersections.
- Examples: every chain member individually; complete numbered chain; completed
  cut graph including boundary arcs; basis-following curve; curve traversing
  multiple handles; separating and nonseparating loops where certified; boundary
  arcs with different itineraries; front/back visibility; invalid itinerary.
- Gate: all P3 certificates, stable numbering, paired crossings, route closure,
  exact endpoints, embeddedness where promised, correct hidden segments, no
  accidental hole traversal or lost/reordered visits. Reversing traversal should
  preserve an unoriented curve; styling must not change its combinatorial route.

### P5: Nonstandard planar layouts and intersecting daisy curves

- P5a: configure a planar arrangement with true boundary circles/marks and its
  cut system once. Standard row and a radial/daisy preset supply that system
  automatically. General custom layouts require an explicit valid system.
- Use the same disk decomposition and router as P4; do not create a second
  topology/itinerary language just for nonhorizontal planar pictures.
- P5b: implement intended intersections between overlay curves, using the
  explicit intersection model from P3. Preserve existing noncrossing defaults.
- Examples: horizontal daisy first, then finite fan and radial examples based on
  C3A; irregular circle layout; mixed circles and marked points; disjoint family;
  intersecting daisy family; each layout with/without numbered cuts and with a
  representative route. Show certified cut disks for each configuration.
- Gate: disk-complement validation, correct route gluing, rim endpoints, no
  interior marks, preserved IDs under movement, intended versus unintended
  intersections, and meaningful failure if moving holes invalidates the system.

### P6: Secondary presentations and complete SVG coverage

- Add the E3B even-genus presentation, D1 oval torus, and F3B rounded genus-two
  presentation with handle-opening boundaries. These are presentation presets,
  not separate mathematical curve systems or alternate meanings of genus.
- Bind each preset to valid cut-system and projection data. Include ordinary,
  numbered-cut, and arc/curve overlay examples for every supported presentation.
- Finish uncovered primary-reference cases before expanding secondary controls.
- Gate: same topological route can be rendered in compatible presentations
  without changing its itinerary; certify each preset; test projection-only
  overlaps and boundary attachments. Review the full SVG gallery visually.

### P7: TikZ/LaTeX last

- Extend shared primitives only as needed for clipping, holes, visibility,
  labels, and overlay ordering. Reuse the finished SVG layout and route model.
  Do not duplicate topology or routing inside the TikZ exporter or LaTeX macros.
- Preserve existing export tests throughout earlier stages. If a new model is
  not supported yet, raise a specific error instead of producing wrong TikZ.
  Shared improvements reaching both backends naturally need not be undone.
- Generate and compile TikZ counterparts for **every new example**, including
  numbered cuts, complementary disks, intersections, custom layouts, and all
  secondary presentations. Include multiple diagrams in one LaTeX document.
- Gate: geometry/ID parity, proper scaling of strokes/dashes/text, correct masks
  or clipping on nonwhite backgrounds, no package/style leakage, and visual
  comparison of compiled output. Record actual compiler and Python versions.

### P8: Complete and publish the milestone

- Run the complete old and new test suites, regenerate all examples, check
  regeneration determinism, validate packaging/installed CLI, and inspect images.
- Update README to show the shortest attractive usage for each standard case;
  move uncommon controls into dedicated documentation. Keep alpha limitations
  honest and map each request to implemented examples and tests.
- Run `git diff --check`; review changed/untracked files; commit scoped changes.
  Preserve online edits when merging. Push only within the existing authorized
  repository workflow, never force-push. Report actual commit and CI status.
- Do not declare the cycle complete until P1-P7 gates pass. If interrupted,
  record the exact failing case and next command instead of lowering the gates.

## Example and test policy

Keep a registry with scenario ID, source reference/panel, minimal constructor,
topological expectations, route/cut IDs, SVG paths, numbered-cut output, and
(after P7) TikZ path. Derive gallery counts from the registry; don't keep a
hard-coded assertion that the gallery must forever contain exactly 48 examples.

For each supported configuration include: plain surface, numbered cut system,
at least one arc/closed curve, and a certificate or disk view in its tests.
Surface-only P1/P2 snapshots may precede their cut-system counterparts, but the
feature family is not fully complete until those counterparts exist. Use
cross-product samples of genus, boundary count/placement, and marks, not only
one visually attractive fixture. Test expected failures alongside successes.

Combine exact combinatorial tests, geometric checks and rendered visual review.
Pixel snapshots alone cannot prove topology; Euler counts alone cannot prove
every face is a disk; geometric samples alone cannot prove embeddedness.
Use certified construction or exact/controlled geometry where a proof is needed,
and state precisely the limits of any bounded search or numerical tolerance.

## Updating this plan at every checkpoint

Change status to in progress when starting a stage. Before a commit or handoff,
record completed substeps, files, tests/versions, generated examples, unresolved
failures, decisions and their reason, and the exact next step in HANDOFF.md.
Use `blocked` only for a real external dependency or mathematical decision that
requires Richard's input; compute exhaustion means checkpoint and hand off.
Routine appearance choices should follow the references without repeated approval.
Ask Richard only before choosing between different mathematical interpretations.
