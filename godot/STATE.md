# Godot Studio checkpoint

- Branch: `joshgay/surface-diagrams:codex/godot-studio`.
- Starting parent: `4bd028e4052e34de429c60502e24e6686c9c2d09`, the browser-editor
  contribution on `codex/ordered-factorizations`.
- Checkpoint date: 2026-09-24 UTC.
- Current milestone: **M0 and M1 complete; M2 programmable work complete,
  with display-enabled visual acceptance still pending; M3 interaction and
  playback implemented, visual acceptance pending; M4 programmable acceptance
  implemented, display-enabled visual acceptance pending; M5 first linked
  exploratory surface slice implemented, visual acceptance pending; M6 supplied
  planar, signed-braid, and explicitly linked exploratory surface walkthrough
  slices implemented, visual acceptance pending; M7 first reproducible
  walkthrough-publication, keyboard-access, deterministic demo-review, portable
  Linux, and measured-performance slices implemented; visual and
  assistive-technology acceptance pending**.
- Pull request status: **not opened; explicitly prohibited until Josh approves**.

## Latest increment: deterministic bounded history-retention audit

Built from live fork head `2cd48105340636e8e0749af00ae3786d5dd957dd`
in an isolated worktree under the exclusive Studio lock.

- Added a versioned, deterministic audit for the complete undo/redo retention
  shape. It reports compact serialized-command bytes, command source bytes,
  runtime snapshot counts and source/document slots, the current document, and
  a conservative schema envelope. The audit explicitly does not present these
  logical quantities as allocator, heap, RSS, or process-memory measurements.
- Every cached snapshot is checked against both the corresponding serialized
  command field and the immutable document's canonical JSON. Tests cover a
  deliberately mismatched command, exact repair, the 101st-edit eviction,
  complete undo/redo transfer, byte-identical round-trip audit, and redo
  invalidation after a replacement edit.
- Recovery now enforces the same 100-command bound across undo and redo
  combined. Previously it independently accepted up to 100 in each array even
  though live history can retain only 100 total.
- The maximum structural benchmark fixture retains 100 commands and 100 aligned
  snapshots. It reports 3,036,447 bytes of compact command serialization,
  4,353,148 logical source-slot bytes, and zero stale, missing, or orphaned
  snapshots. The deterministic profile reproduced across two complete runs.
- Documented the 105,119,744-byte conservative logical source-slot ceiling and
  the exercised fixture's 4.14 percent use. This deliberately double-counts
  logical slots where the runtime may share immutable string storage.

Runtime: `4.7.2.stable.official.ed1daf0bf`. The official Linux runtime and Web
templates were freshly downloaded and matched their recorded SHA-256 digests.
Checks actually run and passed:

- Aggregate: **863 Godot assertions**, all bridge/browser harnesses,
  deterministic demo, two-run bounded benchmark with retention validation,
  portable-package success/failure scenarios, and the intentional failure
  harness. The private portable package contained 53 files and was exercised
  outside the checkout.
- Full repository regression: **225 Python tests with 359 subtests** and **8
  browser-editor tests**. The first aggregate attempt correctly exposed that
  the newly reconstructed environment lacked the editable local Python package;
  ordinary editable installation followed by a complete rerun passed.
- Static Web export rebuilt successfully with the checked official templates.
  This is a build check, not WebGL or physical-phone visual acceptance. No Site
  deployment, download publication, release, or email occurred.

No controller/test failure remains. Display-enabled desktop, mobile, WebGL,
visible-focus, and screen-reader review remain unavailable in this environment.

**Next specific task:** remove the duplicate source string from each runtime
snapshot cache entry and validate snapshots directly against the immutable
document's canonical JSON, while preserving exact public command/recovery JSON,
tamper fallback, eviction semantics, and the deterministic retention audit.

## Earlier increment: canonical immutable document JSON

Built from live fork head `9ee0768b4094a3b96d2284c6e56ecdc01211e255`
in an isolated worktree under the exclusive Studio lock.

- Every accepted immutable `DiagramDocument` now computes its canonical
  normalized JSON once at construction. History commands, recovery envelopes,
  save operations, bridge calls, and checksums reuse that exact string instead
  of serializing an unchanged dictionary on every access.
- The public record dictionary remains a deep defensive copy. Mutating that copy
  cannot alter either the accepted record or its cached canonical bytes. Imported
  and recovered text still passes through the full bounded parser before the
  cache is created.
- Added direct assertions that cached text equals the previous normalized
  serialization and that `save_path()` writes those exact bytes. Existing
  recovery, deterministic demo, exact SVG/TikZ, publication ZIP, manifest, and
  checksum tests verify all downstream byte-level behavior.
- The fixed benchmark retained identical fixture and output hashes. Its committed
  receipt reduced the combined 100-edit, 100-undo, 100-redo median from 0.653 to
  0.529 seconds, another 19.0 percent. Maximum-record undo fell from 0.855 to
  0.023 ms per action and redo from 0.688 to 0.017 ms. The complete workload is
  86.8 percent below the original 4.008-second baseline. Timings remain
  observations, not a correctness gate.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: **851 Godot assertions**, all bridge/browser harnesses,
  deterministic demo, two-run bounded benchmark, portable-package scenarios,
  and intentional failure-harness check. Its independent benchmark repetition
  observed a 0.592-second combined history median and reproduced the same
  integrity profile.
