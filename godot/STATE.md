# Godot Studio checkpoint

- Branch: `joshgay/surface-diagrams:codex/godot-studio`.
- Starting parent: `4bd028e4052e34de429c60502e24e6686c9c2d09`, the browser-editor
  contribution on `codex/ordered-factorizations`.
- Date: 2026-09-13 (America/Denver).
- Current milestone: **M0 and M1 complete; M2 in progress**.
- Pull request status: **not opened; explicitly prohibited until Josh approves**.

## New functionality in this checkpoint

- Selected and verified the standard GDScript Godot 4.7.2 stable runtime.
- Added an independent, bounded `DiagramDocument` record model for the shared
  version-1 planar/braid JSON format. It normalizes defaults, returns defensive
  copies, rejects malformed/oversized/future/unknown or duplicate-key data,
  validates unique stable IDs and ordered objects, and preserves exact cut and
  signed-word order. Imports never load Godot resources or execute scripts.
- Replaced the placeholder with a working viewer. It opens either generic
  fixture or a selected JSON file, lists object/curve/label records or every
  braid crossing with entering/exiting strand identities, shows normalized
  source, and saves it. Invalid open attempts retain the current document.
- Added explicitly schematic native planar and braid views. They show the thesis
  palette, endpoint/cut numbering, labels, transported strand colors, and the
  fixed crossing-sign statement. Fit, wheel zoom, and middle-button pan are
  separate from immutable mathematical records.
- Added a reproducible headless runner and an independent Python fixture/SVG
  check. The runner also proves its own failure path returns a nonzero status.
- Added a narrow, fixed-command Python geometry bridge. The Godot process writes
  its already validated immutable recipe to a private cache, invokes only the
  repository adapter without a shell, bounds the output, and exposes exact
  library SVG/TikZ for user-selected export paths. Imported data cannot select
  an executable, script, resource, or cache path; bridge failure stays explicit.
- Added stable inspector selection and schematic highlighting for objects,
  curves, labels, and exact braid crossing indices. Selection is view state and
  does not alter the normalized mathematical record.
- Added the first actual planar editing slice. Direct canvas hit-testing selects
  points and labels; pointer motion creates a separate translucent preview;
  release proposes an immutable replacement record. Points must remain strictly
  inside the ellipse and between their existing neighbors, so endpoint/cut
  numbering cannot change accidentally. Escape cancels a draft.
- Added a bounded command history with exact serialized before/after states,
  Undo/Redo controls, and standard keyboard shortcuts. Candidate edits pass both
  strict record normalization and the Python geometry bridge before entering
  history. Rejected schema, order, or geometry changes preserve the last
  accepted document and do not consume an undo step. Camera state survives
  accepted edits and history navigation.

The inherited Python library/browser editor are not new Godot contributions.

## Validation evidence

Runtime: `4.7.2.stable.official.ed1daf0bf`. The downloaded official Linux x86-64
archive matched GitHub release SHA-256
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
See `RUNTIME.md` for official sources and commands.

- Godot headless editor import completed without parse errors.
- Main project ran for three headless frames without script/runtime errors.
- The aggregate runner now treats Godot `ERROR:` or `SCRIPT ERROR:` diagnostics
  as failures even when the engine process itself exits zero.
- Godot tests: **65 assertions passed**. Covered fixtures/defaults, immutable
  records, save/reopen, duplicate JSON keys (including escaped spelling), future
  versions, unknown fields, duplicate IDs, object order, curve minimality,
  empty/exact braid words, strand transport, camera separation, scene load, and
  scene instantiation. New bridge checks cover fixed planar/braid rendering,
  non-mutation, record-to-row identity, successful Godot SVG decoding, and the
  explicit unavailable state when the configured Python executable is missing.
  Editing checks cover immutable proposals, neighbor and ellipse rejection,
  geometry rejection, exact undo/redo, redo invalidation, label commands,
  save/reopen, draft separation, and cancellation.
- Headless UI smoke: **30 assertions passed**. The live scene opened both
  fixtures, edited a point and label through canvas hit-testing, preserved IDs,
  endpoints and cuts, retained camera state, rejected a cross-neighbor drag,
  restored exact source through Undo/Redo, exported exact SVG/TikZ, and preserved
  the current document after a rejected open.
- Independent Python bridge contract: **2 tests passed**. Outputs for both
  fixtures matched the library byte-for-byte and repeated deterministically;
  invalid versioned data failed without leaving SVG or TikZ output files.
- Intentional harness failure reported `FAILED: 1 of 1 assertions` and exited 1.
- Both fixtures were independently accepted and rendered to SVG by the Python
  library. Full inherited regression: **207 Python tests passed** and **8 browser-
  editor controller tests passed**.

## Known limitations

This is an early planar point/label editor and a braid viewer. Native curve
drawing, edit previews, and selection overlays are explicitly schematic;
publication/certified geometry still belongs to the Python renderer and bridge.
There is no row reindexing workflow, cut picker, curve creation/inspector,
recoverable invalid draft, braid editing/playback, factor workspace, or 3D
surface view yet. The source-checkout bridge currently requires a compatible
Python executable and this repository's package source; packaged operation has
not been designed or claimed.

Actual rendered visual acceptance remains unavailable in this environment. There
is no display server. Installing Xvfb failed because the sandbox blocked apt's
required identity changes. Attempting movie capture with Godot's dummy headless
renderer crashed inside its texture path, so no full-UI screenshot is claimed.
Both exact exported fixture SVGs were decoded to PNG with Godot and visually
inspected at the artifact level: the planar fixture retained four blue marks and
its magenta arc; the braid retained six transported strand colors and five
crossings. Headless scene execution exercises `_ready` and data behavior but
does not visually verify selection overlays, pointer gestures, or file dialogs.

## Next implementation task

Continue M2 with ordered cut picking and a curve inspector: create a generic
multi-curve drawing, make itinerary edits explicit commands, preserve the exact
supplied cut sequence without simplification, show Python routing errors without
replacing the accepted state, and prove edit/save/reopen plus undo/redo against
the publication exports. A later display-enabled pass must still inspect the
complete UI, preview/selection overlays, pointer gestures, and file dialogs.

Update this checkpoint after every meaningful implementation commit with actual
changes, tests, remaining failures, and the next concrete task. Work on generic
examples does not require waiting for Richard or Josh to supply research data.
