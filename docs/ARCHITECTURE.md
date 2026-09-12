# Architecture and mathematical representation decisions

Design proposal, September 12, 2026. These are contracts for the revised roadmap,
not a description of calculation features already implemented. Read
[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for scope and sequencing.

## Current sequencing: visualization first

Richard's latest priority supersedes the earlier calculation-led staging. Build
and document drawings of supplied configurations before automatic actions,
normal forms, cover decisions or invariants. The contracts below guide that
separation; they are not prerequisites to shipping the visual tutorial and
cut-system improvements. IMPLEMENTATION_PLAN.md now uses V0-V4, then C1-C4.

## Dependency boundaries

```text
compute -> core <- render
application examples use compute and render
```

`core` owns mathematical surfaces, endpoint/boundary structures, combinatorial
charts and exact serialized mathematical records. `compute` owns algorithms,
normalization, actions, relations and certificates. `render` owns presentations,
coordinates, visibility, labels and SVG/TikZ. Application code requests a
calculation and gives its results to the renderer; importing a surface or drawing
must not run a calculation engine or require an optional algebra dependency.

Initially keep one distribution and preserve the `surface_diagrams` import path.
Namespace names above are architectural roles; decide final packaging names only
when extraction is useful. Avoid introducing a plugin framework or an abstract
base class for every possible mathematical object.

## Three different meanings of a curve

1. **Curve or arc class:** a mathematical object on an explicitly identified
   surface, modulo a stated isotopy convention. An arc must specify its endpoint
   conditions. The object is independent of camera angle, mesh and color.
2. **Combinatorial representative:** a concrete strand arrangement in a chosen
   topological chart. It can record nonminimal intersections, component labels,
   orientations, local strand pairings and an explicit crossing arrangement.
3. **Drawing:** a geometric realization of that representative in a presentation,
   potentially with projection-only crossings, hidden portions and singularities
   of the projection. It is not a canonical representative of an isotopy class.

A normalized representative can support class equality only within the declared
normalization algorithm's domain. A coordinate object does not automatically
supply a canonical form. The first API should expose these distinctions even if
it supports only a narrow collection of exact operations.

## Recommended first encoding

Use an explicit *small topological* triangulation or polygonal cellulation with
stable oriented edge IDs, face incidence and gluing. Represent curves as exact
normal strands with ordered edge crossings and local pairings. Arc endpoints
have separate structured records. Record the chart identity/version with every
encoding; changing the chart uses an explicit conversion.

Useful endpoint types include an interior marked point, a particular boundary
notch, a fixed boundary point in a declared parameterization, or an endpoint free
to move along a specified boundary/window. Do not identify these cases. A mark,
a removed puncture, a branch value, and a boundary circle are different features;
a point may have several explicitly assigned roles without conflating them.

For simple curves and disjoint multicurves, compact normal/integral lamination
coordinates are a strong candidate for efficient operations. Their admissibility,
peripheral components, endpoint conventions and normalization must be specified.
Do not assume a bare list of edge counts determines every labeled arc system,
self-intersecting curve, boundary winding or relative isotopy class. Keep ordered
strands and peripheral data available when compact counts discard information.

An auxiliary triangulation vertex is not automatically a mathematical marked
point. In particular, introducing auxiliary vertices on a closed surface must
not change which isotopies are permitted. Closed and exceptional low-complexity
surfaces require their own supported cases; they cannot silently be converted
to punctured surfaces and treated as equivalent.

Current `DiskRoute` is a presentation itinerary. Keep it as a drawing interface
and provide checked adapters for supported cases. Its metric crossing fractions
and fine mesh face names are not the future canonical curve identity. The P3
cellulation validator supplies useful incidence checks but is not an isotopy or
mapping-class equality algorithm.

## Coordinate comparison, not one encoding for everything

| Representation | Best prospective role | Data/caveat to preserve |
| --- | --- | --- |
| Normal strands / marked triangulation | First exact engine for arcs, simple curves, local actions and reconstruction | Endpoint and peripheral data, strand order, chart conventions and normalization domain |
| Dehn-Thurston coordinates / marked pants decomposition | Compact multicurve and twist calculations, higher-genus computations | Marking/seams, twist signs, boundary behavior, admissibility and conversion conventions |
| Train-track weights | Later measured-lamination and dynamical algorithms | Carrying maps, switch conditions, splitting and exceptional cases |
| Fundamental-group/groupoid words | Path transport and monodromy for covers | Based versus free classes, endpoint paths, surface relations; words alone do not encode a chosen crossing diagram |
| Artin braid words | Braids, products, inverses, factorizations and planar braid views | Strand order, endpoint labels, sign and multiplication convention; equality needs a stated algorithm |
| Link/tangle combinatorial diagrams | Kirby, bridge and tri-plane representations | Crossing over/under, boundary matching, orientation and framing data |

Flipper demonstrates ideal-triangulation coordinates as a computational approach
for laminations and mapping-class actions on punctured surfaces. That supports
investigating this representation; it does not establish coverage of our notched
or closed-surface conventions. [Flipper's own documentation](https://flipper.readthedocs.io/en/latest/api/flipper.html)

Dylan Thurston's draft on geometric intersection explicitly treats change of
Dehn-Thurston coordinates and twisting. Compare that approach before C1 rather
than prematurely ruling it out. See RESEARCH_NOTES.md for retrieval status and
other references. Keep the abstraction open to an exact coordinate conversion;
implement only one initial engine.

## Mapping classes through images of a reference system

Richard proposes using the image of a chosen cut system to identify a mapping
class, independently of its Dehn-twist or half-twist word. Make this a first-class
candidate representation, with its exact scope determined by the stabilizer.

Let G be the chosen mapping class group and C a reference system with all its
labels, endpoint conditions and incidence data. Its orbit map is

    G -> G.C,    f -> f(C).

Equality here means equality under the declared isotopy convention, not equal
screen coordinates. The map is injective exactly when Stab_G(C) is trivial:
f(C) = g(C) implies that g^{-1}f fixes C. In general the orbit is the homogeneous
space G/Stab_G(C). With trivial stabilizer it is a G-torsor (a set with a free,
transitive G-action). Choosing C as reference identifies that torsor with G.
Define "compatible" here as belonging to this decorated orbit; a matching number
of arcs or an abstractly isomorphic cut graph is not a sufficient certificate.

The Alexander method supplies the relevant uniqueness mechanism. In the basic
case of a compact oriented surface with nonempty boundary and no interior marks,
a complete disjoint system of essential, labeled proper arcs cutting the surface
into disks detects mapping classes relative to pointwise-fixed boundary. Fixing
the arc classes allows simultaneous straightening, and the remaining disk maps
are isotopic to the identity relative to their boundaries. More general filling
systems require the appropriate Alexander hypotheses and control of their graph
automorphisms; merely filling the surface does not always remove all symmetries.
See Farb and Margalit, *A Primer on Mapping Class Groups*, Proposition 2.8
([text](https://euclid.nmu.edu/~joshthom/Teaching/MA589/farbmarg.pdf)).

Do not transfer that claim to an ordinary closed-curve cut system in a Heegaard
diagram: nontrivial twists about its curves preserve their isotopy classes. A
pants decomposition alone has the same problem. Closed surfaces, interior marks,
unlabeled systems and notched-boundary groups need separate stabilizer arguments.
For notched boundaries, retain endpoint/notch transport and boundary action;
recheck uniqueness in the enlarged group rather than inheriting the fixed-boundary
result. The existing cellulation certificate checks disk-complement topology;
it does not yet prove that the chosen mapping-class action has trivial stabilizer.

Proposed records and operations (not implemented):

- `ReferenceSystem`: surface/convention, labeled arcs or filling graph, chart,
  endpoint/incidence data, and the supported rigidity argument.
- `MappingClassImage`: reference ID plus the exact image system and required
  boundary/point transport. Preserve the original word separately as provenance.
- `same_mapping_class`: compare exact normalized images only in a supported
  domain with a trivial-stabilizer guarantee. Otherwise report the residual
  ambiguity or that the comparison is unsupported.
- Changing reference systems uses an explicit change-of-marking operation.
  Composition obeys `(fg)(C) = f(g(C))` for right-to-left products; computing it
  still requires an action or reconstruction algorithm.

A uniquely determined isotopy class is not automatically a canonical serialized
normal form or a cheap algorithm. C1 must test image normalization, compatibility
and actions, including braid relations giving equal images and nontrivial twists
that an insufficient reference system fails to detect. Equal products also do
not identify their factorizations: distinct ordered factor sequences remain
separate objects even when their final image system agrees.

## Surface and map contracts

A surface carries orientation, genus, stable boundary and point identities, and
explicit boundary/point structures. Its concrete combinatorial chart additionally
specifies enough incidence to construct the surface; genus and feature counts
alone are not an embedding or chart.

A map records source and target marked surfaces, orientation behavior, allowed
boundary and point permutations, and its mathematical encoding. Use morphisms
between differently marked surfaces where needed, with automorphisms as a special
case. Do not force every intermediate operation into one group on one immutable
marking. Composition order is documented and tested once across every module.

Numeric drawing parameters never determine whether a mathematical map is legal.
An algorithm result states its domain, convention and evidence: proven true,
proven false with a witness, unknown, or unsupported. Different notions of
comparison get distinct operations: literal word equality, supported equality of
mapping classes, equality of products, conjugacy, Hurwitz equivalence, isotopy of
representatives, and equivalence of manifolds represented by diagrams.

## Braids and factorizations

Begin with ordinary Artin braids on a marked disk. General surface braids and
braid groupoids are later extensions, with their ambient surface and endpoint
configuration explicit. Keep the braid word, its induced permutation and any
mapping-class action as distinct records. A nontrivial pure braid can have the
identity permutation.

A factorization stores an ordered tuple of factors, factor IDs, its ambient
map/groupoid context and optional provenance. Its product is a separate computed
result. If products act right-to-left, state that once in examples and tests.
A Hurwitz move convention must be fixed explicitly; for example the algebraic
replacement `(a,b) -> (b,b^{-1}ab)` preserves the written product `ab`. Do not
silently interchange this with its inverse convention.

Parallel displays consume a correspondence record: which factor or block of
factors downstairs corresponds to which factor(s) upstairs, the cover/embedding
used, chosen lift, boundary action and any deck ambiguity. A lifted twist may
produce a product of twists; never require a one-to-one factor correspondence.
Layout may align grouped blocks and label unavailable or unknown translations.
Matching color is a display convention, not evidence of mathematical equality.

## Notched boundaries: preserve rotation and twist separately

Richard's intended use is to admit boundary actions that pointwise-fixed mapping
class groups exclude, making additional lifts admissible. The exact group or
category is still to be formalized; do not impose an order-three relation merely
because three notch positions are visible.

Proposed boundary structure:

- A parameterized oriented boundary circle with an origin and a finite cyclic
  set of `q` notches; `q` is positive and rotations are exact rational turns.
- A declaration of allowed cyclic notch shifts, permitted permutations of
  boundary components, and how notch labels are transported.
- An explicit isotopy convention preserving the declared structure throughout
  an isotopy, not merely at its endpoints.
- A record of the full map, retaining information about boundary Dehn twists.
  The notch permutation alone is not a faithful encoding of that map.

Example explaining the distinction: on an annulus use
`p(r, exp(i*theta)) = (r, exp(i*d*theta))`. A downstairs twist
`T(r,theta) = (r,theta + 2*pi*f(r))`, with `f=0` on one boundary and `f=1`
on the other, has a lift
`R(r,theta) = (r,theta + (2*pi/d)*f(r))` satisfying `p R = T p`.
The lift turns one boundary by `1/d` of a turn. It is forbidden by pointwise
boundary fixing but may be allowed by a compatible notch structure. Its `d`th
power is a full upstairs Dehn twist, not automatically the identity. Its notch
permutation does become the identity. Reversing the twist convention reverses
the signs, not this distinction.

For this local model, allowing quarter turns also allows a half turn, whereas
third turns need a compatible cyclic structure. For a general cover, independent
choices of boundary phases need not extend to one global lift. Neither this
annulus example nor a notch count is a general liftability test. If Richard wants
a quotient that kills full twists, name that quotient and implement it explicitly.
If boundary rotations are allowed freely during isotopy instead, the group can
change again; preserve that distinction rather than collapsing all variants.

## Cover data and Birman-Hilden scope

A cover has explicit source and base surfaces (either may have positive genus),
degree, branch values, local ramification degrees, and a sheet/gluing or monodromy
model. It also records boundary covering degrees and parameterizations, point
preimages, and which preimages remain marked in the chosen category. Track
ramified and unramified preimages separately. An arbitrary ordinary marked point
must not silently become a branch value.

Start with finite sheet permutations for generators of an explicitly presented
punctured base surface. Check the surface relation, connectedness when requested,
peripheral cycle data and the resulting Euler/genus/boundary data. Positive-genus
bases need handle-generator monodromy, not just puncture permutations. Degree-two
involution pictures are examples, not the architecture's general definition.

A lifting calculation first checks equivalence of the relevant monodromy after
the base map's action, with basepoint/transport conventions supplied. It then
checks ramification, marked-point and allowed boundary behavior. Return the chosen
sheet transport/lift or the supported obstruction. Existence of a topological
lift, an admissible lift in the chosen boundary category, and injectivity of a
map between mapping-class groups are distinct claims.

Birman-Hilden results have hypotheses and marking/boundary conventions. The
Margalit-Winarski survey treats fully ramified finite branched covers with
negative-Euler-characteristic total surface and distinguishes closed-surface deck
quotients from pointwise-boundary conventions. Store theorem applicability as
separate evidence, not a universal property of a `Cover` object. Recheck theorems
when adding notches or marking upstairs preimages. [Margalit-Winarski survey](https://celebratio.org/Birman_JS/article/471/)

## Diagram extensions

Heegaard and trisection diagrams compose labeled curve families on a core surface.
Keep each family's disjointness and the required inter-family conditions explicit.
A collection that renders successfully is not automatically a valid diagram of
the claimed 3- or 4-manifold. Relative, bordered, pointed and sutured variants use
separate contracts for the boundary and auxiliary structures they require.

Classical bridge diagrams use arcs/tangles and endpoint matching. Bridge trisection,
shadow and tri-plane diagrams have different compatibility data; share primitives
and adapters rather than treating the names as synonyms. Kirby diagrams require
framed-link/handle data and crossing information that a surface isotopy class
alone does not retain. Begin by recording/rendering explicit known examples.
General recognition, simplification, equivalence searches and cross-family
conversion algorithms remain separate, later capabilities.

## Migration and immediate non-goals

Do not discard the existing P3 validator or move all source files at once. Identify
which immutable records can become core data, which routines are calculations,
and which objects are render-specific. Add adapters with tests on current fixtures.
Leave the cusp prototype isolated during that audit. Do not claim that every
surface projection must have an everywhere regular differential.

This plan does not authorize implementing all diagram families at once, installing
an algebra system, renaming the repository, or changing mathematical conventions
without an explicit specification. First complete the visual tutorial and
requested cut-system diagrams. Exact actions and coordinate comparisons follow
the visualization milestones in the controlling plan.
