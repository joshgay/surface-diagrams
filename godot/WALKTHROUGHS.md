# Supplied transformation walkthroughs

The **Walkthroughs** workspace replays bounded, versioned records. Each step
contains references to complete planar before/after documents, stable selected
object/curve/label IDs, a human-readable operation label, provenance, and a
recorded verification status. Saving writes the normalized record exactly.

Version 1 accepts 1 to 65 planar documents and 1 to 64 steps within the shared
256 KiB import bound. Every state must preserve the same ordered stable IDs and
kinds. Step references must form an explicit continuous chain. Unknown fields,
future versions, duplicate JSON keys, scripts/resources, missing endpoints,
reordered IDs, duplicate selections, and unsupported status values fail without
replacing the active walkthrough.

The bundled `point-and-label-v1.json` fixture is an original generic interface
example. Both steps are explicitly unverified. It is not Richard Buckman's
research data and asserts no isotopy, braid equality, mapping-class action, or
product preservation.

Forward and reverse playback use one deterministic scalar position. The two
panels always contain the complete supplied endpoints; their opacity changes for
orientation only. No fractional mathematical record exists. The selected IDs,
timeline, playback direction, and panel opacity are view state and are excluded
from serialized mathematics.

Verification and provenance are imported metadata. Studio displays them but
does not promote a source assertion to an independent or machine check. Version
1 does not yet animate signed braid words, cover data, or certified geometry.
