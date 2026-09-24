# Performance limits and observations

Studio keeps hard data limits small enough for strict validation and exact
history. Version 1 accepts at most 256 KiB per diagram, 32 planar objects, 16
curves, 32 labels, 32 braid strands, 128 signed generators, and 100 undo
commands. These are schema bounds, not claims about a display frame rate.

The fixed `bounded-m7-v1` benchmark uses every one of those structural maxima.
It also measures exact Python SVG/TikZ generation and a representative linked
walkthrough publication. See [benchmark/README.md](benchmark/README.md) for the
command and interpretation rules.

## 2026-09-24 Linux headless observation

The pinned `4.7.2.stable.official.ed1daf0bf` runtime produced the committed
[receipt](benchmark/receipts/linux-headless-2026-09-24.json) on x86-64 Linux
with the headless display driver and nine reported processors.

| Workload | Fixed units per sample | Median total | Median per unit |
| --- | ---: | ---: | ---: |
| Maximum bounded import | 80 documents | 531.468 ms | 6.643 ms/document |
| Maximum-record edit/history | 300 actions | 4,007.524 ms | 13.358 ms/action |
| Maximum braid timeline | 257 samples | 868.465 ms | 3.379 ms/sample |
| Exact maximum-planar SVG/TikZ | 1 render | 487.567 ms | 487.567 ms/render |
| Representative publication | 1 ZIP | 463.511 ms | 463.511 ms/bundle |

This establishes a useful controller baseline:

- maximum accepted records parse in single-digit milliseconds per document in
  this aggregate headless run;
- exact history at the hard record bound remains suitable for deliberate edits,
  but the benchmark does not include visible canvas redraw or input latency;
- maximum braid timeline sampling remained below a 16.7 ms frame budget per
  sample here, but no WebGL, 2D drawing, 3D drawing, or browser work is included;
- Python geometry and publication are sub-second user-initiated operations on
  this host and should not be placed inside animation frames; and
- the publication case has two planar endpoints and one step. It is explicitly
  not a measurement of the 65-document adapter bound.

The receipt enforces no timing threshold. Different hardware, process startup,
load, browser behavior, visible rendering, and assistive technology can change
the result. The deterministic fixture and output hashes verify that repeated
runs measured the same work; they do not turn the timings into correctness or
mathematical evidence.

## Parsed history snapshot comparison

The runtime-only history cache retains already validated immutable record
targets while leaving recovery JSON byte-for-byte unchanged. The follow-up
[receipt](benchmark/receipts/linux-headless-2026-09-24-history-cache.json)
repeated the same `bounded-m7-v1` workload and exact integrity outputs.

| Maximum-record history workload | Baseline | Parsed snapshots | Change |
| --- | ---: | ---: | ---: |
| 100 edits + 100 undos + 100 redos | 4,007.524 ms | 2,026.430 ms | -49.4% |
| Average across 300 actions | 13.358 ms | 6.755 ms | -49.4% |

The newer receipt also separates the phases. Median edit cost was 18.296 ms,
while cached undo and redo were 0.750 ms and 0.739 ms per action. This shows
that strict construction and validation of new maximum-size records now
dominates history cost. The cache does not relax import, recovery, or mutation
checks; if serialized command text changes, Studio discards the cached target
and parses the changed text through the original rejection path.

## Normalized edit candidate comparison

Local edits begin with a defensive dictionary copy of an accepted immutable
document. The edit path now sends that dictionary directly through the complete
schema normalizer instead of first serializing it, reparsing the JSON, and
scanning the generated text for duplicate fields. Imported files and serialized
recovery records still use the full bounded text parser. Valid and rejected
candidate tests require the internal path to produce the same normalized record
or exact schema error as that parser.

The [follow-up receipt](benchmark/receipts/linux-headless-2026-09-24-edit-candidate.json)
uses the same workload and integrity outputs:

| Maximum-record history workload | Parsed snapshots | Normalized candidates | Change |
| --- | ---: | ---: | ---: |
| 100 edits + 100 undos + 100 redos | 2,026.430 ms | 652.606 ms | -67.8% |
| 100 new edits | 1,829.615 ms | 482.105 ms | -73.6% |

The full workload is 83.7% below the original 4,007.524 ms baseline. Cached
undo and redo remain in the sub-millisecond-per-action range; their smaller
differences between receipts are normal host timing variation. These observations
do not change any correctness claim or timing threshold.

## Canonical JSON cache comparison

Every immutable `DiagramDocument` now computes its canonical normalized JSON
once at construction. History commands, recovery, checksums, saves, and bridge
calls reuse that exact string. A defensive copy remains the only public record
dictionary, so callers cannot make the cached text stale.

The [canonical JSON receipt](benchmark/receipts/linux-headless-2026-09-24-canonical-json.json)
again retains the same fixtures and integrity outputs:

| Maximum-record history workload | Normalized candidates | Canonical JSON | Change |
| --- | ---: | ---: | ---: |
| 100 edits + 100 undos + 100 redos | 652.606 ms | 528.907 ms | -19.0% |
| 100 undos | 85.494 ms | 2.340 ms | -97.3% |
| 100 redos | 68.754 ms | 1.651 ms | -97.6% |

New edits still construct and validate a new immutable document, including its
one canonical serialization, so their small difference between receipts is host
variation rather than an optimization claim. The full history workload is now
86.8% below the original 4,007.524 ms baseline.
