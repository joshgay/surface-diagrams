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

## Deterministic history-retention envelope

The versioned retention audit records logical data shape at the exact history
limit. It separately counts compact UTF-8 serialization of command dictionaries,
the document-source strings referenced by those commands, runtime-only snapshot
source/document slots, and the current immutable document. It also verifies
that every snapshot source and cached document exactly matches its corresponding
serialized command. The audit is deterministic and deliberately does not report
allocator, heap, resident-memory, or process measurements because Godot may
share immutable string storage.

The [retention receipt](benchmark/receipts/linux-headless-2026-09-24-retention-audit.json)
reproduced this endpoint across two complete runs of the unchanged
`bounded-m7-v1` workload:

| Retained quantity at 100 commands | Exact amount |
| --- | ---: |
| Compact serialized command equivalent | 3,036,447 bytes |
| Source text in command fields | 2,171,147 bytes |
| Runtime snapshot source slots | 1,085,572 bytes |
| Runtime immutable snapshot document slots | 1,085,572 bytes |
| Current immutable document | 10,857 bytes |
| Total logical source slots | 4,353,148 bytes |
| Runtime snapshots | 100 |
| Stale, missing, or orphaned snapshots | 0 |

Undoing and redoing the full stack must reproduce the byte-identical audit.
The 101st edit evicts both the oldest serialized command and its runtime
snapshot, and a new edit after undo clears both redo structures together.
Recovery now enforces 100 commands across undo and redo combined, matching live
history behavior rather than allowing two independent 100-command stacks.

The conservative logical source-slot ceiling is 105,119,744 bytes: two bounded
document sources per command, one snapshot source plus one snapshot document
per command, and the current document. This ceiling intentionally counts each
logical slot even where the runtime shares storage. The exercised maximum
structural fixture uses about 4.14 percent of it. Compact command serialization
is reported separately because it is an equivalent diagnostic representation,
not another retained runtime buffer.

## Document-only runtime snapshot cache

Runtime snapshot entries now retain only the already validated immutable
`DiagramDocument`. The document's cached canonical JSON is the source of truth,
so storing that same string a second time beside the document was unnecessary.
Undo and redo compare the document's canonical JSON directly with the public
serialized command. A mismatch still discards the cache path and parses the
command text through the original strict validation path.

The [document-only cache receipt](benchmark/receipts/linux-headless-2026-09-24-snapshot-document-cache.json)
reproduced the same fixtures, command serialization, snapshot count, endpoint
hashes, exact SVG/TikZ, and publication bundle across two complete runs:

| Retained quantity at 100 commands | Source + document cache | Document-only cache | Change |
| --- | ---: | ---: | ---: |
| Compact serialized command equivalent | 3,036,447 bytes | 3,036,447 bytes | unchanged |
| Runtime snapshot source slots | 1,085,572 bytes | 0 bytes | -100% |
| Runtime immutable snapshot documents | 1,085,572 bytes | 1,085,572 bytes | unchanged |
| Total logical source slots | 4,353,148 bytes | 3,267,576 bytes | -24.94% |
| Runtime snapshots | 100 | 100 | unchanged |
| Stale, missing, or orphaned snapshots | 0 | 0 | unchanged |

The conservative logical source-slot ceiling falls exactly 25 percent, from
105,119,744 to 78,905,344 bytes. Public command JSON, recovery JSON, the
100-command bound, tamper fallback, and eviction semantics are unchanged. These
remain logical retention counts, not measurements of physical process memory.
Timing differences between receipts are host observations and are not attributed
to this storage-only change.

## Compact workspace recovery history

Workspace recovery version 3 uses the version-2 compact history document table
and bounded integer command
references. A valid contiguous 100-command history can contain at most 101
distinct canonical endpoint documents, so the same document is no longer copied
into the `after` field of one command and the adjacent `before` field of the
next. Public runtime commands and version-1 recovery parsing remain unchanged.

The [compact recovery receipt](benchmark/receipts/linux-headless-2026-09-24-compact-recovery.json)
uses the 32-object, 16-curve, 32-label fixture and restores all 100 undo and redo
transitions:

| Maximum-fixture recovery quantity | Exact amount |
| --- | ---: |
| Commands | 100 |
| Distinct canonical endpoint documents | 101 |
| Version-1-equivalent history JSON | 3,051,715 bytes |
| Version-2 compact history JSON inside version 3 | 1,538,696 bytes |
| History reduction | 1,513,019 bytes (49.58%) |
| Complete version-3 envelope with native view state | 1,559,787 bytes |
| Explicit envelope bound | 33,554,432 bytes |

The exercised envelope uses 4.65 percent of the bound. The 32 MiB limit is an
explicit serialized import cap chosen above 101 logical 256 KiB document slots;
JSON string escaping also counts toward it, so encoding still rejects any actual
record that crosses the cap. Version-1 files retain their original 1 MiB limit.
Parsing all supported versions performs strict document, command, continuity,
selection, and draft validation before changing the live workspace. Versions 2
and 3 reject duplicate, unreferenced, or out-of-range document slots; version 3
also validates its separate bounded camera, braid playback, and panel state.
These byte counts describe serialized recovery data, not process memory.
