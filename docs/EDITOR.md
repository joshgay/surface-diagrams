# Local diagram editor

This experimental editor is a browser interface to the existing Python library,
not a separate geometry engine. It currently edits planar diagrams and signed
braid words. It does not edit higher-genus meshes, factorization panels, arbitrary
SVG files, or Tiny Bubbles Lab pages. No Godot installation is needed.

## Start

```sh
python -m pip install .
surface-diagrams-editor
```

The command opens a browser at a newly allocated loopback port. To choose a port
or open the browser yourself:

```sh
python -m surface_diagrams.editor --port 8765 --no-browser
```

Visit the printed URL on the **same computer**. Keep the terminal running;
Ctrl+C stops the service. Do not expose or reverse-proxy this development server
to a network. Installing Python/package dependencies requires their usual access;
the running editor itself uses no internet, remote fonts, analytics, or CDN.

## Planar workflow

1. Choose **Planar**. The initial example has four marked points and one arc.
2. Set the ellipse dimensions. Use the object controls to set point/boundary
   kinds, x coordinates, and optional individual radii. Objects remain on y=0.
3. Use the P/B pattern and **Rebuild row** to change the number/order of objects.
   Rebuilding explicitly asks before clearing existing curves, because it changes
   endpoint and cut numbering. Undo restores the entire previous recipe.
4. Choose **Draw arc**, click a numbered endpoint, click the cut intervals in the
   exact visit order (if any), then click the ending endpoint. For **Draw loop**,
   select the cut itinerary and use **Finish loop**.
5. Select a curve in the list or on the drawing to edit its ID, color, direction,
   endpoints, rim choices, and itinerary. Enter cut numbers separated by spaces
   or commas. Invalid itineraries are reported, never silently simplified.
6. In select mode, drag a point horizontally or edit its x coordinate. Dragging
   cannot move it past its neighbor. To place text, use **Add label**, click the
   drawing, then edit text, size, color, and position in the sidebar.

Numbered objects run left to right from 1 through n. The outer endpoints are 0
and n+1; cuts are 0 through n. The initial defaults preserve the library's thesis
palette: blue `#006fff` marks, gray `#8b8b8b` boundaries, and magenta `#ff00d4`
curves. Boundary circles and explicit rim sides remain available.

Disjoint rendering is the default. **Allow intersections** is an explicit overlay
mode and does not certify pairwise disjointness. When rendering fails, the last
valid drawing is dimmed and cannot be edited on-canvas or exported. Correct the
recipe in the sidebar or Undo. Failed geometry is never replaced with guessed
curves or hidden crossings.

## Braid workflow

Choose **Braid**, set the strand count, and enter a signed word such as
`1, -2, 3, 1`. Select a crossing to see its entering and exiting strand IDs.
Append a generator, change its sign, move it earlier/later in the word, or delete
it. Empty words produce straight identity strands. Colors follow transported
strand identities rather than resetting at each crossing.

The editor initially reads the supplied word bottom to top; the original
top-to-bottom presentation is also selectable. **The sign convention does not
change with direction:** positive means upper-left over upper-right, so in
bottom-to-top traversal the lower-left strand passes under the lower-right.
Word order is never reversed or reduced automatically. The display does not
compute mapping-class actions, compare braid words, or prove a relation.

## Save, reopen, undo, export

- **Save JSON** downloads the entire editable recipe, not just a screenshot.
- **Open JSON** validates the document before replacing the current recipe.
  Valid-schema drafts whose geometry fails can be reopened and corrected.
  Malformed JSON, unknown fields, unsupported versions, and invalid schema data
  are rejected without discarding the current recipe. A saved schema-invalid
  draft must be corrected as JSON before it can be reopened.
- **Undo/Redo** stores up to 100 whole-recipe edits. A drag is one edit. This
  history is local to the current page and is not saved in the JSON file.
- **Export** downloads SVG, TikZ, or Python. Every export first checks the current
  geometry. JSON may still be saved while an image/code export is blocked.
- The exported Python script recreates a `DiagramDocument` and writes
  `diagram.svg` and `diagram.tikz` in its working directory. Running that script
  replaces those two files. The local server never runs uploaded Python.

Outside text fields, Ctrl/Cmd+Z undoes, Ctrl/Cmd+Shift+Z redoes, and Ctrl/Cmd+S
downloads JSON. Escape cancels the drawing tool. Browser-native text-field undo
is left intact. Zoom and fit affect only the preview, not the export geometry.
There is no autosave, account sync, or server-side file storage. Download a JSON
copy before closing the editor. Browser settings determine the download folder.

## Python document API

```python
from pathlib import Path
from surface_diagrams import DiagramDocument, save_svg, save_tikz

document = DiagramDocument.from_json(Path("study.json").read_text())
recipe = document.to_dict()  # independent editable copy
recipe["title"] = "Revised study"
document = DiagramDocument.from_dict(recipe)
save_svg(document, "study.svg", title=document.title)
save_tikz(document, "study.tikz", title=document.title)
```

Version 1 requires `format: "surface-diagrams"`, integer `version: 1`, and `kind`
equal to `planar` or `braid`. Planar recipes have `surface`, `curves`, and
`allow_intersections`; braid recipes have `braid`. Both support `title`, `style`,
and `labels`. Defaults are expanded during normalization. Unknown/duplicate JSON
fields are rejected instead of silently losing future-version data. All IDs are
stable recipe data, not automatically inferred from drawing positions.

Limits: 256 KiB per recipe, 32 objects/strands, 16 curves, 64 cut visits per curve,
128 braid generators, and 32 labels. Width/height are 20..5000; coordinates and
style sizes have finite bounds. Planar objects must be strictly left to right on
y=0. Labels enlarge both export frames when needed. Text is plain, not evaluated
LaTeX or HTML; the existing TikZ engine's font/Unicode limitations still apply.

## Security and validation status

The server binds only to 127.0.0.1, accepts exact local Host/Origin values, and
requires a per-process token on POST requests. Only three bundled assets and
fixed JSON/export endpoints are served. There is no arbitrary path, shell,
Python-evaluation, or uploaded-SVG endpoint. These protections do not turn the
standard-library development server into a multi-user hosting service.

Automated tests cover recipes, validation boundaries, reproducible exports,
geometry rejection, HTTP restrictions, and controller state with a minimal DOM
double (not a real browser). The first implementation's hosted
browser test was blocked from opening the loopback URL. **Actual visual,
pointer, and file-dialog acceptance is still pending** and should be completed
before treating this editor as release-ready:

- Draw an arc and loop; inspect numbered endpoints/cuts and itinerary order.
- Drag points and labels at different zoom levels; undo/redo each gesture.
- Edit a braid in both directions; verify crossing selection and ID transport.
- Save/reopen both document kinds; reject a malformed file without losing work.
- Download all three export types and compare them with the current recipe.
- Check keyboard focus, a narrow viewport, and long labels.

Run the checks with:

```sh
python -m unittest discover -s tests
node --check src/surface_diagrams/editor_assets/editor.js
node --test tests/editor_state.test.cjs
```

Node 20+ is used for development checks only, not to run the editor. The CI
workflow runs the Python suite and controller checks separately.
