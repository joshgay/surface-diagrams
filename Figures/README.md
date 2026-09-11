# Original reference diagrams

These are the 114 original SVG diagrams supplied by Richard for this project.
He authorized including the complete collection in the repository. Filenames
and SVG contents are preserved, including variants and apparent duplicates.
The total SVG size is 8,102,982 bytes (about 7.73 MiB).

[INDEX.md](INDEX.md) lists every diagram. [MANIFEST.json](MANIFEST.json) records
byte sizes and SHA-256 hashes. Generated library examples belong in
`examples/output/`, not among these original references. The original source
SVGs are not Python runtime assets and need not ship inside the Python wheel.

## Primary nonplanar references

| Reference | Visual guidance from inspection |
| --- | --- |
| [D3HyperellipticLifted.svg](D3HyperellipticLifted.svg) | Low horizontal surfaces, shallow oval handle openings, many broad short collars, right-end rim, and front/back solid/dashed curve segments. |
| [D2AHyperellipticSurfaces.svg](D2AHyperellipticSurfaces.svg) | Use the bottom lifted-surface panel for the default visual language; upper panels show other presentations and projection context. Short repeated collars and a chain-like set of connecting curves are visible. |
| [E2MCKHOddGenusLifted.svg](E2MCKHOddGenusLifted.svg) | Smooth low body; paired side boundaries and a few top/bottom collars; routing around and between shallow handle openings. |
| [E2MCKHOddGenusLiftedWithBoundaries.svg](E2MCKHOddGenusLiftedWithBoundaries.svg) | Boundary rims and front/back visibility; mixed boundary placements; several concrete families of closed-curve overlays. |

The first four are closest to Richard's desired defaults. They supersede earlier
guesses made from a single thesis figure. They contain several panels and omitted
repetitions: a library example should choose an explicit finite surface rather
than infer its genus from visible holes in an abbreviated panel.

## Secondary presentations

| Reference | Visual guidance from inspection |
| --- | --- |
| [E3BMCKHEvenGenus.svg](E3BMCKHEvenGenus.svg) | More undulating outline and angled side collars; a secondary even-genus presentation. |
| [D1HyperellipticTorus.svg](D1HyperellipticTorus.svg) | Broad central oval opening and collars around the outside of a torus. |
| [F3BBKHGenusTwo.svg](F3BBKHGenusTwo.svg) | Rounded genus-two lobes, boundaries in handle openings, and front/back curves. |

## Planar references

| Reference | Visual guidance from inspection |
| --- | --- |
| [C3ADaisyRelation.svg](C3ADaisyRelation.svg) | True circular boundary holes; fan and radial layouts; intentionally intersecting magenta loops. Implement a horizontal version first, then these general arrangements. |
| [BPlanarCutSystem.svg](BPlanarCutSystem.svg) | Additional relevant source found in the collection: mixed dots/circles and horizontal colored cuts. This is a visual reference, not by itself a formal certificate of a cut system. |

All nine diagrams above were rendered and visually inspected for the plan.
Other files are archived and indexed; no claim is made that every source has
been visually reviewed, interpreted, or reimplemented.

## How to use this collection

- Read [the controlling implementation plan](../docs/IMPLEMENTATION_PLAN.md)
  before changing defaults, topology, route coordinates, or examples.
- Cite a filename and panel when using a reference. Do not edit originals to
  make generated examples appear to match; put comparisons in generated output.
- Mathematical construction, boundary counts, and cut certificates must come
  from the model. A projection diagram alone does not specify all of them.
- Keeping every figure does not add the calculations or relations pictured in
  them to the package's implementation scope.
