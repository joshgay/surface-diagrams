# Display-enabled visual review

This harness captures real rendered Studio windows at three fixed logical
viewports: desktop 1280x800, phone portrait 390x844, and phone landscape
844x390. Each profile records the editor, factor sequence, exploratory surface,
and signed-braid walkthrough workspaces. The twelve PNGs have fixed fixtures,
stable-ID selections, timeline positions, scrolled content targets, and focused
controls.

Run from a clean checkout with the pinned standard engine and an actual X11 or
Wayland display:

```sh
python3 godot/visual_review/run_visual_review.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --output /tmp/surface-studio-visual-review
```

Use `--display-driver x11` or `--display-driver wayland` only when explicit
selection is necessary. The runner refuses an existing output directory and
uses isolated Godot data, config, and cache directories so local recovery state
cannot enter the evidence. It also refuses to run without `DISPLAY` or
`WAYLAND_DISPLAY`; dummy/headless textures are not accepted as visual evidence.

The output contains:

- twelve PNGs with exact pixel dimensions;
- one receipt per viewport profile;
- `manifest.json`, including fixture and PNG SHA-256 checksums, byte counts,
  viewport, selected ID, timeline, scrolled target, and focus metadata;
- `REVIEW.md`, an uncompleted human-inspection checklist.

Every generated receipt is marked `not-reviewed` and
`visual_acceptance_claimed: false`. Capturing frames proves only that the named
engine/display path rendered the recorded pixels. A reviewer must inspect the
images, and must record browser WebGL, physical-phone, and screen-reader results
separately. The harness never certifies mathematical equivalence or promotes
exploratory coordinates to publication geometry.
