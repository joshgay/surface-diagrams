# Surface Diagrams Studio (Godot branch)

A separate experimental project for an interactive surface-and-braid workspace:
edit mathematical records, inspect persistent strand/curve identities, scrub
transformations, and connect planar drawings with exploratory surface views.
The Python drawing library remains the authority for its supported certified
geometry and publication SVG/TikZ outputs.

**Status:** the editor loads bundled planar, multi-curve, and braid JSON
fixture, draws an explicitly schematic native preview, and highlights stable
objects, curves, labels, and crossing indices selected in its inspector. In a
desktop planar document, drag a point or label to preview a move. Release commits only
after record and Python geometry validation; a rejected move restores the last
accepted record. Undo/redo buttons and Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, or Ctrl+Y
restore exact serialized states. The braid editor supports literal signed-word
edits, crossing selection, undo/redo and deterministic fractional playback.

**Factor workspace** opens a separate read-only viewer with linked supports,
supplied before/after states, and continuous braid blocks. It imports bounded
versioned JSON and offers exact desktop Python SVG/TikZ export, without computing
missing states or claiming a verified action. See [FACTOR_WORKSPACE.md](FACTOR_WORKSPACE.md)
for the generic fixture, schema, import controls and explicit limitations.

**Exploratory 3D** opens a linked generic oriented-disk view. Stable point,
boundary and curve IDs synchronize between the supplied 2D recipe and supplied
3D coordinates, with orbit/zoom, picking, hide/isolate and orientation labels.
It is deliberately not certified geometry or a computed lift. See
[SURFACE_VIEW.md](SURFACE_VIEW.md) for its bounded schema and limitations.

**Walkthroughs** opens a reversible supplied-record viewer. Every step names
complete before/after diagrams, stable selected IDs, an operation label,
provenance, and a recorded verification status. Scrubbing or playback only
crossfades planar endpoints or reveals a literal supplied braid block. It does
not compute an intermediate record or prove equivalence. Signed-braid steps
preserve exact word order, transported strand IDs, and the fixed physical sign
convention in both presentation directions. See
[WALKTHROUGHS.md](WALKTHROUGHS.md).
Planar steps may also link exact complete endpoints to independently supplied
exploratory 3D views. That comparison is explicitly labeled supplied and
unverified; Studio neither computes nor implies a branched-cover lift.
Desktop walkthroughs can export a deterministic review bundle containing the
normalized record, exact Python-library SVG/TikZ and editable Python for every
2D endpoint, plus checksums. Exploratory 3D data is explicitly excluded from
certified geometry output. See [PUBLICATION.md](PUBLICATION.md).

The Studio lists strand transport, exposes normalized source, pans/zooms without
changing records, and opens/saves bounded JSON. Accepted edits, undo/redo, the
current stable-ID selection, and unapplied curve drafts are also checkpointed in
a separate bounded version-1 workspace recovery record. A fixed local bridge
validates the same record with the Python library and makes its exact publication
SVG and TikZ available through explicit export buttons. Bridge failure is visible
and never falls back to a purported exact result. Do not confuse this early
editor with the more complete
[local browser editor](../docs/EDITOR.md), which runs without Godot.

The editor and all three secondary workspaces also have an explicit pointer-free
path: predictable entry/return focus, named controls, keyboard record selection,
camera control, factor/walkthrough stepping and playback, and 3D visibility
actions. These commands are view state and never edit mathematical JSON. See
[ACCESSIBILITY.md](ACCESSIBILITY.md) for the exact shortcuts and current
screen-reader/visual-acceptance limits.

For release review, [DEMO_REVIEW.md](DEMO_REVIEW.md) defines one fixed
end-to-end workflow spanning validated editing, exact undo/redo, factor and
signed-braid inspection, linked exploratory records, and deterministic
publication. Its runner executes twice and retains a receipt and bundle only
when both runs are byte-identical. The visual, browser, phone, and screen-reader
checklist remains separate from that automated evidence.

