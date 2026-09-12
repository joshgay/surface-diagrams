# Revised development plan: surface topology, calculations, and drawings

This is the controlling plan, revised September 12, 2026 following Richard's
request to separate mathematics, calculation, and visualization, and to include
braids, factorizations, covering maps, and future low-dimensional diagram families.
Read [ARCHITECTURE.md](ARCHITECTURE.md), [RESEARCH_NOTES.md](RESEARCH_NOTES.md), and
[HANDOFF.md](HANDOFF.md) with it. Earlier user requirements remain valid unless
explicitly rescheduled below; future ideas are not immediate implementation work.

The previous P0-P8 visual roadmap is preserved in
[the visual-cycle archive](archive/IMPLEMENTATION_PLAN-visual-cycle-2026-09-12.md).
Its exact reference, transparency, endpoint, topology, and export criteria remain
acceptance criteria for the corresponding features when those features ship.

## Immediate decision

Keep one repository and the current installable package for now. Introduce three
internal responsibilities: `core`, `compute`, and `render`. These are proposed
module boundaries, not instructions to move every existing file immediately.
The calculation engine and renderer depend on the mathematical core; the core
must not depend on drawing meshes or an optional calculation backend. Preserve
existing imports through compatibility adapters when files eventually move.
Separate distributions can follow demonstrated need; separate repositories and
independent release processes are not needed now.

This revision supersedes the instruction to finish every P4-P8 feature before
starting any calculation work. It does not mark those unfinished phases complete.

## What exists

- Attractive standard genus and planar SVG drawings, Type I/II surface outlines,
  circular planar holes, and existing TikZ output.
- An explicit abstract-cellulation validator and standard chains with decorations.
- Checked closed-genus mesh bindings, numbered chains, automatic marks, and
  continuous piecewise-smooth routes, including repeated visits and intersections.
- 129 tests passed in the last full Python 3.12 run; the previous full 127-test
  suite and two additional edge-chart tests passed on Python 3.9.
- Type I/II genus route bindings remain unsupported. The top-pair prototype is
  archived as a patch because its collar cusp needs another local projection model.
- No mapping-class equality engine, braid engine, general cover engine, or
  Heegaard/Kirby/trisection calculus has been implemented by these checkpoints.

## Staged roadmap

| Stage | Deliverable | Acceptance gate | Scope status |
| --- | --- | --- | --- |
| R0 | Reconcile Richard's work; specify surfaces, endpoints, boundary conventions, composition, and representation contracts | Record provenance of supplied work; settle or explicitly label open mathematical conventions; compare curve encodings on a small fixture set | Current planning work; user material still to be located |
| R1 | Small shared core with one exact curve/arc encoding and adapters to current drawings | Mathematical identity survives restyling; serialization round trips; endpoint/peripheral/twist data survive; unsupported normalization is explicit | Next implementation slice |
| R2 | Braids, elementary mapping classes, and ordered factorizations | Braid relations, inverses, composition convention, curve actions, and product checks on supported surfaces | First calculation milestone |
| R3 | One factorization displayed coherently as braid, planar surface, and lifted surface | Stable factor/curve IDs, explicit correspondence maps, synchronized factor order, documented lift choices; no inference from matching colors | First integrated release target |
| R4 | Cover data and boundary-aware lifting, beginning with explicit small examples | Monodromy, sheet transport, ramification, boundary action and lift ambiguity checked independently; positive and negative examples | Next mathematical extension |
| R5 | Broader curve coordinates, higher-genus bases, additional covers and rendering presets | Each new algorithm has a declared domain and cross-checked examples; no theorem applied outside its hypotheses | Subsequent releases |
| R6 | Heegaard and bridge diagram data, followed by trisection/relative diagram data | Dedicated diagram contracts and known fixtures, distinguishing representability from validity or equivalence | Future extensions |
| R7 | Kirby diagrams and selected transformations between diagram families | Framing/handle information preserved; specific conversion hypotheses and inverse/check examples | Future extension; not required for first release |

R3 may initially use one fully specified lift example rather than waiting for the
general R4 lifting engine. That example must identify its theorem/construction
and boundary convention. One coherent example is preferable to several unfinished
universal engines.

## R0: representation decision before another renderer redesign

Prototype and compare explicit normal strands in a marked triangulation with
Dehn-Thurston coordinates relative to a marked pants decomposition. Use Dylan
Thurston's draft as one mathematical reference, not as an assumed ready-made
implementation. Evaluate existing flipper/curver-style algorithms for overlap;
no dependency or backend migration is selected by this document.

Recommended starting representation: exact oriented strand paths, ordered
crossings, local strand pairing, and endpoint data in a small *topological*
triangulation/cellulation. Keep a compact normal-coordinate view where its
uniqueness and normalization hypotheses have actually been implemented.
The thousands of triangles used to draw a genus surface are not this core chart.

Fixture set: punctured disk with three braid strands; annulus with winding and
fixed endpoints; a boundary-parallel and a null-homotopic loop; a once-bordered
torus; a closed genus-two separating curve; marked-point arcs; a surface with
three notches on one boundary; and an explicit degree-two/three annular cover.
Compare reconstruction, endpoint winding, twist actions, normalization, and
translation to the current drawings. Pick the first implementation from evidence.
Do not build two complete coordinate engines at once.

Include Richard's image-of-cut-system proposal: specify a decorated reference
system with a proved trivial stabilizer in each initially supported group, and
represent a mapping class by its exact image system. The orbit is a torsor when
this rigidity holds, and only a quotient by the stabilizer otherwise. Compare
normalization and equality of these images on braid relations and annular twists.
Keep the reference system distinct from the chart used to encode its image.
ARCHITECTURE.md states the hypotheses and the distinction from Heegaard cut systems.

