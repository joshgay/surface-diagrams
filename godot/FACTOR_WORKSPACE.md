# Supplied factor workspaces, version 1

Open **Factor workspace** in Studio. This separate read-only viewer preserves
the editor's current document, unapplied drafts and undo history. Choose a
factor to link its support, supplied before/after states, and continuous braid.
Picking a braid crossing selects its factor. Empty blocks have their own factor
selection but no synthetic crossing. Phone-width layouts stack the views in a
scrollable column. Mouse wheel or pinch zooms each schematic canvas; middle
mouse or one-finger drag pans it.

The factor timeline has start/end, previous/next, play/pause, scrub and display
direction controls. Each factor owns one timeline stage. A nonempty stage
reveals its literal crossings fractionally; a block with several crossings gets
proportionally more playback time. An explicit empty block receives one timed
hold with unchanged strand identities, so it cannot disappear between its
neighbors. The support and supplied before/after panels change only at factor
boundaries. They are never interpolated or presented as results of the braid.
Changing presentation direction preserves application order, signed words,
factor position and the fixed positive-crossing convention.

**Open workspace** accepts a local JSON file on desktop. **JSON import / source**
shows editable input; **Import pasted JSON** works on both desktop and browser.
A rejected import keeps the accepted workspace and selection. There is no
factor editing, recovery, or browser geometry engine yet. Pasted text is an
import buffer, not a saved mathematical edit.

The original generic fixture is
[`fixtures/workspaces/grouped-v1.json`](fixtures/workspaces/grouped-v1.json).
Its storyboard deliberately makes no claim that the displayed states are
images under the displayed factors. It is not Richard's research construction.

## Data contract

The envelope's required fields are `format`, `version`, `title`, `strands`,
`direction`, `documents`, `initial_state`, and `factors`.
`format` is `surface-diagrams-factor-workspace`; `version` is 1.
`documents` maps persistent reference IDs to complete planar version-1
`surface-diagrams` recipes. Each recipe retains its own IDs, literal cuts,
style, labels, and horizontal object order.

Each factor requires exactly these fields:

| Field | Meaning |
| --- | --- |
| `id` | Distinct persistent factor ID, not a positional index |
| `exponent` | Nonzero integer label; never expands or inverts the braid block |
| `group` | Plain-text contiguous group label, or empty string |
| `support` | Named planar diagram reference |
| `braid_word` | Complete literal signed block; `[]` explicitly supplies a straight block |
| `after` | Supplied after-state reference, or explicit `null` |

`initial_state` is also a diagram reference or `null`. For factor zero the
before-state is this supplied initial record. For a later factor it is exactly
the preceding factor's supplied `after`, including `null`. The viewer never
carries an older state forward to fill a gap. A strand permutation derived from
the literal braid word is a combinatorial calculation, not a computed surface
action. Display direction never changes the word or crossing sign.

Timeline position, play/pause, temporary display direction, selection, zoom and
camera are view state. They are intentionally absent from saved mathematical
JSON and publication export. Closing the factor viewer stops playback and leaves
the main editor's accepted document, drafts and undo history untouched.

Limits: 256 KiB UTF-8 source, 16 factors, 33 named diagrams, 1..32 strands,
128 crossings across all blocks, exponent magnitude at most 1,000,000,
120-character title, 80-character group label. IDs use the existing safe
40-character record-ID grammar. Nested recipes retain their existing limits.
Unknown fields, duplicate JSON keys/IDs, noncontiguous group reuse, unknown
references, scripts/resources, and future versions are rejected. Imports load
data only; diagram references are not paths.

## Python adapter and publication

`bridge/factor_workspace.py` independently validates the envelope and builds
`FactorPanel` / `FactorizationDiagram`. Each nested `DiagramDocument` is passed
as the panel drawing with its own style, so labels are not stripped by reducing
it to its underlying surface. The existing fixed-command geometry bridge then
returns bounded SVG/TikZ. The renderer retains native support geometry, tall
rows, contiguous groups, empty blocks and continuous strand colors.

Exact export permits either a complete initial/after-state sequence or all
states absent. Partial sequences remain viewable, but export is explicitly
unavailable because the Python `FactorizationDiagram` requires all-or-none
states. No after-state is computed and no supplied state is silently dropped.
Browser mode has no Python bridge and cannot enable these export buttons.
Successful rendering validates supported geometry, not a lift, action, product
identity, or equivalence between states.

Run the aggregate tests in `RUNTIME.md`; it includes the dedicated Godot factor
workspace suite and independent Python adapter contracts. Full UI and physical
phone visual acceptance remain separate from headless/controller checks.
