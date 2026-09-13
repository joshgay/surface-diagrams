# Godot Studio checkpoint

- Branch: `joshgay/surface-diagrams:codex/godot-studio`.
- Starting parent: `4bd028e4052e34de429c60502e24e6686c9c2d09`, the browser-editor
  contribution on `codex/ordered-factorizations`.
- Date: 2026-09-13.
- Current milestone: **M0, not yet completed**.
- Pull request status: **not opened; explicitly prohibited until Josh approves**.

## What exists

A Godot 4 project configuration, a placeholder workspace scene, two generic
version-1 JSON fixtures, and a concrete independent implementation program.
These are newly added scaffold files. The inherited Python library and browser
editor are not new Godot contributions.

## Validation and limitations

No `godot` or `godot4` executable was found in the initial workspace. This seed
has not been imported, parsed, visually opened, or tested by Godot. It has no
interactive drawing tools, playback, 3D view, or executable mathematical model
yet. The two data fixtures were checked with the existing Python document API.
The inherited branch has 207 passing Python tests and 8 controller tests, but
those do **not** constitute Godot runtime validation.

## Next implementation task

Complete M0 and begin M1: select/install an exact stable standard Godot 4 engine
from an official source, record the version, validate/fix this project, add a
headless test runner, and implement bounded import plus a first usable fixture
view. If engine installation is unavailable, implement/test the interchange
fixtures and adapter specification without claiming the Godot project ran.

Update this checkpoint after every meaningful implementation commit with actual
changes, tests, remaining failures, and the next concrete task. Work on generic
examples does not require waiting for Richard or Josh to supply research data.