- Full repository regression: **225 Python tests with 359 subtests** and **8
  browser-editor tests**.
- Static Web export rebuilt successfully. Pack inspection confirmed that
  benchmark implementation and receipts remain excluded. No Site deployment,
  download publication, or release occurred.

No controller/test failure remains. This optimization does not resolve the
existing display-enabled desktop, mobile, WebGL, visible-focus, or screen-reader
review gaps.

**Next specific task:** add a deterministic bounded history-retention audit that
reports serialized command bytes and runtime snapshot counts at the 100-command
limit, verifies eviction leaves no stale cached snapshots, and documents the
maximum retained-data envelope before further history optimization.

## Earlier increment: normalized local edit candidates

Built from live fork head `54f62d7d789c4c60a65cc5ab774fb8653d03b9ff`
in an isolated worktree under the exclusive Studio lock.

- Local edit methods now send defensive dictionary copies directly through the
  complete version-1 schema normalizer. They no longer serialize those trusted
  copies to JSON, parse them back, or scan generated text for duplicate fields
  before normalization.
- Imported files, browser uploads, saved workspaces, and recovery command text
  still use the full 256 KiB text parser with JSON syntax and duplicate-field
  checks. The optimized path is internal to dictionaries derived from an
  already accepted immutable document.
- Added parity coverage for representative label, planar-object, curve, and
  signed-braid candidates. Unknown fields, duplicate stable IDs, nonminimal cut
  itineraries, invalid braid generators, and invalid colors must produce the
  exact same schema error through both paths.
- The fixed benchmark retained identical fixture and output hashes. Its committed
  receipt reduced the combined 100-edit, 100-undo, 100-redo median from 2.026
  seconds to 0.653 seconds, another 67.8 percent. The maximum-record edit phase
  fell from 18.296 ms to 4.821 ms per edit. The complete workload is 83.7 percent
  below the original 4.008-second baseline. Timings remain observations, not a
  correctness gate.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: **849 Godot assertions**, all bridge/browser harnesses,
  deterministic demo, two-run bounded benchmark, portable-package scenarios,
  and intentional failure-harness check. Its independent benchmark repetition
  observed a 0.878-second combined history median and reproduced the same
  integrity profile.
- Full repository regression: **225 Python tests with 359 subtests** and **8
  browser-editor tests**.
- Static Web export rebuilt successfully. Pack inspection confirmed that
  benchmark implementation and receipts remain excluded. No Site deployment,
  download publication, or release occurred.

No controller/test failure remains. This optimization does not resolve the
existing display-enabled desktop, mobile, WebGL, visible-focus, or screen-reader
review gaps.

**Next specific task:** cache each immutable `DiagramDocument`'s canonical JSON
text at construction so history commands and equality checks do not repeatedly
serialize unchanged records, while proving save, recovery, publication, and
checksum outputs remain byte-identical.

## Earlier increment: parsed history snapshot cache

Built from live fork head `2c325f955b9d6bec3f64f08809c1fb99bcb8797d`
in an isolated worktree under the exclusive Studio lock.

- Undo and redo now reuse runtime-only, already validated immutable document
  snapshots instead of reparsing the same stored JSON on every transition. The
  serialized 100-command history and recovery formats are unchanged and contain
  no cache objects.
- Cache entries are accepted only when their source text exactly matches the
  corresponding serialized command. Missing, size-mismatched, or changed cache
  entries fall back to the original strict parser. A tampered command therefore
  still fails with the original error and leaves the document and both stacks
  unchanged.
- New edits, redo invalidation, oldest-command eviction, undo, redo, and complete
  recovery restoration maintain matching bounded caches. Recovery still parses
  and validates every stored command before changing the live workspace.
- Extended the fixed benchmark receipt with separate edit, undo, and redo phase
  timings. The previous combined 100-edit, 100-undo, 100-redo median was 4.008
  seconds. The new committed receipt records 2.026 seconds, a 49.4 percent
  reduction with identical deterministic integrity outputs. Maximum-record undo
  and redo medians are 0.750 ms and 0.739 ms per action; new edit validation is
  now the dominant 18.296 ms per action. Timing remains observational, not a
  correctness gate.
- Added exact tests for cache exclusion from serialized recovery, tamper
  fallback, failure atomicity, restored-stack use, 100-command eviction, and 100
  exact redo transitions.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: **840 Godot assertions**, all bridge/browser harnesses,
  deterministic demo, two-run bounded benchmark, portable-package scenarios,
  and intentional failure-harness check. Its independent benchmark repetition
  observed a 1.745-second combined history median and reproduced the same
  integrity profile.
- Full repository regression: **225 Python tests with 359 subtests** and **8
  browser-editor tests**.
- Static Web export rebuilt successfully. Pack inspection confirmed that
  benchmark implementation and receipts remain excluded. No Site deployment,
  download publication, or release occurred.

No controller/test failure remains. This optimization does not resolve the
existing display-enabled desktop, mobile, WebGL, visible-focus, or screen-reader
review gaps.

**Next specific task:** add a strict internal normalized-candidate constructor
for already bounded edit dictionaries while leaving imported JSON on the full
duplicate-field parser, then benchmark maximum-record edit construction and
verify identical normalized output and rejection behavior.

## Earlier increment: bounded performance baseline

Built from live fork head `2e0685fae9075b47c30244bca38fff60a278394d`
in an isolated worktree under the exclusive Studio lock.

