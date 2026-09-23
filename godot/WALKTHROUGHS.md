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

Forward and reverse playback use one deterministic scalar position. Planar
panels always contain the complete supplied endpoints and change opacity for
orientation only. Braid panels retain the complete endpoint words while the
after panel schematically reveals the literal block at the current fraction. No
fractional mathematical record exists. Selected IDs, timeline, playback and
presentation directions, and panel opacity are view state.

Verification and provenance are imported metadata. Studio displays them but
does not promote a source assertion to an independent or machine check. Version
1 does not yet animate cover data or certified geometry.
