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
current stable-ID selection, unapplied curve drafts, and a separate bounded
camera/timeline/panel envelope are also checkpointed in a version-4 workspace
recovery record. Its compact history stores each exact command endpoint document
once. Version 4 also retains the complete literal new-curve draft, including
schema-invalid input, without inserting it into the accepted record. Existing
version-1, version-2, and version-3 records remain readable and receive
deterministic defaults for state they predate. Desktop
storage keeps the newest checksum-verified generation and one last-known-good
generation. If replacement is interrupted or the primary is corrupt, startup
offers the newest valid slot and labels the fallback explicitly. A fixed local
bridge validates the same record with the Python library and makes its exact
publication SVG and TikZ available through explicit export buttons.
Bridge failure is visible and never falls back to a purported exact result. Do
not confuse this early editor with the more complete
[local browser editor](../docs/EDITOR.md), which runs without Godot.

The editor and all three secondary workspaces also have an explicit pointer-free
path: predictable entry/return focus, named controls, keyboard record selection,
camera control, factor/walkthrough stepping and playback, and 3D visibility
actions. These commands are view state and never edit mathematical JSON. See
[ACCESSIBILITY.md](ACCESSIBILITY.md) for the exact shortcuts and current
screen-reader/visual-acceptance limits.

**Find record** or Ctrl/Cmd+F searches the current diagram by persistent ID,
record kind, literal position, or visible label. Matching rows stay in exact
inspector order. Selecting one synchronizes the view only; accepted JSON,
history, camera/playback state, and unapplied drafts remain unchanged. The
query and result source are bounded, and compact layouts reveal the selected
Records pane instead of leaving the match hidden.

At widths below 900 logical pixels, the factor, exploratory surface, and
walkthrough workspaces expose touch-sized view switchers instead of stacking
every 2D and 3D canvas into one long scroll. Switching support/state/braid,
2D/3D, or complete before/after endpoints changes only presentation. Stable-ID
selection, timeline position, supplied records, and independent 3D cameras are
preserved. Desktop layouts continue to show all linked views together.

For real-window visual evidence, [visual_review/README.md](visual_review/README.md)
defines twelve fixed editor/workspace captures at desktop, phone portrait, and
phone landscape sizes. The runner isolates recovery state, records fixture,
viewport, selection, scroll target, focus, dimensions, byte counts, and SHA-256
checksums, and refuses dummy/headless rendering. Generated evidence remains
explicitly unreviewed until a person inspects it.

For release review, [DEMO_REVIEW.md](DEMO_REVIEW.md) defines one fixed
end-to-end workflow spanning validated editing, exact undo/redo, factor and
signed-braid inspection, linked exploratory records, and deterministic
publication. Its runner executes twice and retains a receipt and bundle only
when both runs are byte-identical. The visual, browser, phone, and screen-reader
checklist remains separate from that automated evidence.

For installed-layout review, [desktop/README.md](desktop/README.md) describes a
private portable Linux package. It runs outside the source checkout with a
fixed sibling Python authority, verifies exact geometry and publication, and
tests explicit missing-authority and missing-interpreter failures. The helper
does not publish or install the generated binary.

[benchmark/README.md](benchmark/README.md) defines the fixed bounded M7
performance workload and its versioned receipt. It measures maximum-size import,
the complete history limit, braid sampling, exact geometry, and representative
publication without treating elapsed time as correctness evidence. Current
observations and practical interpretation are in [PERFORMANCE.md](PERFORMANCE.md).

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
discard the validated checkpoint. Recovery is limited to 100 undo/redo commands
total, known existing-curve IDs, one bounded new-curve draft, and 64 cut visits
per draft. Version 4 has a
32 MiB payload cap, and each generation slot has a 34 MiB cap; legacy version 1
retains its original 1 MiB limit. The view envelope bounds zoom, pan, literal
braid playhead/presentation, and panel booleans; it cannot name scripts or
resources. New-curve recovery accepts only the editor's literal arc/loop fields,
fixed magenta color, numbered endpoints/cuts, and bounded scalar values. It may
retain invalid geometry for correction, but cannot manufacture an accepted
curve. Generation and payload bytes share a SHA-256
checksum. It never loads a script, scene, or resource, and camera state remains
outside the mathematical record. Successful Save marks the accepted source
clean, while any unapplied drafts remain visibly unsaved and recoverable.

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
The live Site is a separately published build. A branch push alone does not
update it; development handoffs should include this link and state whether the
reported changes have been deployed.