- Added the fixed `bounded-m7-v1` benchmark using production record, history,
  timeline, geometry, and publication code. Its generated planar fixture uses
  all 32 objects, 16 curves, and 32 labels; its braid uses all 32 strands and
  128 literal signed generators; history uses all 100 commands.
- Each run measures five raw samples for import, edit/history, braid sampling,
  and exact SVG/TikZ, plus three publication samples. A versioned receipt stores
  raw microseconds, min/median/max summaries, normalized fixture fingerprints,
  and exact history, geometry, timeline, and publication outcomes.
- The wrapper executes the entire workload twice and requires the deterministic
  profile and output hashes to match. It never compares timings between runs,
  enforces no speed threshold, and explicitly labels all timings as performance
  observations rather than correctness or mathematical evidence.
- Committed the first headless Linux receipt and practical interpretation. Its
  medians were 6.643 ms per maximum import, 13.358 ms per maximum-record
  edit/undo/redo action, 3.379 ms per maximum-braid timeline sample, 487.567 ms
  per exact SVG/TikZ render, and 463.511 ms per representative publication.
  Visible drawing, browser/WebGL, 3D, input, and assistive technology were not
  measured. The two-document publication is representative, not the 65-document
  adapter bound.
- Benchmark code and receipts are excluded from Web and portable application
  packs. The existing application and mathematical fixture formats are
  unchanged.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- The benchmark wrapper reproduced the deterministic workload/integrity profile
  twice for the committed receipt. The complete aggregate runner repeated the
  two-run benchmark and passed all existing 833 Godot assertions, 13 browser
  adapter/loader tests, 18 Python bridge/adapter/runner tests, deterministic demo,
  portable-package scenarios, and intentional failure-harness check.
- Full repository regression: **225 Python tests with 359 subtests** and **8
  browser-editor tests**.
- Editor import and static Web export passed. Pack inspection confirmed the
  benchmark implementation and receipt were excluded. No Site deployment,
  download publication, or release occurred.

No controller/test failure remains. The benchmark does not resolve the existing
display-enabled desktop, mobile, WebGL, visible-focus, or screen-reader review
gaps. It records only headless controller and subprocess costs on one host.

**Next specific task:** add an internal parsed-snapshot cache for history
transitions, preserving the exact serialized recovery format and 100-command
semantics, then rerun the fixed benchmark to quantify the effect without making
timing a correctness gate.

## Earlier increment: verified portable Linux package

Built from live fork head `c675316e10a2bb098091894d3d6b3d03923a573e`
in an isolated worktree under the exclusive Studio lock.

- Added a private x86-64 package builder using the exact standard Godot runtime
  and a compiled project pack. The generated directory contains the runtime,
  pack, fixed authority adapters, a private Python library copy, license, and a
  versioned SHA-256 manifest. No export-template dependency is required.
- Added bounded authority discovery. Studio uses an explicitly configured
  trusted authority, then a fixed `authority/` directory beside the executable,
  then source-checkout adapters. An explicit incomplete authority fails instead
  of silently falling back. Imported records cannot select scripts or paths.
- Updated both Python adapters to load the packaged private library while
  retaining source-checkout operation. Successful bridge results report whether
  the authority was configured, packaged, or from the checkout.
- Added a packaged self-test that requires exact planar SVG/TikZ geometry and a
  deterministic linked-walkthrough publication with both exploratory 3D views
  explicitly excluded. It returns a bounded machine-readable receipt.
- The builder ran the 147,279,259-byte, 53-file manifested payload from a
  separate working directory outside the repository. It then verified nonzero
  actionable failure
  for both an absent authority directory and a configured missing Python
  interpreter. The package remained local and was not published.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile, 71 factor-workspace, 54 surface-view, 79 planar-walkthrough, 54
  signed-braid walkthrough, 52 cover-link walkthrough, 35 publication, 40
  keyboard/accessibility, 24 end-to-end demo, and **10 new authority-discovery
  assertions**, 833 total. The aggregate runner also rebuilt and tested all
  three portable runtime scenarios.
- The complete pinned-runtime runner passed, including 13 browser adapter/loader
  tests, 18 independent Python bridge/adapter/runner tests, and the intentional
  harness failure exiting 1.
- Full repository regression: **225 Python tests with 359 subtests** and **8
  browser-editor tests**.
- Editor import, three-frame launch, and static Web export passed. Inspection of
  the Web pack confirmed that desktop, bridge, and demo implementation files
  were excluded. No Site deployment, download publication, or release occurred.

No controller/test failure remains. Headless controller checks do not establish
screen-reader interoperability, visible focus clarity, keyboard behavior in an
actual WebGL browser, or physical-phone usability. Display-enabled desktop,
mobile, and browser acceptance therefore remains pending. Packaged operation is
verified headlessly on Linux, but its visible desktop presentation has not been
accepted and Python 3 remains a documented runtime requirement.

**Next specific task:** add bounded performance fixtures and a reproducible
benchmark receipt for import, edit/history, timeline sampling, exact geometry,
and publication. Record practical limits without converting timings into
correctness claims.

## Earlier increment: explicit supplied planar-to-surface endpoint links

Built from live fork head `ae72ebd897ac929103aa616de85c5c7bf3fe2909`
in an isolated worktree under the exclusive Studio lock.

