# Godot Studio checkpoint

- Branch: `joshgay/surface-diagrams:codex/godot-studio`.
- Starting parent: `4bd028e4052e34de429c60502e24e6686c9c2d09`, the browser-editor
  contribution on `codex/ordered-factorizations`.
- Checkpoint date: 2026-09-23 UTC.
- Current milestone: **M0 and M1 complete; M2 in progress**.
- Pull request status: **not opened; explicitly prohibited until Josh approves**.

## Latest increment: explicit slot-preserving row reindex

Built on live fork head `17bc1b10d1d5daa20c514dd4311567e7d930ba4a`.
The private Site was not redeployed or modified during this increment.

- Added explicit adjacent left/right row reindex controls for selected planar
  objects. Ordinary dragging still cannot cross neighbors. A reindex instead
  moves stable object records between fixed ordered x-slots, preserves every
  object/curve ID, and keeps literal endpoint and cut numbers unchanged.
- Before confirmation, the complete candidate passes strict document parsing and
  the Python geometry bridge. A scrollable preview shows old/new ID order, every
  changed slot, every endpoint number whose attached object changes, and every
  literal cut visit whose neighboring-ID corridor changes. The policy is stated
  directly; no number, visit, or record is silently transported or simplified.
- Confirm creates one command. Undo/redo restores exact recipes, Python SVG/TikZ
  remains deterministic, stable-ID selection follows the moved record, and all
  curve drafts stay keyed to their original curve IDs. Cancel and bridge failure
  leave the accepted source, both history stacks, on-disk recovery checkpoint,
  and every curve draft unchanged.
- Browser controller coverage requires the existing explicit unvalidated-edit
  opt-in, retains a confirmation stage, labels the result UNVALIDATED, and never
  fabricates publication geometry.

Runtime remains `4.7.2.stable.official.ed1daf0bf`; the official archive matches
SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
Checks actually run: **127 model/controller assertions**, **78 desktop scene
assertions**, **30 web-mode controller assertions**, **3 Python bridge tests**,
**3 runner contract tests**, **13 browser-adapter/loader tests**, and the
intentional exit-1 harness. Full inherited regressions: **213 Python tests with
324 subtests** and **8 browser-editor tests** passed. Godot editor import and a
three-frame project start completed without final diagnostics.

The new point-ID swap fixture produced byte-identical exact SVG and TikZ before
and after reindexing, as expected because slot geometry and numeric curve recipes
were unchanged. This is an automated geometry comparison, not visual acceptance
of the native controls or confirmation dialog; no display server is available.

## Foreground web proof of concept

Josh explicitly approved pursuing a private ChatGPT Site. Deployment succeeded:
<https://surface-diagrams-studio.joshgay.chatgpt.site>. This is **not full browser
acceptance or completion of M2**. The desktop path remains geometry-validated.

New browser-specific functionality:

- A single-threaded Web export preset, trusted HTML shell, explicit loading and
  failure states, and a reproducible export helper pinned to the official
  `4.7.2.stable.official.ed1daf0bf` engine.
- Local file selection with fatal UTF-8 decoding and a 256 KiB bound before
  reading; Godot then applies its strict versioned record validation. No
  imported scripts/resources execute. Browser JSON downloads preserve exact
  normalized records, use `-unvalidated.json` filenames, and revoke object URLs.
- Web startup never invokes `OS.execute`. Publication SVG/TikZ remains disabled.
  The initial mode is a viewer; explicit opt-in enables unvalidated point/label
  drafts with the existing neighbor/ellipse constraints and exact undo/redo.
  Geometry validation is never represented as successful in this mode. Opening
  another document resets the opt-in; failed opens preserve the active record.
- The initial Sites source push rejected the raw 39,514,754-byte engine as too
  large. Deterministic gzip reduced it to 10,054,758 bytes. The loader bounds
  decompression, checks the original size and SHA-256, then returns an
  `application/wasm` response. A guarded expression replacement in the generated
  Godot loader selects this path; neither engine bytes nor mathematical records
  are changed. No binaries/build products were added to the GitHub branch.

Checks actually run for this slice:

- Matching official export templates downloaded and SHA-256 verified (RUNTIME.md).
- Aggregate checks passed: 65 existing Godot model assertions, 30 existing
  desktop scene assertions, **19 new web-mode controller assertions**, **6 new
  mocked-DOM file adapter tests**, **7 new compressed-loader tests**, 2 Python
  bridge tests, fixture rendering, and the intentional exit-1 failure harness.
- Full inherited regressions: 207 Python tests and 8 browser-editor tests passed.
- The real Godot Web export succeeded. Generated JavaScript passed syntax
  checks. The actual compressed engine was decoded through the new loader,
  SHA-256 verified, and compiled by Node's WebAssembly runtime (337 imports).
- Sites source push, archive save, and owner-private deployment succeeded.
  Authenticated HTTP checks returned 200 for HTML, JS, PCK and compressed WASM.
  Downloaded JS/PCK/compressed-WASM SHA-256 matched local artifacts byte-for-byte.
  Reported types were text/html, text/javascript, application/octet-stream and
  application/wasm respectively. The compressed asset remains gzip bytes; the
  custom loader explicitly decodes them rather than trusting that MIME type.
