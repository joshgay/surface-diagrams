# Keyboard and accessibility controls

Surface Diagrams Studio provides a pointer-free path through the editor and
its factor, exploratory surface, and supplied walkthrough workspaces. Native
Godot controls retain their normal Tab and Shift+Tab focus behavior. Important
lists, timelines, source fields, diagram canvases, status text, and 3D views
have explicit accessibility names. Opening a secondary workspace places focus
on its primary selector; Escape returns to the editor and restores the prior
focus when that control still exists.

## Editor

- Arrow keys pan a focused diagram canvas.
- `+` and `-` zoom; Home fits the diagram.
- `[` and `]` select the previous or next record in exact inspector order.
- Ctrl/Cmd+O opens JSON and Ctrl/Cmd+S saves JSON.
- Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, and Ctrl/Cmd+Y retain their existing exact
  undo/redo behavior.
- Ctrl/Cmd+1, 2, or 3 opens the factor, exploratory surface, or supplied
  walkthrough workspace.

## Secondary workspaces

- Factor workspace: Left/Right steps factors, Home/End jumps, Space plays or
  pauses, and D changes only the braid presentation direction.
- Exploratory surface workspace: Up/Down selects stable IDs, Home selects the
  first ID, F fits the 3D camera, H hides, I isolates, and A shows all.
- Supplied walkthrough: Left/Right steps, Home/End jumps, Space plays or
  pauses, R reverses playback, and B changes only signed-braid presentation.
- A focused 3D view uses arrow keys to orbit, `+`/`-` to zoom, and Home to fit.
- On compact screens, touch-sized view-switcher buttons place one linked canvas
  at a time in the content region. They participate in ordinary Tab navigation;
  switching them changes no supplied record or stable-ID selection.
- If an orientation change or on-screen keyboard resize crosses the compact
  breakpoint, the linked view containing keyboard focus becomes the active
  compact view before sibling columns are hidden. The workspace then scrolls
  that focused control into the reachable content region. The editor likewise
  follows focused inspector/source controls into the Records pane instead of
  replacing them with the Diagram pane.
- Escape returns from any secondary workspace to the editor.

These commands modify selection, camera, visibility, or playback state only.
They do not renumber, simplify, reroute, or otherwise change a mathematical
record. Text-entry fields keep ordinary editing keys instead of triggering
workspace shortcuts.

The controller tests exercise these paths at 320, 390, 844, and 1280 pixel
widths, including portrait and landscape compact-view switching. A separate
focus contract shrinks a desktop layout to 390 pixels wide, and the editor
source case also contracts to 360 pixels high to model a virtual keyboard.
The Web shell also reports the canvas content box after safe-area padding and
visual-viewport changes, so browser chrome and the on-screen keyboard do not
silently leave Godot using stale layout dimensions.
This is not a claim of screen-reader certification or visual acceptance. Those
checks still require display-enabled desktop and physical mobile environments.