- Extended the bounded version-1 walkthrough format with optional planar-only
  `surface_views` and per-step `cover` records. Each linked surface record must
  independently pass the strict exploratory-surface parser and embed the exact
  complete planar before/after document named by the step. Every surface view
  must be referenced; missing endpoints are never carried forward or generated.
- Each cover link requires its own provenance, verification, and literal
  `supplied-exploratory-linkage` status. Braid walkthroughs reject this data.
  Unknown fields, scripts/resources, mismatched planar records, orphan views,
  invalid 3D endpoints, and future or promoted status claims fail without
  replacing the accepted walkthrough.
- The walkthrough viewer now presents both complete supplied 2D endpoints and
  both complete supplied exploratory 3D endpoints. Stable object/curve
  selection links all four views. The two cameras remain independent view
  state. Scrubbing never interpolates a surface or creates an intermediate
  mathematical record, and visible language states that no branched-cover lift
  is computed or certified.
- Added an original generic disk fixture with an explicit moved planar endpoint
  and independently supplied 3D coordinates/polyline. Its verification remains
  unverified and it asserts no isotopy, action, equality, cover lift, or
  relationship to Richard's research construction.
- Corrected the Studio README to describe the existing Site as public while
  retaining the branch/Site separation and no-automatic-deployment boundary.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile, 71 factor-workspace, 54 surface-view, 79 planar-walkthrough, 54
  signed-braid walkthrough, and **52 new cover-link walkthrough assertions**,
  724 total. New coverage includes exact embedded endpoint equality, defensive
  copies, orphan/mismatch/executable-field rejection, linked 2D/3D selection,
  independent cameras, noninterpolated surface endpoints, failed-import
  preservation, exact save/reopen, and 320/390/1280-pixel layouts.
- 6 Python factor-adapter, 3 geometry-bridge, 3 runner-contract, and 13 browser
  adapter/loader tests. The intentional harness failure exited 1. Editor import,
  three-frame launch, and existing fixture renders passed.
- Full inherited regression: **207 Python tests** and **8 browser-editor tests**.
- Static Web export rebuilt successfully and its pack contains the new fixture
  plus compiled walkthrough/3D classes. No Site deployment or binary
  publication occurred.

No controller/test failure remains. Display-enabled desktop/mobile/WebGL visual
acceptance remains unavailable, so the four-panel presentation, 3D selection,
and physical-phone scrolling are not visually accepted. The linkage validates
record identity only; it does not calculate a cover, lift a curve, or certify
the supplied 3D geometry.

**Next specific task:** start M7 with a reproducible walkthrough publication
bundle containing normalized walkthrough JSON, exact Python-library SVG/TikZ
for every planar endpoint, and a deterministic manifest of stable references
and checksums. Exploratory 3D views must remain explicitly excluded from
certified publication output.

## Earlier increment: explicit supplied signed-braid walkthroughs

Built from live fork head `13bbbc67e0d6218cf8b82c3bafa6bf57ec709d30`
in an isolated worktree under the exclusive Studio lock.

- Extended the bounded version-1 walkthrough format to homogeneous braid-state
  chains. Each braid step requires a nonempty literal signed word plus complete
  supplied entry and exit strand-ID orders. Import requires the after-state word
  to equal the exact before-state word followed by that block, checks both
  endpoint permutations, and independently transports the entry order through
  the block. Nothing is reduced, cancelled, reordered, or sign-flipped.
- Braid states must preserve strand count, spacing, colors, and their stored
  presentation. Stable numeric strand identities can be selected across every
  endpoint. Mixed planar/braid state sets, malformed permutations, missing or
  executable fields, inconsistent prefixes, and unsupported generators fail
  without replacing the accepted walkthrough.
- Added fractional literal-block playback to the existing reversible viewer.
  Both panels retain complete supplied records; the after panel schematically
  reveals only the current block fraction. Bottom-to-top/top-to-bottom is
  separate view state. Positive remains upper-left over upper-right in either
  direction, and selected transported strands receive a persistent highlight.
- Added an original three-step `[1, -2, 1]` generic fixture with independently
  specified orders `[1,2,3]`, `[2,1,3]`, `[2,3,1]`, `[3,2,1]`. Every step is
  visibly unverified and asserts no braid relation, equality, mapping-class
  action, or connection to Richard's research data.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile, 71 factor-workspace, 54 surface-view, 79 planar-walkthrough, and
  **54 new signed-braid walkthrough assertions**, 672 total. New coverage
  includes prefix and permutation rejection, literal multi-generator blocks,
  independently expected strand orders, both physical presentation directions,
  fractional positive/negative crossings, stable strand linkage, reverse replay,
  failed-import preservation, and exact save/reopen.
- 6 Python factor-adapter, 3 geometry-bridge, 3 runner-contract, and 13 browser
  adapter/loader tests. The intentional harness failure exited 1. Editor import,
  three-frame launch, and existing fixture renders passed.
- Full inherited regression: **207 Python tests** and **8 browser-editor tests**.
- Static Web export rebuilt successfully and contains the signed-braid fixture.
  No Site deployment or binary publication occurred.

No controller/test failure remains. Display-enabled visual acceptance remains
unavailable, so native strand highlighting, fractional crossing gaps, mobile
controls, and actual WebGL rendering are not visually accepted. The braid
walkthrough validates literal combinatorial transport only; it does not prove
that a supplied word equals another braid or induces any claimed surface action.

