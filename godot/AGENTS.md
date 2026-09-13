# Godot Studio development boundaries

This subtree belongs to Josh Gay's long-running Godot project in
`joshgay/surface-diagrams`, branch **`codex/godot-studio`**.

- Read `DEVELOPMENT.md` and `STATE.md` before choosing work. Implement the next
  unfinished milestone; do not repeatedly replace development with planning.
- Commit and push only to `codex/godot-studio`. Never force-push. Fetch its live
  head before work and again before publishing. If it advanced, do not overwrite
  another session's work or push a divergent history.
- **Do not open a pull request for this branch.** Josh will explicitly decide
  when it is ready. Do not merge, release, deploy a website, publish a download,
  send email, or modify the separate `codex/ordered-factorizations` branch.
- Keep Godot-specific implementation, fixtures, docs, and tests under `godot/`.
  Prefer an adapter here over changing the Python library's public API. A truly
  necessary shared-code fix must be small, tested, documented, and stay on this
  branch; never quietly spread it into other branches.
- Preserve mathematical object IDs, horizontal ordering, exact itinerary and
  factor/word order, colors, and crossing sign conventions. Never infer an
  equivalence or geometric certificate from an attractive animation.
- Use original or repository-provided geometry and fixtures. Do not guess
  Richard's thirteen-factor data or label a generic demo as his construction.
- Use a dedicated clean worktree. Do not disturb a dirty worktree or an active
  foreground/session task. Hold a local exclusive lock during edits when runs
  share a filesystem. If another run is active, skip conflicting work.
- Before committing: run relevant tests, inspect changed files, exclude engine
  caches/binaries/build output, and update `STATE.md` with concrete evidence and
  the next implementation task. Report failed/unavailable checks honestly.
- Use configured tools and ordinary dependency installation only. Do not work
  around authentication, approval, hosting, or browser permission restrictions.
  No paid services, new external accounts, or runtime telemetry are needed.

