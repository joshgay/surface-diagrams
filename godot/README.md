# Surface Diagrams Studio (Godot branch)

A separate experimental project for an interactive surface-and-braid workspace:
edit mathematical records, inspect persistent strand/curve identities, scrub
transformations, and connect planar drawings with exploratory surface views.
The Python drawing library remains the authority for its supported certified
geometry and publication SVG/TikZ outputs.

**Status:** branch scaffold and development program only. The initial scene is
a workspace placeholder, not a functioning editor. No Godot binary was available
in the initial workspace, so the project has not yet been parsed or run by Godot.
The first development iteration must validate this seed and build its first
working import/view slice. Do not confuse it with the already implemented
[local browser editor](../docs/EDITOR.md), which runs without Godot.

Import `project.godot` using the standard Godot 4 editor. The first implementation
iteration must select and record an exact stable Godot 4 version, verify it from
the official release source, and make the checks reproducible. Use GDScript and
the Compatibility renderer initially; no .NET or external assets are required.
The [official Godot download page](https://godotengine.org/) and
[documentation](https://docs.godotengine.org/) are the reference sources.

See [DEVELOPMENT.md](DEVELOPMENT.md) for scope/acceptance criteria,
[STATE.md](STATE.md) for the current checkpoint, and [AGENTS.md](AGENTS.md) for
branch and automation boundaries. **No pull request until Josh approves.**

The fixtures are original generic examples in the browser editor's version-1
JSON format. They are not a mathematical relation or Richard's type (6,7) data.

