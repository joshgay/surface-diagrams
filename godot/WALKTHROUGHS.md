# Supplied transformation walkthroughs

The **Walkthroughs** workspace replays bounded, versioned records. Each step
contains references to complete planar before/after documents, stable selected
object/curve/label IDs, a human-readable operation label, provenance, and a
recorded verification status. Saving writes the normalized record exactly.

Version 1 accepts 1 to 65 homogeneous planar or braid documents and 1 to 64
steps within the shared 256 KiB import bound. Every state must preserve the same
ordered stable IDs and kinds. Braid states must also preserve strand count,
spacing, colors, and stored presentation. Step references must form an explicit
continuous chain. Unknown fields, future versions, duplicate JSON keys,
scripts/resources, missing endpoints, reordered IDs, duplicate selections, and
unsupported status values fail without replacing the active walkthrough.

A planar step may additionally contain a `cover` linkage to two named
`surface-diagrams-surface-view` records. The linkage is accepted only when each
surface record embeds the exact complete planar endpoint named by that step.
Every supplied surface view must be referenced, and the linkage carries its own
provenance, verification, and the literal status
`supplied-exploratory-linkage`. Missing surface endpoints are not carried
forward or generated. Braid steps reject this planar-only data.

The bundled `point-and-label-v1.json` fixture is an original generic interface
example. Both steps are explicitly unverified. It is not Richard Buckman's
research data and asserts no isotopy, braid equality, mapping-class action, or
product preservation.

The bundled `signed-braid-v1.json` fixture supplies the literal word
`[1, -2, 1]` as three prefix steps. Each step records its own literal block and
complete entry/exit strand orders. Import verifies that the after-word is the
exact before-word plus that block and that the supplied orders match literal
strand transport. No generator is reduced, reordered, or sign-flipped. Positive
always means upper-left over upper-right in either presentation direction.

The bundled `supplied-cover-disk-v1.json` fixture contains one generic planar
step and two independently supplied exploratory disk views. The viewer links
object and curve selections across all four complete 2D/3D endpoints. Orbit and
zoom remain independent camera state. Fractional playback does not interpolate
the disk, move a curve, or synthesize any mathematical record. The fixture is
unverified interface data, not a computed branched-cover lift or Richard
Buckman's research construction.

Forward and reverse playback use one deterministic scalar position. Planar
panels always contain the complete supplied endpoints and change opacity for
orientation only. Braid panels retain the complete endpoint words while the
after panel schematically reveals the literal block at the current fraction. No
fractional mathematical record exists. Selected IDs, timeline, playback and
presentation directions, and panel opacity are view state.

Verification and provenance are imported metadata. Studio displays them but
does not promote a source assertion to an independent or machine check. Version
1 does not compute a cover lift, certify the supplied exploratory geometry, or
animate an intermediate surface state.

On desktop, **Export publication bundle** invokes the fixed Python library
adapter for every complete supplied 2D document. The deterministic ZIP includes
the normalized walkthrough, exact SVG/TikZ, editable Python and normalized JSON
per endpoint, plus a manifest with stable references, byte counts and SHA-256
digests. Exploratory 3D records remain in the walkthrough source and are listed
as excluded; they never become purported certified geometry. Browser builds
keep this control disabled. See [PUBLICATION.md](PUBLICATION.md) for the exact
archive layout and limits.