## Earlier increment: explicit supplied planar walkthroughs

Built from live fork head `ae2175c2f44a7e528cfa953982d9d53465f02515`
in an isolated worktree under the exclusive Studio lock.

- Added a bounded version-1 `surface-diagrams-walkthrough` model containing
  complete named planar states and 1 to 64 ordered steps. Every step requires a
  stable ID, name, operation label, before/after references, 1 to 64 selected
  object/curve/label IDs, provenance, and verification metadata. All states must
  preserve the same stable IDs, kinds, and order. Consecutive steps must share
  an explicit state reference; missing states are never derived.
- Added exact normalized save/reopen and strict rejection for future/unknown or
  duplicate fields, scripts/resources, missing references, discontinuous chains,
  reordered IDs, duplicate selections, and unsupported provenance/verification
  values. Imported verification is displayed as record metadata and never
  promoted into a Studio conclusion.
- Added a responsive Walkthroughs workspace with forward/reverse play, scrub,
  boundary step controls, linked stable-ID inspection, complete side-by-side
  endpoints, and an explicit visual crossfade. No fractional mathematical state
  exists or is serialized. Timeline, opacity, selection, and playback direction
  remain view state, and opening/closing the viewer preserves the editor record
  and undo history.
- Added an original two-step point/label fixture. Both steps are visibly
  unverified and make no isotopy, action, equality, or product-preservation
  claim. This is generic interface data, not Richard's construction.
- The aggregate run caught a landscape-phone height regression caused by the
  extra toolbar button. Factor, surface, and walkthrough viewers now share one
  compact Workspaces menu. The existing portrait, landscape, tablet, and desktop
  controller checks pass again.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile, 71 factor-workspace, 54 surface-view, and **79 new walkthrough
  assertions**, 618 total. New coverage includes schema bounds, explicit chain
  continuity, stable ID/kind/order preservation, defensive copies, exact save
  and reopen, deterministic forward/reverse playback, unequal frame partitions,
  endpoint-only crossfade, linked selection, failed-import preservation,
  phone/desktop layouts, hidden-editor undo isolation, and close behavior.
- 6 Python factor-adapter, 3 geometry-bridge, 3 runner-contract, and 13 browser
  adapter/loader tests. The intentional harness failure exited 1. Editor import,
  three-frame launch, and existing fixture renders passed.
- Full inherited regression: **207 Python tests** and **8 browser-editor tests**.
- Static Web export rebuilt successfully. Its pack contains the generic fixture
  and all three compiled walkthrough classes. No Site deployment or binary
  publication occurred.

No controller/test failure remains. Display-enabled visual acceptance remains
unavailable, so endpoint opacity, native controls, pointer behavior, and the
mobile browser presentation have not been visually accepted. Version 1 supports
complete planar endpoints only; it does not yet record signed-braid or cover
walkthroughs, compute an operation, or certify the imported verification claim.

## Earlier increment: linked exploratory 3D disk

Built from live fork head `d592987550f45e68482f66898cab8ac9028ae376`
in an isolated worktree under the exclusive Studio lock.

- Added a bounded version-1 `surface-diagrams-surface-view` data model. It embeds
  a fully validated planar `DiagramDocument`, then requires one supplied 3D
  coordinate/polyline for every planar object/curve in the same stable-ID order.
  Version 1 accepts only an oriented generic disk. Arc endpoints must equal the
  supplied coordinates of their linked internal objects; loops must close.
  Future/unknown fields, scripts/resources, partial/reordered IDs, unsafe
  coordinates and unlabeled geometry status fail instead of being repaired.
- Added a responsive linked 2D/3D workspace with two-way stable-ID selection,
  projection-based 3D picking, orbit/zoom/fit, hide/isolate/show-all, and visible
  `+x`, `+y`, `front +z` orientation labels. Blue `#006fff` points, gray
  `#8b8b8b` boundaries and magenta `#ff00d4` curve polylines are retained.
  Read-only 2D views now support mouse selection without starting edit previews.
- Added the original generic oriented-disk fixture. Its five-point `arc1`
  polyline is drawn literally. It is prominently labeled supplied exploratory
  geometry, not a computed lift, certified route, equivalence, or completion of
  the Python library's unfinished bordered mesh. The planar record remains the
  publication authority; no 3D export was added.
- Camera, selection, label visibility and hidden IDs remain view state. Tests
  confirm camera motion and visibility changes leave the mathematical JSON
  byte-identical. Opening/closing the workspace preserves the main editor's
  unsaved record and undo history. See `SURFACE_VIEW.md`.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile, 71 factor-workspace and **54 new surface-view assertions**, 539
  total. Surface coverage includes schema bounds, ID/order/color preservation,
  literal vertex count, camera separation, two-way selection, actual 3D picking,
  hide/isolate/show-all, orientation visibility, failed-import preservation,
  phone/desktop layouts, hidden-editor undo isolation and main-scene return.
- 6 Python factor-adapter, 3 geometry-bridge, 3 runner-contract and 13 browser
  adapter/loader tests. The deliberate harness failure exited 1. Editor import,
  three-frame launch and existing fixture renders passed.
- Full inherited regression: **207 Python tests** and **8 browser-editor tests**.
- Static Web export rebuilt successfully and its pack contains the surface
  fixture and compiled 3D classes. No Site deployment or binary publication
  occurred.