Import `project.godot` using Godot 4.7.2 stable. The exact runtime, checksum, and
commands are in [RUNTIME.md](RUNTIME.md). Use GDScript and the Compatibility
renderer; no .NET or external assets are required.
The [official Godot download page](https://godotengine.org/) and
[documentation](https://docs.godotengine.org/) are the reference sources.

See [DEVELOPMENT.md](DEVELOPMENT.md) for scope/acceptance criteria,
[STATE.md](STATE.md) for the current checkpoint, and [AGENTS.md](AGENTS.md) for
branch and automation boundaries. **No pull request until Josh approves.**

The fixtures are original generic examples in the browser editor's version-1
JSON format. They are not a mathematical relation or Richard's type (6,7) data.

## Ordered curve itinerary editing

Open **Multi-curve fixture**, then select a curve in the record list. Its
inspector shows the persistent ID, exact endpoints/orientation, and accepted
cut visits. Append visits by clicking numbered `c0`...`cn` buttons, canvas ticks,
or cut labels, in the intended order. Repeated visits remain repeated. **Remove
last**, **Clear**, and **Reset** edit or discard the draft explicitly. Drafts
are limited to 64 visits and marked `[draft]` in the record list.

**Apply exact cuts** submits one undoable command. On desktop, both record
validation and the Python geometry renderer must accept it. A rejected route
leaves the accepted recipe, history, SVG, and TikZ untouched. The draft stays
available when switching between curve and object selections; another curve's
accepted edit does not delete it. Save JSON writes only the accepted recipe and
warns when unapplied drafts are excluded. If drafts remain, they stay recoverable
without being inserted into that mathematical JSON file.

Opening a file or fixture, or closing Studio, now checks both accepted-record
changes and every stable-ID curve draft. The confirmation offers explicit
Cancel and **Discard and continue** choices. Cancel leaves the record, command
history, and drafts unchanged; a failed import also leaves them unchanged. On a
later desktop start, a recovery prompt lets the user restore or explicitly
discard the validated checkpoint. Recovery is limited to 1 MiB, 100 undo/redo
commands in either stack, known curve IDs, and 64 cut visits per draft. It never
loads a script, scene, or resource, and camera state remains outside the
mathematical record. Successful Save marks the accepted source clean, while any
unapplied drafts remain visibly unsaved and recoverable.

Example: select `editable` in the six-point fixture. Its initial itinerary is
`[0]`. Appending `c5` proposes `[0, 5]`, which the Python noncrossing router
rejects. Remove that visit and append `c6`: `[0, 6]` is accepted. Undo, redo, and
save/reopen reproduce byte-identical library SVG/TikZ for the accepted states.
No automatic cancellation, sorting, endpoint renumbering, or guessed route is
used. Native canvas curves and draft visit markers remain schematic.

## Explicit row reindexing

Select a planar object to expose **Reindex one slot left/right**. Ordinary point
dragging still stops at its neighbors. Reindexing is a separate, deliberately
destructive transaction with a precise slot policy: the selected stable object
record trades places with its adjacent record, fixed horizontal slot coordinates
remain ordered, and literal curve endpoint/cut numbers do not change.

Before anything is committed, Studio validates the complete candidate through
the Python geometry bridge and opens a scrollable confirmation containing the
old/new stable-ID order, both changed slots, every endpoint whose attached ID
would change, and every cut visit whose left/right corridor would change. Cancel
leaves the accepted recipe, undo/redo stacks, recovery checkpoint, and all curve
drafts byte-for-byte unchanged. Confirmation creates one undoable command and
retains drafts by curve ID. Browser use requires the existing unvalidated-edit
opt-in and remains visibly UNVALIDATED.

The browser-specific controller retains its explicit unvalidated opt-in and
disabled exact exports. Branch commits are not automatically deployed to the
public Site; the Site source and each publication receipt remain separate.

## Public browser proof of concept

Josh authorized a ChatGPT Site proof of concept on 2026-09-14 and requested
public access on 2026-09-23:
<https://surface-diagrams-studio.joshgay.chatgpt.site>.

This is the Godot application exported to WebAssembly, not the separate Python
browser editor. It opens the two fixtures, inspects records, pans/zooms, imports
bounded local JSON and downloads normalized JSON. Browsers cannot run the local
Python process bridge. Exact SVG/TikZ exports stay disabled. Experimental
point/label editing requires explicit opt-in and preserves record constraints
and exact undo/redo, but **does not validate curve geometry**. Downloaded files
are named `*-unvalidated.json`; the existing schema is not silently extended.
Validate those records using the Python library before publication.

Use a desktop browser with WebGL 2, WebAssembly, Web Crypto and gzip
DecompressionStream support. Real browser startup, pointer/touch input, layout,
and upload/download dialogs still need visual acceptance. There is no automatic
browser persistence: explicitly download JSON before closing or opening another
fixture. User diagrams are not uploaded to a server.

With the pinned engine and matching templates installed:

```
python3 godot/web/build_web.py --godot /path/to/godot --output godot/builds/web
```

The helper exports into a temporary directory, validates outputs, then copies
them to the requested static directory. It compresses the engine with
deterministic gzip; the browser verifies exact size and SHA-256 before supplying
an `application/wasm` response to Godot. A guarded one-expression adjustment to
the generated loader selects this path. No engine binary, cache, generated Site
assets, or Site credentials belong in this GitHub branch. The Site source
repository separately owns its static output and `.openai/hosting.json`.
