# Parked P2 work

`p2-circular-boundaries.patch` preserves the unfinished work from before the
September 11 nonplanar refinement. It is **not applied** to the main checkout.
The ordinary package therefore contains only completed features at this checkpoint.

To resume from the repository root with a clean working tree:

```powershell
git apply --check docs/checkpoints/p2-circular-boundaries.patch
git apply docs/checkpoints/p2-circular-boundaries.patch
```

The patch adds `Style(boundary_shape="circle")`, an automatic radius of 12,
outlined circular planar holes, separation checks, analytical trimming of arc
endpoints to hole rims, and guide labels raised above the rims. Existing dot
behavior remains the default. It changes only `model.py`, `layout.py`, and
`curves.py`. It has passed the old test suite, but has no dedicated P2 tests yet.

Remaining work before claiming P2 complete:

1. Inspect the analytical trimming for straight/curved arcs, both directions,
   both ends, explicit radii, aspect ratios, and arcs with intermediate cuts.
   The current SVG ellipse commands need to preserve the original arc center
   after trimming. Check geometry, not just text snapshots.
2. Ensure curve strokes and guide lines never appear inside circular holes.
   The existing patch has no clipping of stroke caps, loops, or guide lines.
   Avoid white masking so transparent/colored backgrounds remain correct.
   Review the router's collision checks against true circular obstacles.
3. Add default horizontal circle rows, mixed holes/marks, rim-ended arcs, loops,
   numbered guides, radius overrides, and colored-background examples/tests.
   Confirm old dot output remains unchanged.
4. Keep TikZ geometry extensions for P7. The current TikZ arc writer expects
   whole half-ellipses with endpoints on the axis. Report unsupported new
   geometry explicitly until that stage rather than emitting incorrect TikZ.
   Update gallery/export tests to distinguish supported SVG-only scenarios.
5. Run the P2 gate in `docs/IMPLEMENTATION_PLAN.md`, visually inspect outputs,
   update `docs/HANDOFF.md`, and commit/push. Remove this patch only after its
   work has been incorporated and verified.

General planar arrangements and daisy intersections remain P5. Genus arcs and
closed curves remain P4, after the cut-system topology work in P3.
