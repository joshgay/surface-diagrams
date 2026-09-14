# Surface Diagrams Studio (Godot branch)

A separate experimental project for an interactive surface-and-braid workspace:
edit mathematical records, inspect persistent strand/curve identities, scrub
transformations, and connect planar drawings with exploratory surface views.
The Python drawing library remains the authority for its supported certified
geometry and publication SVG/TikZ outputs.

**Status:** the first editor slice loads either bundled planar/braid JSON
fixture, draws an explicitly schematic native preview, and highlights stable
objects, curves, labels, and crossing indices selected in its inspector. In a
desktop planar document, drag a point or label to preview a move. Release commits only
after record and Python geometry validation; a rejected move restores the last
accepted record. Undo/redo buttons and Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, or Ctrl+Y
restore exact serialized states. The braid view remains inspection-only.

The Studio lists strand transport, exposes normalized source, pans/zooms without
changing records, and opens/saves bounded JSON. A fixed local bridge validates
the same record with the Python library and makes its exact publication SVG and
TikZ available through explicit export buttons. Bridge failure is visible and
never falls back to a purported exact result. Do not confuse this early editor
with the more complete
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

## Private browser proof of concept

Josh authorized a private ChatGPT Site proof of concept on 2026-09-14:
<https://surface-diagrams-studio.joshgay.chatgpt.site>.

This is the Godot application exported to WebAssembly, not the separate Python
browser editor. It opens the two fixtures, inspects records, pans/zooms, imports
bounded local JSON and downloads normalized JSON. Browsers cannot run the local
Python process bridge. Exact SVG/TikZ exports stay disabled. Experimental
point/label editing requires explicit opt-in and preserves record constraints
and exact undo/redo, but **does not validate curve geometry**. Downloaded files
are named `*-unvalidated.json`; the existing schema is not silently extended.
Validate those records using the Python library before publication.

Use a desktop browser with WebGL 2, WebAssembly, Web Crypto and gzip
DecompressionStream support. Real browser startup, pointer/touch input, layout,
and upload/download dialogs still need visual acceptance. There is no automatic
browser persistence: explicitly download JSON before closing or opening another
fixture. User diagrams are not uploaded to a server.

With the pinned engine and matching templates installed:

```
python3 godot/web/build_web.py --godot /path/to/godot --output godot/builds/web
```

The helper exports into a temporary directory, validates outputs, then copies
them to the requested static directory. It compresses the engine with
deterministic gzip; the browser verifies exact size and SHA-256 before supplying
an `application/wasm` response to Godot. A guarded one-expression adjustment to
the generated loader selects this path. No engine binary, cache, generated Site
assets, or Site credentials belong in this GitHub branch. The Site source
repository separately owns its static output and `.openai/hosting.json`.
