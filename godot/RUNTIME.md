# Godot runtime and checks

The development target is **Godot 4.7.2 stable, standard GDScript build**. The
Godot Foundation published this maintenance release on August 18, 2026, from
engine commit `ed1daf0bf`. The Linux x86-64 archive used for the first verified
run was the official `Godot_v4.7.2-stable_linux.x86_64.zip` with SHA-256:

```
cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
```

Official sources:

- <https://godotengine.org/article/maintenance-release-godot-4-7-2/>
- <https://github.com/godotengine/godot/releases/tag/4.7.2-stable>
- <https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html>

The engine executable is a development dependency and is not stored in this
repository. Download the standard build for your platform, verify the archive
against the digest in GitHub's release metadata, and substitute its path for
`godot` below.

```sh
godot --version
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/run_tests.gd
godot --path godot
```

Or run every engine check, the failure-harness check, and the independent Python
fixture/renderer check from the repository root:

```sh
python godot/tests/run_all.py --godot /path/to/godot
```

The GDScript test runner returns a nonzero process status when an assertion
fails. The harness itself can be checked without changing source files:

```sh
godot --headless --path godot --script res://tests/run_tests.gd -- --self-test-failure
# Expected: exit 1 and an intentional harness failure message.
```

Engine caches (`.godot/`), exported builds, and test output are ignored. Project
configuration, scenes, scripts, fixtures, and relevant generated UID files are
committed. No engine binary or export template is committed.

## Web export dependency

The matching official `Godot_v4.7.2-stable_export_templates.tpz` from the same
release was downloaded and checked against the release asset SHA-256:

```
f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011
```

Only `web_nothreads_release.zip`, `web_nothreads_debug.zip`, and `version.txt`
are needed for this slice. On Linux install them under
`~/.local/share/godot/export_templates/4.7.2.stable/`. The web preset disables
threads and extensions and retains Compatibility rendering. The export helper
fails if the exact engine version or expected loader expression changes.

The official exported engine is 39,514,754 bytes; deterministic gzip reduces it
to 10,054,758 bytes in this environment. This compression preserves all engine
bytes and is required because Sites rejected the raw source object as too large.
Godot export and Node WebAssembly compilation succeeded; neither substitutes for
executing the full application with WebGL in a real browser.

## Portable Linux review package

The pinned standard Linux runtime can also run a compiled project pack without
installing a separate export template. `desktop/build_linux.py` assembles that
runtime, the pack, and the fixed Python authority into a private directory and
tests it from outside the source checkout. See [desktop/README.md](desktop/README.md).
The package is deliberately not committed or published. Python 3 is still
required for exact geometry validation and publication.

## Display-enabled visual evidence

Headless controller checks do not establish that the interface is legible or
usable. On an actual X11 or Wayland display, capture the fixed desktop and phone
review set with:

```sh
python3 godot/visual_review/run_visual_review.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --output /tmp/surface-studio-visual-review
```

The runner refuses dummy/headless display mode and an existing output path. It
writes twelve dimension- and checksum-verified PNGs plus fixture, viewport,
selection, scroll-target, and focus metadata. All receipts remain explicitly
unreviewed until a person inspects them. See
[visual_review/README.md](visual_review/README.md).
