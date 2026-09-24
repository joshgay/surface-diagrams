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
