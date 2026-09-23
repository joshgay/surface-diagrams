# Exploratory linked surface view

Open **Exploratory 3D** in Studio. The first M5 fixture presents the same stable
point, boundary and curve IDs in a planar recipe and in a supplied 3D model of
an oriented disk. Select a record in the list, click it in 2D, or pick it in 3D;
the other view follows that ID. Drag the 3D view to orbit, use the wheel to zoom,
and use **Fit 3D** to restore the initial camera. Hide and isolate affect only
3D visibility. Orientation labels identify `+x`, `+y`, and the front `+z` side.

This is an exploratory inspection view. The 2D `DiagramDocument` remains the
library-supported publication record. The 3D coordinates are supplied data,
not a computed lift, isotopy, certified route, equivalence, or completion of the
library's bordered higher-genus mesh. Studio never derives a 3D curve from the
2D itinerary. Camera, selection, label visibility and hidden IDs are view state
and do not appear in the mathematical JSON.

## Version-1 data contract

The envelope format is `surface-diagrams-surface-view`, version 1, and its
required status is `exploratory-supplied-geometry`. It contains:

- one complete planar version-1 `surface-diagrams` recipe;
- an oriented generic disk with bounded radius, thickness and literal color;
- one supplied 3D coordinate for every planar object, in the exact same stable-ID
  order;
- one supplied 3D polyline for every planar curve, in the exact same stable-ID
  order.

Version 1 intentionally supports only a disk. Arc polylines must begin and end
at the exact supplied coordinates of their linked internal endpoint objects.
Loop polylines must be explicitly closed. Each curve contains 2..256 finite,
bounded points. The whole UTF-8 record is limited to 256 KiB and inherits all
limits and validation from its embedded planar document. Outer-rim arc
endpoints, partial record sets, reordered IDs, unknown fields, scripts/resources,
future versions, invalid colors and unlabeled geometry status are rejected.

The bundled fixture is
[`fixtures/surfaces/disk-v1.json`](fixtures/surfaces/disk-v1.json). It is an
original generic example, not Richard's research construction. Its `arc1` 3D
polyline is visibly curved above the disk only because those five coordinates
are present in the fixture.

## Current limits

The view is read-only and has no recovery record because camera and visibility
are temporary presentation state. There is no 3D export, surface action,
animation, higher-genus mesh, depth-aware curve routing, or occlusion proof.
The line renderer is schematic. Headless tests exercise model construction,
projection-based picking and controller linkage; they are not full visual
acceptance on a display, phone GPU, or WebGL browser.
