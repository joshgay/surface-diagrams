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