No controller/test failure remains. A direct SubViewport screenshot attempt
failed because the headless dummy renderer returns no texture, consistent with
the recorded display limitation. Therefore mesh construction, camera projection
and picking are tested, but actual desktop/mobile/WebGL appearance is not
visually accepted. Version 1 is a disk with supplied polylines, not a higher-
genus surface, depth-aware curve router, surface action, or 3D editor.

## Earlier increment: synchronized factor timeline

Built from live fork head `939ae2e4235df3c8411fb2059c250948f30542f1`
in an isolated worktree under the exclusive Studio lock.

- Added a pure factor timeline whose position is view state, never mathematical
  data. Each supplied factor owns one stage. A nonempty stage maps its local
  fraction into that factor's exact global crossing interval. Multi-crossing
  blocks receive proportional playback time. An explicit empty block receives
  one timed hold with identical entering/exiting strand IDs instead of vanishing.
- Added start/end, previous/next, play/pause, scrub and presentation-direction
  controls to the linked factor workspace. Factor selection, support, supplied
  before/after panels, continuous braid prefix, crossing highlight and literal
  ID details now share one position. Clicking a crossing selects its factor and
  local position. Changing direction cannot reverse the factor or word order.
- Missing states stay absent throughout playback. Supplied planar states switch
  only at factor boundaries and are labeled as endpoints, not interpolated or
  computed animation results. Closing the viewer stops playback and preserves
  the main editor's unsaved record and undo history. All timeline interaction
  leaves the factor-workspace JSON byte-identical.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile and **71 factor-workspace assertions**, 485 total. New coverage
  includes fractional and multi-crossing blocks, empty-stage holds, unequal
  frame partitions, invalid elapsed times, both presentation directions,
  scrub/play/step/crossing synchronization, missing-state gaps, close behavior,
  mathematical-record immutability and the phone-width main scene.
- 6 Python factor-adapter, 3 geometry-bridge, 3 runner-contract and 13 browser
  adapter/loader tests. The deliberate harness failure still exited 1. Editor
  import, a three-frame launch and the three existing Python fixture renders
  passed.
- Full inherited regression: **207 Python tests** and **8 browser-editor tests**.
- The static Web export rebuilt successfully and contained the new compiled
  timeline. No Site deployment, binary publication or hosting write occurred.

No test failures remain. Display-enabled control/animation inspection and an
actual Android/iOS browser pass are unavailable, so M4 visual acceptance is not
claimed. The factor workspace remains read-only and is not in recovery. It
supports planar supplied panels, not genus-surface records.

## Earlier increment: supplied factor workspace

Built from live fork head `08ef1f7b3c375df7718eacac0b4db362d973e7e4` in an
isolated worktree under the exclusive Studio lock.

- Added a bounded, independently validated version-1 factor-workspace envelope.
  It preserves literal factor IDs/exponents/groups, named complete planar
  support/state recipes, application order and signed braid blocks. Duplicate
  keys, unsafe references, executable/unknown fields and future versions fail.
- Added a separate read-only factor workspace reachable from Studio. Desktop
  file import and desktop/browser pasted JSON synchronize support, supplied
  before/after states, a continuous braid and exact transported strand IDs.
  Picking a crossing selects its factor; explicit empty blocks retain their
  own selection without stealing a neighboring crossing. Phone layouts stack
  the views. Invalid imports preserve accepted data and selection. Opening and
  closing the viewer preserves the editor's unsaved record and undo history;
  viewer shortcuts cannot undo hidden editor work.
- Added a generic grouped storyboard, including a straight block and a negative
  exponent with an already-supplied complete word. No cancellation, power
  expansion, research identity, computed surface action or verified lift is
  claimed. Missing states remain visibly absent, including missing before-states
  after gaps; older states are never carried forward.
- Added a narrow Python adapter to `FactorPanel` / `FactorizationDiagram` and
  exact desktop SVG/TikZ export. Nested recipe styles and labels are preserved.
  Incomplete state sequences remain viewable but cannot export through the
  all-or-none state API. Browser publication remains explicitly unavailable.
  The Python library itself was not changed. See `FACTOR_WORKSPACE.md`.

Runtime: `4.7.2.stable.official.ed1daf0bf`. Checks actually run and passed:

- Aggregate: 175 model, 119 desktop scene, 49 braid interaction, 41 browser-mode,
  30 mobile and **55 new factor-workspace assertions**, 469 total. Factor tests
  include 320/390/1280-pixel layouts, actual main-scene phone integration,
  import rejection, missing states, selection, read-only dragging, hidden-editor
  undo isolation, deterministic exports and empty sequences.
- **6 new Python factor-adapter tests**, 3 existing geometry-bridge tests,
  3 runner-contract tests and 13 browser adapter/loader tests. Adapter tests
  independently construct library panels, compare exact outputs, and check
  physical crossing signs and color continuity through tall/empty blocks in
  both display directions.
- Full inherited regression: **207 Python tests** and **8 browser-editor tests**.
- Editor import, three-frame headless launch, all three existing fixture renders,
  and the deliberate failing assertion's exit-1 contract.
- Static Web export built locally; its pack includes the new nested fixture.
  No Site deployment or binary publication occurred. The exported SVG geometry
  was decoded and inspected: blue points, magenta arcs and continuous braid
  blocks. That decoder does not render SVG text, so this is geometry inspection,
  not typography or full interactive UI acceptance.

