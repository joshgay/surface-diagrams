# Checkpoint history

The partial P2 patch saved in commit `7daf912` has been incorporated into the
completed circular-boundary implementation and removed from the current tree.
Do not reapply it. The historical patch remains available in git history.

Read [HANDOFF.md](../HANDOFF.md) for the current status and exact next action.
P4 is in progress. `top-pair-binding.patch` preserves the unfinished Type II
boundary integration on top of commit `02eaf4d` and uses the experimental
`genus_outer_mesh.py` helper. It is not an accepted implementation.

The edge-chart helper has regression coverage for explicit rim IDs, matching
front/back seams, reverse traversal, multiple pairs, and all four views. The
patch still fails the whole-cell certificate on the default genus-two top pair.
An inward rim and its collar have opposing tangents at their shared anchor,
creating a projection cusp. The current strictly positive radial-triangle model
cannot represent this local chart. Adding more grid rows or collar samples did
not solve that mathematical issue.

To resume the prototype, first run `git apply --check docs/checkpoints/top-pair-binding.patch`,
then apply it in an isolated checkout and run:

```python
from surface_diagrams import GenusSurface, BoundaryPair
GenusSurface(2, type_ii=(BoundaryPair(),)).cut_system()
```

The latest failing carrier was `front` quad 204, adjacent to the lower rim's
left anchor. Preserve the strict certification gate: either supply a valid local
cusp chart with justified endpoint degeneracy, or use a different explicit sheet
partition. Do not replace failure with an unchecked interpolation or call the
boundary SVG certified. The public binding retains its unsupported error until
that work passes.
