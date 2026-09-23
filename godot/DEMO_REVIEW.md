# End-to-end demo review

The fixed `generic-review-v1` workflow checks one complete research-facing path:

1. Load the generic planar fixture and move stable point `p1` through the exact
   Python geometry validator.
2. Undo to the byte-exact original recipe and redo to the byte-exact accepted
   edit.
3. Inspect the third supplied factor at a fractional braid position and confirm
   transported strand identities in the alternate presentation direction.
4. Inspect the middle negative block of the generic signed-braid walkthrough
   while reverse playback and presentation direction remain independent.
5. Build the deterministic publication bundle for the supplied planar/3D-linked
   walkthrough and verify that exploratory 3D views are listed but excluded from
   certified geometry artifacts.

Run it from a clean checkout with the pinned engine:

```sh
python3 godot/demo/run_demo.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --receipt /tmp/surface-studio-demo.json \
  --bundle /tmp/surface-studio-demo.zip
```

The wrapper runs the workflow twice. Both normalized receipt bytes and both ZIP
bytes must match before it retains either output. The receipt contains stable
IDs, literal words, transported identities, exact-source checksums, bundle size,
and bundle checksum. It contains no timestamp, camera state, local path, or claim
that a supplied operation is mathematically verified. The ZIP remains a local
review artifact; this command does not upload or publish it.

## Display and assistive-technology review

The automated receipt does not answer these questions. Record each environment
and result separately rather than editing the deterministic receipt.

- [ ] Desktop: visible focus follows Tab and Shift+Tab through the editor, then
      returns to the invoking control after Escape from each workspace.
- [ ] Desktop: the complete edit, undo, factor, walkthrough, and publication
      path is understandable at 1280 by 800 without clipped status or controls.
- [ ] Browser/WebGL: keyboard commands match `ACCESSIBILITY.md`, upload/download
      works, and exact publication remains visibly unavailable.
- [ ] Phone portrait and landscape: primary controls have usable touch targets,
      scrolling reaches every panel, and the canvas does not steal page gestures.
- [ ] Screen reader: named lists, selectors, timelines, source fields, status
      regions, canvases, and 3D views are announced in a useful order.
- [ ] Mathematical review: stable IDs, horizontal order, endpoint/cut numbering,
      literal signed words, transported identities, and publication exclusions
      match the receipt and source fixtures.

Mark an item passed only in the named display environment. Headless controller
tests, static Web export, and receipt determinism are separate evidence.