No remaining test failures. Display-enabled UI, actual Android/iOS browser
gestures, keyboard and WebGL acceptance are still unavailable. The factor
workspace is read-only and has no shared playback timeline or workspace
recovery yet. It accepts planar support/state recipes, not genus-surface data.
The public Site is unchanged by this branch-only run.

## Earlier increment: mobile layout and touch controls

Foreground repair requested by Josh, built from live fork head
`716c5e3aa93efd2111540a80d6158836dd01cd3a`.

- Replaced the fixed desktop presentation with logical CSS-pixel sizing on the
  Web, a compact Examples menu, and a Diagram/Records switch below 900 pixels.
  The records pane scrolls; toolbars wrap; controls and cut buttons have 44-pixel
  minimum touch targets. Dialogs are fitted to the viewport. The desktop retains
  simultaneous diagram and record panes. The Web shell enables the virtual
  keyboard and prevents page-level overscroll from competing with the canvas.
- Added direct touch handling: tap selects, one-finger drag pans, and two fingers
  pan/zoom. Move points explicitly enables point/label dragging on touch. A
  second finger, OS cancellation, lost focus, or a panel/viewport change cancels
  the pending edit. Touch-generated mouse duplicates cannot commit twice.
  All edits still use the existing record validation and undo controller;
  browser drafts remain explicitly unvalidated.
- Added phone/tablet/desktop layout and touch regression coverage. Tested
  320x640, 390x844, 844x390, 768x1024, and 1280x800 logical viewports. Desktop
  scene tests now explicitly create a desktop-sized window: the dummy headless
  display's default 64x64 size is unsuitable for responsive UI tests.

Runtime remains `4.7.2.stable.official.ed1daf0bf`. The aggregate passed 175 model,
119 desktop scene, 49 braid interaction, 41 browser-mode, and 30 mobile
controller assertions; 3 Python bridge, 3 runner-contract, and 13 browser
adapter/loader tests; and the intentional exit-1 harness. Editor import, the
three-frame headless project run, and all three Python fixture renders passed.
The full inherited Python/browser-editor suites were not rerun because their
shared code and the Python adapter are unchanged.
Actual Android/iOS browser, keyboard, picker, and WebGL visual acceptance is
still unavailable: the supported managed preview cannot run this static export.
The public Site will be rebuilt from this source during the foreground repair;
its deployment receipt belongs to the Site repository. Scheduled runs remain
branch-only and must not redeploy automatically.

## Earlier increment: crossing picking and fractional playback

Built from live fork head `e325d02a501f57734302dcdc6a491c1a590b8caa`.
Josh requested an immediate run and resumed hourly development. The existing
Studio Site's access was changed to public and verified through Sites. It still
serves the previously deployed browser proof of concept (version 1), not this
new branch build: <https://surface-diagrams-studio.joshgay.chatgpt.site>.

- Replaced discrete-only playback with a pure fractional crossing sampler.
  Integer times reproduce independently checked strand configurations; partial
  times reveal the next crossing without changing the exact signed word.
  The canvas, hit testing, and inspector share transported strand identities and
  the same physical over/under convention in both presentation directions.
- Click a visible crossing to select its exact word index in the canvas, list,
  and inspector after pan or zoom. Picking pauses playback at its current time.
  Crossings whose midpoints have not yet appeared cannot be picked. The position
  control also synchronizes selection; the append position clears the old
  crossing highlight. Selection is drawn behind the strands, and overpass gaps
  are clipped to the revealed portion of each crossing.
- Continuous scrubbing, play/pause, and previous/next boundary controls retain
  separate view time. Unequal frame durations reach the same endpoints. Edits
  and undo/redo stop playback and discard partial geometry from the prior word;
  rejected edits retain the current fractional view. Empty braids remain
  stationary, and nonfinite times are rejected. Browser previews use the same
  sampler and keep publication geometry unavailable.

Runtime: `4.7.2.stable.official.ed1daf0bf`. A new dedicated interaction suite
passed **49 assertions** covering independent endpoints, physical signs,
fractional positions, reverse sampling, pause, frame partitioning, actual scene
mouse dispatch, indexed selection, rejection, undo/redo, and empty words.
The aggregate runner passed: **175 model/controller assertions**, **119 desktop
scene assertions**, **49 braid interaction assertions**, **41 browser-mode
controller assertions**, **3 Python bridge tests**, **3 runner contract tests**,
**13 browser adapter/loader tests**, and the intentional exit-1 failure check.
Godot editor import and a three-frame project run completed without diagnostics.
All three fixtures passed the Python renderer. Full inherited Python and
browser-editor suites were not rerun because shared code and the adapter did
not change.

Full interactive visual acceptance remains unavailable without a display
server. These checks exercise schematic path data and live headless scene
controllers; they do not certify the appearance of crossing gaps or controls.
The Python publication adapter and mathematical JSON schema are unchanged.

## Earlier increment: signed braid word and step timeline

Built from live fork head `187c908c4e587236446419176b8e63046ace8353`.
The private Site was not redeployed or modified during this increment.

- Added strict immutable insert, replace, and delete proposals at explicit
  zero-based positions in the version-1 signed braid word. The document parser
  enforces strand ranges and word bounds; the desktop Python adapter validates
  and renders before a one-command commit. Adjacent equal or inverse terms stay
  literal. Rejected edits do not change accepted source, timeline, or history.
