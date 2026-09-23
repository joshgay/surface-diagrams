# Reproducible walkthrough publication bundles

The desktop Walkthroughs workspace can export one deterministic ZIP for any
accepted planar or braid walkthrough. The fixed Python adapter reparses every
supplied 2D `DiagramDocument` through the repository library and writes:

```
manifest.json
walkthrough.json
documents/<stable-document-id>.json
documents/<stable-document-id>.svg
documents/<stable-document-id>.tikz
documents/<stable-document-id>.py
```

`walkthrough.json` is the exact normalized Studio record. Each per-document
JSON is the Python library's normalized recipe. SVG and TikZ come directly from
that validated recipe, and the editable Python program reproduces those two
files through `DiagramDocument`. No native canvas preview is used as publication
geometry.

The version-1 manifest preserves document order, stable object/curve/label or
strand IDs, literal step references, selected records, provenance, recorded
verification, and literal braid blocks. Every artifact has a byte count and
SHA-256 digest. ZIP paths are sorted and entry metadata is fixed, so repeated
exports of the same normalized walkthrough are byte-identical.

Supplied exploratory 3D surface records remain in `walkthrough.json`. The
manifest lists them under `excluded_exploratory_surface_views`, and the archive
contains no separate mesh, curve, image, or purported certified 3D geometry.
The adapter does not compute a cover lift. Recorded verification remains source
metadata and is not promoted by export.

The adapter accepts at most 256 KiB of validated walkthrough JSON, 65 supplied
documents, and 64 steps. The resulting bundle is bounded to 64 MiB. It invokes
one fixed repository script without a shell; imported data cannot select a
command, module, script, or output path. A failed build leaves the export button
disabled and never substitutes native schematic geometry.

Browser exports remain disabled because a Web build cannot invoke the local
Python geometry authority. The command-line contract can be reproduced from a
clean checkout with:

```sh
python3 godot/bridge/build_walkthrough_bundle.py \
  godot/fixtures/walkthroughs/point-and-label-v1.json \
  /tmp/walkthrough-publication.zip
```

This creates a local review artifact only. It does not publish, upload, deploy,
or certify the walkthrough.
