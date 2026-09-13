# Handoff: surface-diagrams

## Local browser editor, September 13

Added an immutable version-1 `DiagramDocument` JSON recipe API and a dependency-
free, loopback-only browser editor. The editor supports horizontal planar point/
boundary rows, arc/loop itineraries, signed braid words, transported strand IDs,
labels, whole-recipe undo/redo, JSON open/save, and SVG/TikZ/reproducible-Python
downloads. All geometry remains in the existing library. See [EDITOR.md](EDITOR.md)
for usage, schema limits, security boundaries, and the manual acceptance checklist.

The original 171 Python tests plus 36 document/HTTP tests pass (207 total), as do
8 JavaScript controller tests using a minimal DOM double. Both document
kinds reproduce exact SVG/TikZ output when their generated Python is run. The
hosted browser could not open the local URL (`ERR_BLOCKED_BY_CLIENT`), so visual,
pointer, and file-dialog testing remains pending. Do not describe this as a
visually verified or release-ready editor. No Godot or Tiny Bubbles Lab deployment
is included in this contribution.

## Ordered factor/action diagrams, September 13

New presentation APIs: `FactorPanel` stores a distinct factor ID, support panel,
nonzero signed exponent, optional complete braid block, group label and supplied
after-state. `FactorizationDiagram` lays out application-ordered rows bottom to
top by default and prints their right-to-left product. An optional braid column
is continuous across rows; strand colors/endpoint IDs are transported without
resetting at a factor boundary. Crossings stay compact within tall rows. Complete
supplied state sequences form a second surface column. Missing states/blocks,
duplicate factor IDs and noncontiguous groups are rejected.

`BraidDiagram(direction="bottom-to-top")` adds upward traversal while preserving
the original fixed sign convention: positive means upper-left over upper-right.
Words are never reversed, simplified or exponentiated by these drawing APIs.
The existing top-to-bottom default and all prior tutorial SVG/TikZ files are
unchanged. Support geometry, cut itineraries, colors and visibility are reused.

Tutorial figures 16/17 demonstrate grouped planar factors with an adjacent braid
and bordered support/action-state panels. The LaTeX gallery now fits both page
dimensions, avoiding overflow from tall figures. Validation: 171 tests pass
(18 new), 17 SVG/TikZ tutorial recipes regenerate, the 17-page TikZ gallery
compiles without overfull boxes, and the portable documentation site's local
links pass. SVG and compiled TikZ examples were visually inspected.

These changes do not compute actions, certify braid lifts or equivalences, or
complete the bordered cut-system mesh. No Tiny Bubbles Lab deployment is part
of this branch. The drawing examples are supplied data, not verification of a
new mathematical relation.

## Tutorial site and catalog, September 13