- Added a braid workspace with an indexed crossing inspector, entry/exit strand
  IDs, over strand ID, signed generator input, direction control, step buttons,
  discrete scrub bar, and timed play/pause. The pure record-level timeline
  computes every left-to-right strand order from the word. The schematic canvas
  draws only the selected prefix and preserves transported strand colors and
  the fixed upper-left-over-upper-right meaning of positive generators in both
  traversal directions. View direction and step are outside the mathematical
  JSON. Import resets the view to the supplied direction and full word.
- Undo/redo stops playback and preserves exact signed words. Unsaved braid
  edits survive desktop recovery with command history. Save/reopen and Python
  SVG comparisons are deterministic. Browser editing still requires explicit
  unvalidated opt-in; no publication geometry is enabled there. Also fixed
  numbered cut picking for an active new-curve draft when a point is selected.

Runtime: `4.7.2.stable.official.ed1daf0bf`; previously verified official
archive SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
Checks actually run: **175 model/controller assertions**, **119 headless desktop
scene assertions**, **38 headless web-mode controller assertions**, **3 Python
bridge tests**, **3 runner contract tests**, **13 browser-adapter/loader tests**,
and the intentionally failing harness (exit 1). The fixed Python adapter
accepted and rendered all three inherited fixtures. Godot editor import and a
three-frame project run completed without final diagnostics. Full inherited
Python and browser-editor regression suites were not rerun in this increment;
the Python library and adapter were unchanged.

This verifies deterministic record state, controller behavior, and exact
publication output. It does not visually verify control layout or crossing
over/under gaps, because a display server is unavailable. Braid playback is
currently discrete by complete crossing; it does not interpolate a crossing.

## Earlier increment: arbitrary arc and loop creation

Built on live fork head `30a21aae75a9c5a593437f726907097122d88090`.
The private Site was not redeployed or modified during this increment.

- Added a dedicated planar curve-creation workspace. Arc drafts expose a new
  validated stable ID, literal endpoints, `default`/`up`/`down` orientation,
  both optional rim sides, exact magenta `#ff00d4`, and ordered cuts. Loop
  drafts expose the same stable ID/color/cut guarantees and literal `start_up`.
  Canvas cut picking is routed to the active creation draft without changing
  the accepted record.
- Strict version-1 parsing rejects unsafe/duplicate IDs, bad endpoints, invalid
  loop parity, terminal/cyclic cancellations, nonminimal visits, and curve-limit
  overflow without trimming or correcting input. The fixed Python bridge then
  rejects geometrically unroutable candidates. Both rejection layers leave the
  accepted source and history unchanged and keep the complete draft visible.
- A successful creation appends the curve in supplied order as one command.
  Undo/redo, stable-ID selection, existing per-curve drafts, desktop recovery,
  save/reopen, and exact Python SVG/TikZ all preserve the literal record. Tests
  cover a generic outer arc and outer loop together, plus a deliberately
  unroutable narrow arc. Recovery and reopen reproduce byte-identical exports.
- Browser creation requires the existing explicit unvalidated-edit opt-in,
  remains labeled UNVALIDATED, creates no geometry result, and keeps publication
  exports disabled. An uncommitted new-curve draft is intentionally in-memory
  and guarded before open/close; accepted creations are covered by recovery.

Runtime remains `4.7.2.stable.official.ed1daf0bf`; the official archive matches
SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
Checks actually run: **152 model/controller assertions**, **98 desktop scene
assertions**, **34 web-mode controller assertions**, **3 Python bridge tests**,
**3 runner contract tests**, **13 browser-adapter/loader tests**, and the
intentional exit-1 harness. Full inherited regressions: **207 Python tests with
324 subtests** and **8 browser-editor tests** passed. Godot editor import
completed without final diagnostics, and the project started for three headless
frames during the aggregate run.

The created-curve SVG/TikZ comparisons exercise the actual Python renderer and
are byte-for-byte checks across undo/redo, recovery, save, and reopen. They are
not visual acceptance of the native form layout or canvas interaction; no
display server is available.

## Earlier increment: explicit slot-preserving row reindex

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

Josh explicitly approved pursuing a private ChatGPT Site. Deployment succeeded,
and he subsequently requested public access on 2026-09-23:
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

This is a planar point/label, curve-itinerary, row, and curve-creation editor
with signed braid-word editing, crossing picking, and a fractional braid timeline. Native curve
drawing, edit previews, and selection overlays are explicitly schematic;
publication/certified geometry still belongs to the Python renderer and bridge.
There is now a read-only supplied factor workspace with a shared deterministic
timeline and exact desktop export, plus a linked exploratory generic-disk 3D
view. The 3D view is not a certified higher-genus mesh or curve router.
Desktop recovery is
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

Extend M6 with a bounded supplied-cover walkthrough that links complete planar
steps to optional exploratory surface-view records by the same stable IDs.
Require explicit provenance and verification on every linkage, reuse the
generic disk data, and do not compute or imply a branched-cover lift.
A display-enabled pass still needs to inspect native controls, crossing gaps,
M2 forms and dialogs, and recovery before visual acceptance can be claimed.

Update this checkpoint after every meaningful implementation commit with actual
changes, tests, remaining failures, and the next concrete task. Work on generic
examples does not require waiting for Richard or Josh to supply research data.
