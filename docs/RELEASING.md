# Publishing and releases

Build the portable site with `python examples/build_site.py`. This checks local
HTML links and writes `public/`. Preview with `python -m http.server 8000 --directory public`.
Edit individual mathematical entries in `docs/catalog/*.json`; all content is
escaped as text. Supply sources, surface conventions, factor IDs and explicit
equivalence steps before changing an entry's Planned status.

## GitLab Pages

Push this repository to the chosen GitLab project. The default-branch pipeline
runs tests, checks regenerated figures, builds the site and deploys `public/`.
Find the actual URL under Deploy > Pages after the pipeline succeeds. All local
URLs are relative so project-subpath hosting works. The GitHub origin can remain.
Configuration follows https://docs.gitlab.com/user/project/pages/ .

## Versioned releases

1. Update `pyproject.toml`, the site version and `CHANGELOG.md` together.
2. Run the full tests, regenerate tutorial figures, build the site, and check CI.
3. Commit the reviewed changes, then tag with `v` plus the package version
   (for this batch, `v0.1.0a3`) and push the commit and tag.
4. The GitHub release workflow builds wheel/source archives, checks metadata,
   and attaches them to an alpha prerelease. It does not publish to PyPI.

The GitLab destination and live deployment must be verified separately; a local
site build does not imply a published site or an existing release.