## R1-R3: a small complete vertical slice

1. Declare the ambient marked surface and boundary/isotopy convention.
2. Represent an embedded arc and simple closed curve exactly, with explicit
   orientation and endpoints; keep isotopy-class operations distinct from an
   explicit representative's crossing arrangement.
3. Represent an Artin braid word with strand count, endpoint labels and sign/order
   convention. Add composition, inverse and the braid relation tests.
4. Implement the supported half-twist/Dehn-twist actions and compare with a small
   independent fixture or optional backend. An endpoint permutation is not a
   braid equality test, and homology is not mapping-class equality in general.
   Use exact images of a rigid reference system as the proposed word-independent
   identity check, once normalization and the stabilizer argument are supported.
5. Store a factorization as an ordered tuple of factors plus stable identities
   and provenance, separately from its product. Start with a specified Hurwitz
   move and its product-preservation test; general search is deferred.
6. Render the same factor sequence in aligned panels, carrying explicit maps
   between braid, base-surface, and lifted-surface data. Not every factorization
   has every view; report why a requested view is unavailable.
7. Ship that supported slice with SVG, its TikZ counterparts, examples, packaging,
   and documentation. Do not let distant 4-manifold features block this release.

## Notched boundaries and covers

Richard clarified that the intended extension admits lifts whose boundary action
would be forbidden by pointwise boundary fixing. Model this as a choice of
boundary structure and allowed actions, rather than setting a fractional twist's
power equal to the identity by fiat. Keep the finite notch permutation distinct
from the full mapping class and any residual boundary Dehn twist.

R0 must specify isotopies as well as maps: boundary labels, cyclic notch sets,
allowed cyclic shifts, boundary-component permutations, and which data isotopies
must preserve. The exact convention is still to be formalized with Richard's
examples. The architecture must preserve enough information to support an
explicit quotient later without silently imposing that quotient now.

R4 starts with local degree-two/three annular models, then one branched cover of
a marked disk, then a positive-genus base. Distinguish:

- a homeomorphism lifting as a map of the chosen cover;
- a lift satisfying the allowed marked-point and boundary actions;
- descent/lifting statements about isotopy classes;
- the Birman-Hilden property and any quotient by deck transformations.

Return a witness or reason where implemented, and `unknown`/`unsupported` when
no decision algorithm applies. A failed search is not proof of non-liftability.
Detailed data and the annulus example are in ARCHITECTURE.md.

## Future diagram families: separate types, shared ingredients

| Family | Reused ingredients | Additional indispensable data |
| --- | --- | --- |
| Heegaard diagrams | Surface and curve systems | Alpha/beta families, labels, appropriate cut-system/handlebody conditions; chosen pointed, bordered or sutured variant |
| Trisection diagrams | Surface and three curve systems | Alpha/beta/gamma roles, parameters and pairwise standardness data; a diagram is not simply any three colored curve systems |
| Relative trisection diagrams | Bordered surface, curves, arcs | Precise relative convention, boundary/open-book information and, where required, arced markings/gluing data |
| Classical bridge diagrams | Surface, arcs, braids/tangles | Endpoint matchings, crossing or height data, trivial-tangle/bridge data |
| Bridge trisection / shadow / tri-plane diagrams | Surface arcs and tangle diagrams | Three systems, compatibility and specified ambient trisection; distinct from classical bridge diagrams |
| Kirby diagrams | Link/tangle projections and labels | Over/under information, framings, dotted one-handles and handle-attachment conventions |

Representation and rendering come before automatic moves; automatic moves come
before a claim to recognize equivalence. Relative variants require explicit
boundary data and morphisms, not a generic `relative=True` switch. Kirby diagrams
will reuse drawing primitives, but will not be forced into a surface-multicurve
encoding that loses crossing or framing information.

## Disposition of the old P4-P8 work

| Old stage | Revised treatment |
| --- | --- |
| P4 | Preserve completed chains/routes. Introduce the core/presentation boundary first; finish only the boundary/curve cases needed by the next integrated example. Keep the cusp prototype isolated until validated. |
| P5 | Standard punctured-disk and braid-related planar views move into the first slice; arbitrary custom layouts and the full daisy gallery remain later work. |
| P6 | Optional presets follow a demonstrated user example; they no longer block the first calculation release. |
| P7 | Verify SVG geometry before extending TikZ for each shipped slice; compile its examples before release. No need to await every future preset. |
| P8 | Apply the audit to every release: tests, deterministic examples, packaging, documented limitations and clean pushes. It is no longer a single distant finish line. |

## Guardrails against uncontrolled scope

- Every implementation batch names one end-to-end mathematical example and its
  acceptance tests. Long-term ideas stay in this roadmap until their stage begins.
- Reuse existing working code; make incremental adapters, not a repository-wide
  rewrite or a universal class hierarchy.
- Keep exact mathematical data and proof/algorithm scope separate from numerical
  drawing tolerances. A singular projection need not imply a singular surface.
- Distinguish literal word equality, equal actions, isotopy, conjugacy, Hurwitz
  equivalence, and equivalence of represented manifolds. No generic `equivalent`
  operation may silently switch between them.
- Preserve all 114 reference SVGs. Tests and pretty defaults remain requirements;
  the first release simply has a smaller supported domain.
- Continue tested, scoped commits and pushes under Richard's standing authorization.
  Update HANDOFF.md with actual progress; never call a roadmap item implemented
  because its data class or documentation exists.
