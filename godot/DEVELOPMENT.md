# Godot Studio: implementation program

## Product goal

Build a useful mathematical workspace, not a game demo or a screenshot viewer.
It should let a researcher edit a diagram, follow the same named objects across
steps and views, inspect precisely what changed, and export a reproducible
record. The significant contribution is this interactive workflow and its
reliable data/geometry bridge. New mapping-class results are not a prerequisite.

The eventual research use includes braids/local relations, curves/twists,
branched-cover views, and supplied factorization sequences. Six marked points
and genus-two examples are useful targets, but generic examples must work
independently. Do not invent the thirteen-factor type (6,7) fixture or assert
its product, lift, or equivalence. Import such a case only from explicit,
versioned source data, with provenance and verification status visible.

## Architecture and nonnegotiable conventions

- **Records first:** stable object/curve/factor IDs and ordered operations live
  outside scene nodes. Layout, zoom, animation, and camera changes do not mutate
  mathematical records. Keep serialization and undo command logic testable
  without a visible window.
- **Shared interchange:** accept the existing `DiagramDocument` version-1 planar
  and braid recipes. Preserve every supported field on round trip; reject a
  future version/unknown field instead of stripping it. Native Godot workspace
  camera/timeline data belongs in a separate versioned envelope, not an implicit
  extension of the Python document schema.
- **Geometry authority:** reuse library-generated SVG or a narrow, tested
  Drawing/primitive adapter for certified planar paths and exports. Never execute
  imported Python, arbitrary shell commands, scene resources, or scripts. File
  imports accept bounded data, not Godot executable resources. Keep any Python
  bridge explicit and local; offer clear unavailable/unsupported states.
- **Conventions:** axis objects are ordered left-to-right; endpoints are 0..n+1
  and cuts 0..n. Keep exact cut visits and supplied word/factor order. Marks are
  blue `#006fff`, boundary dots gray `#8b8b8b`, and curves magenta `#ff00d4` by
  default. Positive braid generators mean upper-left over upper-right in both
  display directions. Bottom-to-top is an explicit presentation, not a reversed
  or sign-flipped word. Colors follow strand identities across all steps.
- **Honest views:** distinguish supplied data, computed combinatorial changes,
  library-accepted geometry, and illustrative 3D motion. An animation is not a
  proof of isotopy, an intersection test, or a certificate of a lifted identity.
- **No hidden scope:** do not replace the library's unfinished bordered mesh,
  add a general mapping-class solver, or deploy Tiny Bubbles Lab as part of an
  implementation shortcut. Keep prototype limitations visible.

## Milestones and completion evidence

Complete useful vertical slices in order. Each slice needs code and tests, not
only a revised plan. Split large slices into bounded commits with clear next
steps in STATE.md.

### M0: reproducible runnable seed

Select an exact stable Godot 4 version from official sources, record its version
and ordinary installation method, open/parse the seed project, fix errors, and
add a small headless test runner with a failing exit code on assertion failures.
Document working headless import/test and interactive-launch commands. Keep
engine caches, binaries, generated UIDs as appropriate to the selected engine,
and export packages out of accidental commits. Validate which metadata Godot
expects to be committed instead of ignoring it indiscriminately.

Acceptance: a clean checkout starts, the test runner demonstrably detects a
failing assertion, and a corrected test run passes. Record real command output.

### M1: open, inspect, save an exact diagram

Implement bounded JSON import/validation and an independent record model. Show
the generic planar and braid fixtures with their IDs, colors, and source recipe.
Provide camera pan/zoom/fit without altering records. Save and reopen to retain
exact supported semantics. Include malformed/future-version/duplicate-ID and
lossless-round-trip tests. If drawing initially uses exported SVG, label that
stage as a viewer until editing works.

Acceptance: two usable fixture views, equivalent records after save/reopen,
stable identity under camera changes, no imported-code execution, and screenshots
or an explicit statement of why visual verification was unavailable.

### M2: actual 2D editing and reliable undo

Add point/label selection and movement, row editing with explicit reindexing
confirmation, ordered cut picking, curve inspector, clear geometry errors,
and command-based undo/redo. Separate drag previews from the accepted record.
Never push objects past neighbors or replace a rejected route with guessed
geometry. Build file-open/save safeguards and recoverable draft behavior.

