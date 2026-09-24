# Keyboard and accessibility controls

Surface Diagrams Studio provides a pointer-free path through the editor and
its factor, exploratory surface, and supplied walkthrough workspaces. Native
Godot controls retain their normal Tab and Shift+Tab focus behavior. Important
lists, timelines, source fields, diagram canvases, status text, and 3D views
have explicit accessibility names. Opening a secondary workspace places focus
on its primary selector; Escape returns to the editor and restores the prior
focus when that control still exists.

Status text in the editor and each secondary workspace is marked as a polite
live region. Source toggles and compact view buttons identify the exact control
or pane they reveal. The custom 2D canvas exposes the loaded diagram kind, exact
selected inspector row, braid presentation, and literal playhead through its
accessible description. The exploratory 3D view similarly exposes the selected
stable ID, hidden-record count, and orientation-label state. These descriptions
are view metadata only; updating them does not alter mathematical records.

## Editor

- Arrow keys pan a focused diagram canvas.
- `+` and `-` zoom; Home fits the diagram.
- `[` and `]` select the previous or next record in exact inspector order.
- Ctrl/Cmd+O opens JSON and Ctrl/Cmd+S saves JSON.
- Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, and Ctrl/Cmd+Y retain their existing exact
  undo/redo behavior.
- Ctrl/Cmd+1, 2, or 3 opens the factor, exploratory surface, or supplied
  walkthrough workspace.

## Mathematical edit forms

- The new-curve form links every stable-ID, endpoint, direction, and rim field
  to its visible label. Every literal cut button is announced as an append
  action with its exact cut number.
- The curve inspector distinguishes accepted curve details, the draft literal
  itinerary, and the exact apply action. Validation feedback is a polite live
  region and describes the apply control.
- The signed-braid editor names word position, signed generator, presentation,
  fractional playhead, and every symbolic timeline button. Position and
  generator fields reference both their visible labels and the explicit policy
  that supplied generators are never reduced or reordered.
- Form controls and literal cut/timeline actions have a minimum 44-pixel target.
  These semantics do not cause a draft to be accepted; the existing explicit
  validation and commit actions remain authoritative.

## Confirmation dialogs

- Unsaved-work and exact row-reindex confirmations initially focus Cancel, so
  keyboard entry lands on the non-destructive action. Recovery initially
  focuses Restore rather than the destructive Discard action.
- Each native dialog action has an explicit accessibility name and description
  that identifies whether it preserves, restores, applies, or discards data.
- Canceling unsaved work or row reindexing restores the exact control that
  opened the dialog. Confirming a reindex also restores that control after the
  single validated command is accepted. Recovery actions return to the editor.
- Opening, canceling, and navigating these dialogs does not change mathematical
  JSON, history, or drafts. The existing validation and explicit confirmation
  remain authoritative for mutations.

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
The aggregate also runs a dedicated semantic contract with Godot's dummy
accessibility driver. It verifies live-region modes, controller relationships,
form label/description relationships, touch targets, dynamic selected-record
descriptions, rejected-draft behavior, deterministic dialog focus, and
byte-identical records. The dummy
driver does not substitute for a real operating-system accessibility bridge.
The Web shell also reports the canvas content box after safe-area padding and
visual-viewport changes, so browser chrome and the on-screen keyboard do not
silently leave Godot using stale layout dimensions.
This is not a claim of screen-reader certification or visual acceptance. Those
checks still require display-enabled desktop and physical mobile environments.
