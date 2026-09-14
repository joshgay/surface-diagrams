# Godot Studio checkpoint

- Branch: `joshgay/surface-diagrams:codex/godot-studio`.
- Starting parent: `4bd028e4052e34de429c60502e24e6686c9c2d09`, the browser-editor
  contribution on `codex/ordered-factorizations`.
- Date: 2026-09-13 (America/Denver).
- Current milestone: **M0 complete; M1 in progress**.
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

The inherited Python library/browser editor are not new Godot contributions.

## Validation evidence

Runtime: `4.7.2.stable.official.ed1daf0bf`. The downloaded official Linux x86-64
archive matched GitHub release SHA-256
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
See `RUNTIME.md` for official sources and commands.

- Godot headless editor import completed without parse errors.
- Main project ran for three headless frames without script/runtime errors.
- Godot tests: **38 assertions passed**. Covered fixtures/defaults, immutable
  records, save/reopen, duplicate JSON keys (including escaped spelling), future
  versions, unknown fields, duplicate IDs, object order, curve minimality,
  empty/exact braid words, strand transport, camera separation, scene load, and
  scene instantiation.
- Headless UI smoke: **10 assertions passed**. The live scene opened the planar
  fixture, switched to braid data, populated both inspectors, retained records
  through navigation, and preserved the current document after a rejected open.
- Intentional harness failure reported `FAILED: 1 of 1 assertions` and exited 1.
- Both fixtures were independently accepted and rendered to SVG by the Python
  library. Full inherited regression: **207 Python tests passed** and **8 browser-
  editor controller tests passed**.

## Known limitations

This is a viewer, not an editor. Native curve drawing is explicitly schematic;
publication/certified geometry still belongs to the Python renderer. It has no
point/label dragging, curve construction, undo stack, playback, factor workspace,
3D surface view, or Godot-side SVG/TikZ export bridge yet.

Actual rendered visual acceptance remains unavailable in this environment. There
is no display server. Installing Xvfb failed because the sandbox blocked apt's
required identity changes. Attempting movie capture with Godot's dummy headless
renderer crashed inside its texture path, so no screenshot is claimed. Headless
scene execution exercises `_ready` and data behavior but does not verify pixels,
pointer gestures, or file-dialog interaction.

## Next implementation task

Finish M1 acceptance in a display-enabled environment: visually inspect both
fixture views, zoom/pan and file dialogs; add record-selection highlighting; and
replace or supplement schematic planar paths with a narrow tested Python SVG/
Drawing bridge while keeping unavailable geometry explicit. Then begin M2 with
command-based edits and exact undo/redo.

Update this checkpoint after every meaningful implementation commit with actual
changes, tests, remaining failures, and the next concrete task. Work on generic
examples does not require waiting for Richard or Josh to supply research data.