Acceptance: create/edit/save/reopen a multi-curve drawing; undo/redo restores
exact recipes; rejected input preserves the last accepted state; geometry and
export comparison tests match the Python library.

### M3: braid editor and deterministic timeline

Add signed-word editing, crossing selection, transported strand-ID inspector,
bottom-to-top/top-to-bottom presentation, play/pause/scrub/step, and a timeline
whose endpoints match the exact supplied configurations. Keep animation time
separate from mathematical state. Use clear over/under gaps and selection.

Acceptance: both directions preserve the fixed sign convention, strand transport
matches independent fixtures, scrubbing in either direction is deterministic,
and cancelled/undone edits do not leave stale animation state.

### M4: factor sequence workspace

Import supplied factor IDs, exponents, support diagrams, braid blocks, group
labels, and complete supplied after-states. Present aligned support/state/braid
views with a common selection and timeline. Build an explicitly versioned
adapter to `FactorPanel`/`FactorizationDiagram`; do not reinterpret missing
states as computed actions. Preserve identity through tall and empty blocks.

Acceptance: generic grouped fixtures match the Python contribution's examples;
selection identifies the same factor in all views; no claimed equality/action
is inferred solely from the presentation.

### M5: linked exploratory surface view

Add a genuinely useful 3D camera and a modest, clearly labeled surface view
linked by stable IDs to the 2D diagram. Begin with a supported, unambiguous
generic surface/curve fixture. Add picking, hide/isolate, orientation labels,
and consistent view-to-view selection before complex animation.

Acceptance: record identity survives camera motion and view switching, the 3D
view exposes its illustrative versus validated status, and curves are not
silently rerouted through unsupported boundaries. No claim that the certified
bordered mesh has been completed.

### M6: explicit transformation walkthroughs

Add a reversible recorded sequence format with before/after data, selected
objects, a named operation, and verification/provenance fields. Animate supplied
twist/braid/cover examples with honest mathematical status. Any generic move
implementation needs independently tested preconditions and exact record-level
postconditions; otherwise it is a supplied walkthrough, not a solver.

Acceptance: deterministic playback and reverse scrubbing, replayable saved
sequences, preserved IDs, visible verification state, and no unsupported
product-preservation claims. Named research fixtures remain optional.

### M7: export, usability, and review gate

Finish publication SVG/TikZ/Python export through the shared geometry bridge,
workspace save/recovery, keyboard access, selection clarity, responsive panel
layout, and a tested demo walkthrough. Record unsupported cases and measured
performance limits. Test installed/packaged operation independently of a source
checkout. Do not publish binaries without Josh's approval.

Acceptance: end-to-end workflow verified visually and in tests; documentation
matches actual behavior; no unresolved data-loss or sign/order defects. Report
readiness to Josh. **Do not open a PR automatically, even when these gates pass.**

## Development iteration protocol

1. Fetch the fork branch and read its current checkpoint. Identify the next
   unfinished acceptance criterion; do not rely on old chat summaries.
2. Work in an isolated, clean worktree with a local exclusive lock when needed.
   Do not interfere with an active run or Josh's edits. If conflicting work is
   in progress, report/skip rather than create duplicate changes.
3. Implement one meaningful, tested increment in a sustained development session.
   Do not manufacture activity by regenerating unchanged assets or repeating
   planning documents. If a dependency is unavailable, do useful in-scope
   independent work and clearly record the missing validation.
4. Run relevant headless tests and visual checks. Run Python/controller regression
   tests when adapters/shared behavior change; regenerate existing figures only
   when drawing behavior could change. Record actual counts and failures.
5. Update STATE.md: files/features changed, checks performed, known issues,
   runtime version, and one concrete next task. Separate new work from inherited
   repository contents. Never mark a milestone done without its evidence.
6. Inspect the diff, commit a coherent change, fetch again, and push a fast-forward
   update only to `codex/godot-studio`. If the remote head advanced, do not force
   it back or overwrite another run. Preserve the work and report the conflict.
7. Report a concise outcome with the commit link, tests, and blocker if any.
   No PR, merge, release, deployment, email, or upstream branch write.

