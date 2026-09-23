# Portable Linux package

Build a private x86-64 package from the pinned standard Godot runtime:

```sh
python3 godot/desktop/build_linux.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --output /tmp/surface-diagrams-studio-linux
```

The output is a directory, not a release archive:

- `SurfaceDiagramsStudio` is the verified standard Godot runtime.
- `SurfaceDiagramsStudio.pck` contains the compiled Studio project and fixtures.
- `authority/` contains the fixed adapters and a private copy of the Python
  geometry package used for validation and publication.
- `package.json` records byte counts and SHA-256 checksums.

The builder starts the package from a working directory outside the source
checkout. It requires exact planar geometry and walkthrough publication to
succeed through the sibling `authority/` directory. It then tests two expected
failures: a package with no authority directory and a package configured with a
missing Python interpreter. Both must exit nonzero with actionable diagnostics.

Python 3 remains a runtime requirement. Set `SURFACE_DIAGRAMS_PYTHON` to a
trusted interpreter when `python3` is not on PATH. An administrator may install
the fixed authority elsewhere and set `SURFACE_DIAGRAMS_AUTHORITY_ROOT`; an
explicit but incomplete directory fails without falling back elsewhere.

This build helper creates a local review package only. It does not publish,
upload, sign, release, or install the application. The official runtime and
generated package remain excluded from Git.