Interrupted mixed-boundary batch verified: 153 tests pass and all 15 tutorial
figures regenerate. Portable site builder checks local HTML links. Twelve planned
relation/fibration pages live in docs/catalog/*.json. User supplied the existing
GitHub repository as publishing destination; GitHub Pages is primary, with an
optional GitLab CI configuration. Release version is 0.1.0a3. See RELEASING.md.


Read [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) first. It is the controlling
roadmap for the new work. This file is the short, frequently updated checkpoint.

## Mixed four-view boundary reference families

The common left Type II + top/bottom pairs + right Type I layout is now supported,
also with explicit plane marks, in all four views. Only same-end Type I/II
combinations remain excluded; the previous opposite-end restriction was overly
broad. Tutorial figure 15 shows this fixture and its stable member identities.

## Member selection for bordered factor panels

`family.select(*numbers)` isolates reference members while retaining geometry,
colors and surface marks; `family.member_numbers` lists available IDs. Empty
selection keeps the bare surface and marks. Tutorial figure 14 shows vertical
factor-support panels on a bordered genus surface. Actions are not computed.

## Explicit marked-point plane bindings

`with_reference_arcs(mark_positions={"P": (x,y), ...})` now places all named
surface marks explicitly in clear upper/lower vertical-plane bands and connects
them inward to the first chain member. IDs and spoke colors follow surface.marks
order. Missing/extra IDs, invalid bands, overlapping marks, marks on reference
curves and spokes crossing another spoke are rejected. Existing automatic
mesh-based mark positions are unchanged. Figure 13 demonstrates this API.
There are now thirteen main tutorial SVG/TikZ figures plus the disk diagnostic.
The certified marked bordered mesh remains unfinished.

## Side Type II spokes and independent presentation geometry

Standard side pairs now connect their inner a anchors to the midpoint of the
outer odd member's upper/lower branch, with inward-tangent cubic spokes. One pair
per side is supported, also mixed with top/bottom pairs and interior Type I rims.
Explicit exclusions: outer bank b for side pairs, repeated same-side pairs, Type I
end rims combined with side pairs, and marks. These cases need further bindings.
The supplied reference drawing no longer asks the closed-surface mesh to validate
it; direct even-wrap geometry avoids the unsupported height-150 closed mesh case.
The certified mesh validator itself is unchanged. Tutorial figure 12 includes a
mixed side/top example.

## Top/bottom Type II reference spokes

`with_reference_arcs(pair_bank="a")` now handles top/bottom Type II pairs, including
mixed Type I boundaries. Each rim gets a vertical-plane spoke to the first chain
member directly inward from its chosen a/b anchor; cubic targets are bisected
rather than snapped to sampled points. Spokes inherit target visibility and
receive persistent boundary-order numbers/colors. Side Type II and mark spokes
remain unfinished, as does the certified bordered mesh. Tutorial figure 12 now
collects the bordered reference families; figure 10 retains attachment guides.

## All Type I slot reference families

The reference drawing now accepts Type I boundaries at genus cusps as well as
outer ends. Odd corridor members use the actual two slot endpoints, opening into
arcs wherever a boundary is present. Even members around opened cusps use a
rounded offset enclosure of the hole/rim control hulls, keeping a small gap;
unopened holes retain the earlier tight wraps. This is presentation geometry,
not a certified bordered mesh. Type II and marked spokes remain unsupported.
Validation: 146 tests and 17 tutorial recipes pass; the updated figures were
visually inspected. The preceding end-boundary commit passed remote CI.

## Type I end reference arcs

`GenusSurface.with_reference_arcs()` draws the reference family for one or both
Type I end boundaries. Each end member becomes two vertical-plane arcs joining
actual rim anchors to the neighboring cusp; interior members retain their IDs,
colors, and cusp-aligned visibility. Both exports and all four views are covered.
This separate presentation API does not pretend to supply a certified bordered
cellulation. Type II connections and marks remain explicitly unsupported. Tutorial figure 10 now shows the end reference family.
The user's one-time 9:16 a.m. Eastern continuation fired during this work; do not
reschedule it.

## Boundary-plane endpoint bindings

`GenusSurface.boundary_anchors()` returns exact rim/vertical-plane attachments
with boundary IDs and a/b banks. `boundary_anchor(id, bank)` resolves one;
`boundary_guide()` draws a labeled SVG/TikZ inventory, now in tutorial figure 10.
The positions are the actual endpoints shared by both half-rims, not rim centers.
Bank letters track tangent orientation, not front/back or cut-disk banks.
These are presentation bindings only: connecting reference arcs, marked-point
bindings and certified Type I/II cellulations still need implementation.
The previous cusp-transition CI run passed (db2b04a).

## Numbered route input update

`CutAtlas.crossing_on_cut(number, segment=1, bank="+", position=.5)` matches
`system.diagram(show_segments=True)` labels such as `2.1+`. Segment/bank coordinates
are mesh-specific; bank signs are not visibility or twist signs. The torus tutorial
now uses this explicit input. Type I/II mesh bindings remain the next major gap.

## Current checkpoint: September 13, 4:15 continuation

The one-time continuation automation is paused. Endpoint commit a76f1c7 passed
remote CI; legend commit 1d8deaa was still queued at this run's start.
Circular planar boundaries now export to TikZ using transparent even-odd stroke
clipping, including Figure panels. The main LaTeX gallery includes all hole
scenarios. Tutorial generation now writes eleven TikZ pictures plus a compilable
`examples/output/tutorial/tutorial-gallery.tex`; CI compiles this document too.
All 140 tests and all 14 tutorial Python blocks pass locally. TeX compilation
is delegated to CI because no TeX executable is installed locally.
Next visual priorities: Type I/II cut-system bindings and accessible genus route
locators, then richer supplied factor/action states. Do not redo endpoint controls
or legends, which are complete. Calculation engines remain lower priority.

## Legend and intersecting-family update

`PlanarDiagram(show_legend=True)` adds stable curve IDs and color swatches below
the surface, in SVG and TikZ. Tutorial figures 04/05 use it; figure 05 also shows
individual components beside the overlay, preserving their supplied routes.
No intersection certification or automatic curve offsetting is implied.
Validation: 140 tests pass; all 14 tutorial blocks run; browser images load.
Remote run 34737479779 for the preceding endpoint commit was still queued.

## Latest visual update

Planar circular boundaries now support exact left/right curved arc endpoints via
`Arc.start_side` and `Arc.end_side`; omitted sides face the route. Invalid endpoint
hole crossings are rejected analytically. Tutorial figure 03 demonstrates explicit
outward-facing endpoints. All 139 tests and 14 tutorial Python blocks pass;
browser checks show all eleven images loading without page overflow. Continue with intersecting-family layouts and visual IDs.

## Resume here

**Visualization first: follow V0-V4, then C1-C4 in IMPLEMENTATION_PLAN.md.**

Richard's five use cases now control the work: planar and standard nonplanar
curves/cuts, vertical factorizations and adjacent braids, supplied visual
transformations, then homology/fundamental-group and Lefschetz-invariant engines.
The earlier R0 exact-core gate is superseded. Keep the architectural separation
but do not defer drawings while researching calculations.

Tutorial: docs/TUTORIAL.md and browser edition docs/TUTORIAL.html. Run
`python examples/tutorial.py` for eleven main SVGs, one detailed cut-disk SVG and eleven TikZ counterparts.
The extra handle arc and `handle_style` constructor option have been removed.
New presentation records: ColoredCurve, PlanarDiagram, BraidDiagram, Panel, Figure.
Genus cut systems use numbered rainbow colors. Independent planar overlays are
opt-in and do not certify intersections; supplied states are not computed actions.

**Current visual refinements:** balanced Type I end clearance is pushed in
`e4f7b32`. The four-view fixture now has a 44-unit right strip, comparable to its
44-unit inter-hole gap and roughly 43-unit opposite strip. The missing generated
LaTeX gallery update was also fixed; GitHub run 34735538354 passed all jobs.

The completed appearance batch changes the default to above/right, makes planar reference cuts
straight symmetry-axis intervals, tightens even genus cuts and applies Richard's
confirmed opposite visibility patterns (above view: odd solid below; even solid
above). `PlanarSurface.with_cut_system()` supplies the standard colored intervals.
`MarkedArc` supplies straight visual arcs between automatic marks while preserving
explicit DiskRoute itinerary behavior. See the tutorial for the two input types.

Validation: all 138 tests pass on Python 3.12; the three new appearance tests
also pass on Python 3.9. All fourteen tutorial Python blocks ran, and the
regenerated figures were visually inspected. CI now also
regenerates genus and tutorial figures in its Python 3.12 job so stale outputs
cannot be missed by the gallery-only generation step.

**Next action: V2/V3.** Finish Type I/II cut bindings and make genus
route locators easier to select. Gentle top/bottom undulation remains a minor
later refinement. Calculation engines remain behind requested visualizations.

The earlier visual-cycle status below is retained as a technical checkpoint:
P0-P3 complete, P4 partial, P5-P8 unfinished and rescheduled.

Current P4a checkpoint: standard_cuts.py now builds certified 2g+1 chains and
numbered boundary/mark spokes. See standard-chains.md. The validator now has
explicit Attachment records for spoke endpoints on chain edges.

Disk routing and numbered complementary-disk diagnostics now work in
`disk_routes.py` and `cut_diagrams.py`. Ten new tests cover repeated crossings,
reversal, boundary returns, explicit overlays and reconstruction after cutting
along a route. Six generated SVG examples are in examples/output/cut-disks-*;
the decorated disk preview was visually checked, including mark M.

Closed default-genus presentation binding now uses an explicit doubled holed
mesh with smooth cubic chain edges. Every curved triangle passes a whole-curve
Bernstein orientation certificate; harmonic cut-disk charts check every triangle.
Genus 1/2/3/5/7 pass all four views. Named cuts and disk routes render with explicit
front/back visibility. The smooth genus-two preview was inspected. The current
127-test suite passes on Python 3.12.14 and 3.9.7; the 16-view regression checks
include genus 1/2/3/5.
The additional genus-seven four-view check also passed.

Marked closed-genus surfaces now work with `GenusSurface(2, marks=('P', 'Q'))`.
Supplementary mesh paths attach at regular cut vertices and reach the actual
marked vertices; the validator checks the resulting disk boundaries. Four new
tests cover all views, stable walks, missing-spoke rejection, exact marked arc
endpoints and maximal automatic mark counts. The marked-cut preview was inspected.

Previous P4 next action, now prioritized in V2: extend the checked presentation
binding to Type I/II boundaries.
The experimental `genus_outer_mesh.py` now classifies top/bottom rim halves and
matching seams explicitly. Its unfinished integration is preserved in
`docs/checkpoints/top-pair-binding.patch`; see that directory's README for the
exact default-genus-two cusp failure and resume commands. The patch is not
applied to the public API, and the edge charts are not a surface certificate.
The two edge-chart tests pass on Python 3.9/3.12; the full Python 3.12 suite now
contains 129 tests. The saved patch passes `git apply --check`.
These are still explicitly unsupported by GenusSurface.cut_system(); the
standalone abstract decorated chain remains available. The former instruction to
finish all remaining P4-P8 work is superseded by the visualization-first roadmap above.
Closed route examples now include multiple handles, a separating loop producing
two once-bordered tori, repeated visits to a cut edge, disjoint handle loops,
and explicitly declared intersections. Their generated contact sheet was inspected:
the harmonic mesh projection is continuous but retains visible tangent changes
between carriers. Smooth presentation-wide routing remains a visual refinement;
do not describe these routes as globally smooth.
Do not mark P4 complete from closed examples alone. New binding modules and
records remain experimental. Projection flattening now uses positive rational
Bezier control hulls to bound every segment, separately from the whole-curve fold
certificate; midpoint-only flattening has been removed. Disconnected projected
pieces are rejected even when their sheet changes.

P3b adds `src/surface_diagrams/cut_systems.py`, 26 tests in
`tests/test_cut_systems.py`, and seven worked examples in
`examples/cut_system_examples.py` with checked-in `examples/output/cut-systems.json`.
It reconstructs full/cut surfaces, vertex links, boundary cycles and mark copies,
and checks parent walks and transverse intersections. All 93 tests pass on
Python 3.9.7 and 3.12.14. JSON reports regenerated identically twice; no SVG or
TikZ geometry changed. The new records are internal, not package-root exports.
Rendered binding, shared parent endpoints/edges, tangencies and triple parent
intersections are explicitly unsupported. P4 may extend these with exact
incidence contracts if its standard configurations require them.

P2 was recovered and committed as 79bf6bd; P3a specification as 577b18f.
Both were pushed before this implementation. Earlier P1/P2 visual checks below
remain historical evidence, not a new visual audit.

Repository root on Richard's machine: `C:\GitHub\surface-diagrams`.
Remote: `https://github.com/richardbuckman-math/surface-diagrams`.
All source links below are repository-relative so another AI can work from a clone.

## What has actually been checked

- Starting code commit: `1af585c` (merge after `97c9c6c`). Version: `0.1.0a2`.
- `python -m unittest discover -s tests` passed **44 tests** at planning time
  with the repository `.venv`.
- Earlier implementation work also verified 44 tests on Python 3.9.7 and 3.12.14,
  built a wheel, compiled 48 TikZ figures plus one multiple-inclusion page with
  Tectonic 0.17.0, and visually inspected the compiled contact sheet. These are
  historical checks, not evidence for future changes.
- The current worktree initially had no tracked changes; only `Figures/` was
  untracked. Richard explicitly authorized including all those diagrams.
- Located **114 original SVGs, 8,102,982 bytes**. All eight named references and
  the additional `BPlanarCutSystem.svg` were rendered and inspected. The other
  SVGs were inventoried, not individually interpreted or visually reviewed.
- [Figures/MANIFEST.json](../Figures/MANIFEST.json) records SHA-256 and byte size
  for every original SVG. The source SVGs are retained unchanged.
- P1 adds `genus_geometry.py`, slot-aware radii, automatically spaced pairs,
  sideways collars, and explicit hidden rim halves. It adds five untuned/override
  examples and a source-comparison generator. Current gallery: 53 scenarios.
- P1 verification: 52 tests pass on Python 3.9.7 and 3.12.14. The SVG genus gallery
  and original-versus-generated comparison were visually inspected. Existing
  TikZ output was regenerated from shared primitives; no exporter logic changed.
- September 11 refinement: 58 tests pass on Python 3.9.7 and 3.12.14. Python 3.9
  requires `PYTHONPATH` pointing to this checkout's `src` (it has no installed
  package). New tests
  cover all four views, boundary visibility including handle-tip boundaries,
  true trimmed hole overlap, mirrored occlusion, direct collar joins, and roomy
  side-pair defaults. The updated D3/D2A/E2 comparison and four-view sheet were
  visually inspected, along with all 17 genus gallery panels. Gallery now has
  57 scenarios. SVG and existing TikZ outputs were regenerated; Tectonic compiled
  the gallery successfully. No TikZ exporter code was changed, and this is not P7.
- The unfinished P2 diff was saved byte-for-byte through git diff and reversed
  out of the working tree. `git apply --check` confirms it can be restored.
  This was the historical P1 checkpoint. P2 has now incorporated that work;
  its obsolete patch has been removed from the current tree.
- P2: circular planar holes, rim-ended arcs, outline-aware clearance, transparent
  stroke clipping, and numbered row guides. All 67 tests pass on Python 3.9.7
  and 3.12.14 (nine additional P2 tests).
  All 14 new gallery scenarios were visually inspected; 1,182 hole-interior
  pixels per image were checked on transparent and colored outputs. Existing
  planar/curve/direction/genus SVG examples were unchanged. Gallery: 71 scenarios.
  New circular-hole TikZ output raises an explicit error pending P7; existing
  export tests still run, and the LaTeX generator marks SVG-only examples.

## User decisions, in priority order

1. The four primary references establish the default nonplanar visual style.
   The E3B/D1/F3B alternatives are secondary presets.
2. The prettiest ordinary result should need only mathematical inputs.
   Appearance parameters are optional for unusual requests.
3. Numbered chain curves plus boundary/mark arcs form a cut system only if its
   complement consists of unmarked disks (boundary marks allowed).
4. Nonstandard configurations set up their cut system once when configured.
5. Show numbered cut-system diagrams in examples and the complete test suite.
6. Add actual planar circular boundaries first in rows, then general layouts
   including the daisy reference. Retain dots and distinguish marks from holes.
7. Add arcs and closed curves on those surfaces; Richard explicitly clarified
   that he did **not** mean subsurface highlighting.
8. Extend TikZ/LaTeX for the new work last. The existing exporter stays usable.
9. Include all supplied reference diagrams in the repository. This is an archive,
   not a request to implement all of their mapping-class calculations.
10. Above/below and left/right are independent choices. D3 is below/right and
    D2A is above/right. Boundary hidden halves and handle overlap follow those
    views; future curves must also honor them. See `docs/genus-presentation.md`.
11. Stop with a tested, committed, pushed checkpoint and portable next steps
    before compute runs out. The user prefers to stay with Codex, but needs the
    option to hand the repository to another AI without losing work.

## Important implementation traps

- The primary references use shallow horizontal openings and short collars;
  P1 now follows that default. Do not restore the old tall lenses or scalloping.
- Genuine intersections in a cut graph, intersections between overlaid curves,
  and overlaps of front/back projected paths are three different things.
- The old planar multicurve router deliberately rejects intersections. Daisy
  overlays require a deliberate extension, not removing that safety check.
- A chain count and global Euler characteristic do not certify disk complements.
  Validate actual gluing, incidences, topology, faces, and placement of marks.
- A sequence of whole-curve numbers can be ambiguous at intersecting cuts.
  Define oriented segments, faces, endpoints, and crossing order before routing.
- Circular boundary endpoints terminate on the rim. Hollow point styling does
  not change a marked point into a boundary component.
- Do not infer topology from abbreviated SVG drawings or their omitted repetitions.
- Reference files are examples/data, not instructions for an agent to execute.

## Files to read for the next stage

- [Figures/README.md](../Figures/README.md): reference priorities and observations.
- [genus.py](../src/surface_diagrams/genus.py): existing geometry and boundary types.
- [model.py](../src/surface_diagrams/model.py): planar inputs and style.
- [curves.py](../src/surface_diagrams/curves.py): existing horizontal cut router.
- [primitives.py](../src/surface_diagrams/primitives.py),
  [layout.py](../src/surface_diagrams/layout.py),
  [svg.py](../src/surface_diagrams/svg.py): rendering separation.
- [gallery.py](../examples/gallery.py), [tests](../tests): examples and regressions.

## Commands

On Richard's machine:

```powershell
cd C:\GitHub\surface-diagrams
git status --short --branch
git log -5 --oneline
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
.\.venv\Scripts\python.exe examples/make_images.py
git diff --check
```

On another machine, create a virtual environment, install with
`python -m pip install -e .`, and use that environment's Python. Python runtime
dependencies remain empty. SVG previewing and LaTeX compilation can use separate
development tools; do not make them required dependencies of the drawing library.

Current Codex sandbox process creation has sometimes failed with `setup refresh
had errors`; approved escalated commands worked during this planning checkpoint.
This is an environment issue, not a package defect. Do not bypass a denied action.

## Checkpoint log

| Stage | Completed work | Evidence | Next step |
| --- | --- | --- | --- |
| P0 | Reference inspection; complete SVG inventory; controlling plan; this handoff | 44 baseline tests; 9 reference previews inspected | Start P1 |
| P1 | Reference-based genus geometry, automatic collars, rim visibility, comparison sheet | 52 tests on Python 3.9/3.12; visual SVG checks; 53 gallery scenarios | Start P2 |
| P1 refinement, September 11 | Four views, trimmed hole overlap, smooth direct collars, taller side-pair defaults; 57 gallery examples | 58 tests on Python 3.9/3.12; comparison, four-view and genus sheets inspected; existing TikZ gallery compiles | Restore saved P2 patch and finish P2 |
| P3b, September 12 | Internal cellulation validator, parent incidence checks, seven executable fixtures and JSON reports | 93 tests on Python 3.9/3.12; deterministic JSON; abstract scope only | P4a standard chain constructions and checked presentation bindings |
| P3a, September 12 | docs/cut-systems.md: worked decompositions and proposed validation contract | Specification only; existing 67 tests pass, no validator implemented | Implement P3b gluing/link/mark kernel and fixtures |
| P2 | Circular planar holes and rim endpoints; clipping and clearance; 14 examples; SVG-only export guard | 67 tests on Python 3.9/3.12; geometry and raster checks; old SVG examples unchanged | Start P3 specification and validator |

Append a row or update it at each meaningful checkpoint. Record the actual files,
commit, tests, failures, and next action. Never make a future AI infer status from
a large transcript. Keep the stage table in IMPLEMENTATION_PLAN.md in sync.

## Prompt for another AI

```text
Continue the surface-diagrams repository from its saved checkpoint.
First read docs/HANDOFF.md, docs/IMPLEMENTATION_PLAN.md, and Figures/README.md.
Inspect the actual repository status and reference SVGs; do not rely only on
this prompt. Resume the first unfinished stage in the plan and keep both
checkpoint documents current. The primary references are D3HyperellipticLifted,
D2AHyperellipticSurfaces, E2MCKHOddGenusLifted, and
E2MCKHOddGenusLiftedWithBoundaries, all in Figures/ as SVGs.
Make beautiful ordinary diagrams require minimal parameters. Build and certify
numbered cut systems whose complement consists of unmarked disks, then support
arcs and closed curves on standard genus and custom planar configurations.
Include ordinary and numbered-cut examples and substantive tests for every
supported configuration. Extend TikZ/LaTeX for the new features last.
Follow the saved plan's stage gates and preserve existing work. Ask only when
different mathematical interpretations require the author's decision. Record
progress and exact next actions before stopping or handing off. Do not claim
a stage complete until its acceptance tests and visual checks pass.
```

## Confirmed cusp-plane convention

Type I/II boundary and marked-point reference arcs must lie in the vertical
plane. Bind their endpoints to the actual boundary/mark geometry in that plane;
do not fan them through an arbitrary surface chart. Even genus wraps change
visibility on the projected line through the hole cusps, matching their odd
neighbors, rather than at y=0. This affects presentation visibility only and
preserves supplied curve itineraries and the checked cellulation.

Cusp-plane update validation: 142 tests pass, including transition checks in all
four viewing directions. Genus and tutorial outputs regenerated and inspected.