- Initial network attempts timed out; ordinary retries succeeded. The raw-file
  size rejection is resolved by compression, not by changing providers/access.

Remaining browser limitations: no exact dynamic geometry validation/export, no
automatic local persistence or unsaved-change confirmation, and no real-browser
WebGL/startup/input/touch/file-dialog/resize acceptance. The current managed
preview does not support this buildless static project; the cloud browser may
not navigate live Sites URLs. Native headless tests and Node compilation are
not visual or browser-runtime verification. Desktop-browser use is the target
for the proof of concept; mobile usability is not claimed.

The foreground web next task is a permitted real-browser startup/edit/undo/
download/reopen acceptance pass, then a narrow browser-safe exact geometry
adapter. Do not silently upgrade unvalidated drafts into certified geometry.
The core M2 next task below still applies to scheduled branch development;
this Site approval does not authorize automatic scheduled deployments.

## Earlier implemented functionality

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
- Added a six-point multi-curve fixture, stable-ID curve inspector, literal
  ordered cut picking, retained rejected drafts, and Python-validated itinerary
  commands. Undo/redo and save/reopen reproduce exact SVG/TikZ; no visit is
  sorted, cancelled, or rerouted.
- Added explicit open/close data-loss guards and a bounded version-1 desktop
  recovery envelope separate from mathematical JSON. It restores accepted edits,
  undo/redo, stable selection, and every unapplied draft. Future/unknown data and
  discontinuous histories are rejected; browser persistence is not claimed.

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
- Godot tests: **127 assertions passed**. Covered fixtures/defaults, immutable
  records, save/reopen, duplicate JSON keys (including escaped spelling), future
  versions, unknown fields, duplicate IDs, object order, curve minimality,
  empty/exact braid words, strand transport, camera separation, scene load, and
  scene instantiation. New bridge checks cover fixed planar/braid rendering,
  non-mutation, record-to-row identity, successful Godot SVG decoding, and the
  explicit unavailable state when the configured Python executable is missing.
  Editing checks cover immutable proposals, neighbor and ellipse rejection,
  geometry rejection, exact undo/redo, redo invalidation, label commands,
  save/reopen, draft separation, and cancellation. Recovery checks additionally
  cover future/unknown/oversized input, unknown curve IDs, discontinuous command
  stacks, literal invalid drafts, exact disk round trip, and restored undo/redo.
  Reindex checks cover invalid/duplicate orders, row edges, fixed-slot movement,
  complete endpoint/cut impact reporting, Python acceptance, geometry rejection,
  one-command history, and exact undo/redo.
- Headless UI smoke: **78 assertions passed**. The live scene opened the
  fixtures, edited a point and label through canvas hit-testing, preserved IDs,
  endpoints and cuts, retained camera state, rejected a cross-neighbor drag,
  restored exact source through Undo/Redo, exported exact SVG/TikZ, and preserved
  the current document after a rejected open. It also exercised cancel/discard
  guards for fixture replacement and close, started a second Studio instance,
  restored accepted edits plus two drafts, and used undo after recovery. It also
  exercised reindex preview/cancel/confirm, bridge failure, preserved recovery
  and drafts, stable-ID movement, exact undo/redo, and validated geometry.
- Web-mode controller smoke: **30 assertions passed**. Browser editing remains
  explicitly unvalidated, guards pending drafts, and requires opt-in plus
  confirmation before an unvalidated reindex.
- Independent Python bridge contract: **3 tests passed**. Outputs for all three
  fixtures matched the library byte-for-byte and repeated deterministically;
  invalid versioned data failed without leaving SVG or TikZ output files.
- Intentional harness failure reported `FAILED: 1 of 1 assertions` and exited 1.
- All three fixtures were independently accepted and rendered to SVG by the
  Python library. Full inherited regression: **213 Python tests with 324 subtests
  passed** and **8 browser-editor controller tests passed**.

## Known limitations

This is a planar point/label and curve-itinerary editor and a braid viewer. Native curve
drawing, edit previews, and selection overlays are explicitly schematic;
publication/certified geometry still belongs to the Python renderer and bridge.
There is no arbitrary curve creation, braid editing/playback, factor workspace,
or 3D surface view yet. Desktop recovery is
bounded and tested, but browser persistence remains deliberately absent. The
source-checkout bridge currently requires a compatible
Python executable and this repository's package source; packaged desktop
operation has not been designed or claimed. The separate browser proof of
concept and its deliberately unavailable geometry bridge are described above.

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

Finish the remaining programmable M2 slice with explicit arbitrary curve
creation. Build an in-memory arc/loop draft with a new validated stable ID,
literal endpoint/orientation fields, and ordered cut visits; show schema and
Python routing failures without altering the accepted record; and commit a
successful creation as one undoable command while preserving every other draft.
Save/reopen and recovery must reproduce the new curve and exact publication
exports. A display-enabled pass must still inspect UI layout, overlays, gestures,
dialogs, reindex preview, and the recovery prompt.

Update this checkpoint after every meaningful implementation commit with actual
changes, tests, remaining failures, and the next concrete task. Work on generic
examples does not require waiting for Richard or Josh to supply research data.