This is the Godot application exported to WebAssembly, not the separate Python
browser editor. It opens the two fixtures, inspects records, pans/zooms, imports
bounded local JSON and downloads normalized JSON. Browsers cannot run the local
Python process bridge. Exact SVG/TikZ exports stay disabled. Experimental
point/label editing requires explicit opt-in and preserves record constraints
and exact undo/redo, but **does not validate curve geometry**. Downloaded files
are named `*-unvalidated.json`; the existing schema is not silently extended.
Validate those records using the Python library before publication.

Use a browser with WebGL 2, WebAssembly, Web Crypto and gzip DecompressionStream
support. The Web shell follows the mobile visual viewport across dynamic browser
chrome, orientation changes, and on-screen keyboard resizing. CSS safe-area
insets keep the canvas out of display cutouts, and Godot lays controls out in the
remaining canvas content-box pixels rather than physical backing pixels. These
contracts are automated, but real browser startup, pointer/touch input, layout,
and upload/download dialogs still need visual acceptance. There is no automatic
browser persistence: explicitly download JSON before closing or opening another
fixture. User diagrams are not uploaded to a server.

New Web builds show the source revision and engine version during startup,
check browser capabilities before downloading, and retain visible errors if a
script or engine fails. Download progress remains indeterminate when the engine
cannot report a total. A slow start stays recoverable, and reloading after a
failure requires pressing Reload Studio. The expandable build report can be
copied or manually selected when clipboard access is unavailable. It contains
build, browser, viewport, and startup error details; nothing is sent automatically.
The static `studio-build.json` beside `index.html` remains available after startup
and records the source revision, local-change flag, exact engine, and pack and
compressed-engine checksums. These identifiers help compare a deployed Site
with a GitHub checkpoint; they do not certify browser or mathematical acceptance.

Check the public publication against the current checkout without deploying it:

```
python3 godot/web/check_site.py
```

For an exact source-and-assets comparison, build the candidate Web export and
pass its manifest:

```
python3 godot/web/check_site.py \
  --expected-manifest godot/builds/web/studio-build.json
```

Exit 0 means the public Site identifies the expected commit (and, in manifest
mode, exact pack and compressed-engine bytes). Exit 3 means a valid but different
build is live. Exit 2 means the publication cannot be identified, including the
older Site shell that predates `studio-build.json`. This read-only check does not
publish or download the large assets.

When browser edits or unapplied curve drafts differ from the last opened or
downloaded JSON, Studio also requests the browser's standard close/reload
confirmation. Downloading accepted JSON clears that warning only when no
unapplied draft remains. Browser vendors may suppress this prompt, especially
on mobile, so it is a safeguard rather than persistence: download JSON before
leaving the Site.

With the pinned engine and matching templates installed:

```
python3 godot/web/build_web.py --godot /path/to/godot --output godot/builds/web
```

The helper exports into a temporary directory, validates outputs, then copies
them to the requested static directory. It compresses the engine with
deterministic gzip; the browser verifies exact size and SHA-256 before supplying
an `application/wasm` response to Godot. A guarded one-expression adjustment to
the generated loader selects this path. The bounded `viewport.js` adapter is
copied and checked alongside the existing trusted file and engine adapters. No
engine binary, cache, generated Site assets, or Site credentials belong in this
GitHub branch. The Site source repository separately owns its static output and
`.openai/hosting.json`.
