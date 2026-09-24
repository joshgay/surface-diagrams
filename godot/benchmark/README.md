# Bounded performance benchmark

Run the fixed M7 benchmark with the pinned Godot runtime:

```sh
python3 godot/benchmark/run_benchmark.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --receipt /tmp/surface-diagrams-studio-benchmark.json
```

The runner executes the complete benchmark twice. The two runs must use the
same normalized fixture fingerprints and produce the same history, geometry,
and publication hashes. Timing samples are intentionally not compared between
runs because elapsed time changes with the host and current load.

The fixed workload covers:

- 40 maximum planar plus 40 maximum braid imports per sample;
- the complete 100-command history limit followed by exact undo and redo;
- 257 timeline samples over 32 strands and 128 signed generators;
- exact SVG and TikZ generation for the maximum planar fixture; and
- a representative linked walkthrough publication bundle.

The receipt includes raw microsecond samples, min/median/max summaries, the
schema limits exercised, and deterministic integrity fingerprints. It enforces
no timing threshold. A faster or slower result does not prove or disprove
correctness, mathematical validity, visual quality, or suitability on another
machine. Publication is deliberately representative rather than a claim about
the largest possible 65-document bundle.

The integrity profile also contains a versioned history-retention audit at the
100-command endpoint. It reports compact serialized-command bytes, logical
source bytes, runtime snapshot counts, cache alignment, and the conservative
schema envelope. These are deterministic logical quantities, not allocator,
heap, resident-memory, or process measurements; immutable string storage may be
shared by the engine. Current snapshots retain only immutable documents, so the
audit requires zero separately stored snapshot-source bytes.

History measurements also contain separate edit, undo, and redo phase samples.
Their sum is the recorded total for each sample, allowing changes to record
construction and history navigation to be distinguished without changing the
fixed workload.

The committed receipts intentionally retain successive measurements of the
same workload. This makes history-cache and normalized-edit changes comparable
while deterministic fixture and result hashes guard against measuring different
records or outcomes.

The benchmark requires the same trusted local Python geometry authority as the
desktop application. It is excluded from Web and portable application packs.
