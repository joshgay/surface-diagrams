# Surface Diagrams Studio (Godot branch)

A separate experimental project for an interactive surface-and-braid workspace:
edit mathematical records, inspect persistent strand/curve identities, scrub
transformations, and connect planar drawings with exploratory surface views.
The Python drawing library remains the authority for its supported certified
geometry and publication SVG/TikZ outputs.

**Status:** the working viewer slice loads either bundled planar/braid JSON
fixture, draws an explicitly schematic native preview, and highlights stable
objects, curves, labels, and crossing indices selected in its inspector. It
lists strand transport, exposes normalized source, pans/zooms without changing
records, and opens/saves bounded JSON. A fixed local bridge validates the same
record with the Python library and makes its exact publication SVG and TikZ
available through explicit export buttons. Bridge failure is visible and never
falls back to a purported exact result. It is not yet an editor. Do not confuse
it with the already implemented
[local browser editor](../docs/EDITOR.md), which runs without Godot.

Import `project.godot` using Godot 4.7.2 stable. The exact runtime, checksum, and
commands are in [RUNTIME.md](RUNTIME.md). Use GDScript and the Compatibility
renderer; no .NET or external assets are required.
The [official Godot download page](https://godotengine.org/) and
[documentation](https://docs.godotengine.org/) are the reference sources.

See [DEVELOPMENT.md](DEVELOPMENT.md) for scope/acceptance criteria,
[STATE.md](STATE.md) for the current checkpoint, and [AGENTS.md](AGENTS.md) for
branch and automation boundaries. **No pull request until Josh approves.**

The fixtures are original generic examples in the browser editor's version-1
JSON format. They are not a mathematical relation or Richard's type (6,7) data.
