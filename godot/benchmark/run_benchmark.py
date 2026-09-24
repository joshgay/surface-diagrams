#!/usr/bin/env python3
"""Run and validate the fixed bounded Studio benchmark twice."""

from argparse import ArgumentParser
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"
EXPECTED_RUNTIME = "4.7.2.stable.official.ed1daf0bf"
MEASUREMENTS = {
    "bounded-import": (5, 80),
    "edit-undo-redo": (5, 300),
    "braid-timeline": (5, 257),
    "exact-svg-tikz": (5, 1),
    "publication-bundle": (3, 1),
}


def invoke(godot: Path, receipt: Path) -> str:
    result = subprocess.run(
        [str(godot), "--headless", "--path", str(PROJECT), "--script",
         "res://benchmark/run_benchmark.gd", "--", f"--receipt={receipt}"],
        cwd=ROOT, text=True, capture_output=True, timeout=120,
    )
    output = result.stdout + result.stderr
    if result.returncode != 0 or "BENCHMARK PASS" not in output:
        raise SystemExit("bounded benchmark failed:\n" + output[-6000:])
    return output


def validate(path: Path) -> dict:
    if not path.is_file() or path.stat().st_size > 128 * 1024:
        raise SystemExit("benchmark receipt is missing or exceeds 128 KiB")
    receipt = json.loads(path.read_text(encoding="utf-8"))
    if receipt.get("format") != "surface-diagrams-studio-benchmark" or receipt.get("version") != 1:
        raise SystemExit("unsupported benchmark receipt")
    if receipt.get("workload") != "bounded-m7-v1" or receipt.get("runtime") != EXPECTED_RUNTIME:
        raise SystemExit("benchmark workload or runtime is not the pinned version")
    interpretation = receipt.get("interpretation", {})
    if (interpretation.get("status") != "performance-observation-only"
            or interpretation.get("timings_establish_correctness") is not False
            or interpretation.get("thresholds_enforced") is not False):
        raise SystemExit("benchmark overstates what timing observations establish")
    measurements = receipt.get("measurements", [])
    if [item.get("id") for item in measurements] != list(MEASUREMENTS):
        raise SystemExit("benchmark measurements are missing or reordered")
    for item in measurements:
        sample_count, units = MEASUREMENTS[item["id"]]
        samples = item.get("samples_us", [])
        if (item.get("sample_count") != sample_count or len(samples) != sample_count
                or item.get("units_per_sample") != units
                or any(type(value) is not int or value <= 0 or value > 120_000_000 for value in samples)):
            raise SystemExit("benchmark measurement is unbounded or malformed: " + item["id"])
        ordered = sorted(samples)
        if (item.get("minimum_us") != ordered[0] or item.get("median_us") != ordered[len(ordered) // 2]
                or item.get("maximum_us") != ordered[-1]):
            raise SystemExit("benchmark summary does not match raw samples: " + item["id"])
        if item["id"] == "edit-undo-redo" and "phases" in item:
            phases = item["phases"]
            if set(phases) != {"edit", "undo", "redo"}:
                raise SystemExit("history timing phases are missing")
            for phase in phases.values():
                phase_samples = phase.get("samples_us", [])
                if (len(phase_samples) != sample_count
                        or any(type(value) is not int or value <= 0 for value in phase_samples)):
                    raise SystemExit("history timing phase is malformed")
            if any(sum(item["phases"][name]["samples_us"][index]
                       for name in ("edit", "undo", "redo")) != samples[index]
                   for index in range(sample_count)):
                raise SystemExit("history timing phases do not sum to the total")
    integrity = receipt.get("integrity", {})
    hashes = [value for key, value in integrity.items() if key.endswith("sha256")]
    if len(hashes) != 5 or any(type(value) is not str or len(value) != 64 for value in hashes):
        raise SystemExit("benchmark integrity fingerprints are incomplete")
    if (integrity.get("timeline_final_paths") != 32
            or integrity.get("timeline_final_crossings") != 128
            or integrity.get("publication_documents") != ["disk_before", "disk_after"]
            or integrity.get("excluded_exploratory_surface_views") != ["surface_before", "surface_after"]):
        raise SystemExit("benchmark integrity endpoint is unexpected")
    retention = integrity.get("history_retention", {})
    totals, bounds = retention.get("totals", {}), retention.get("bounds", {})
    if (retention.get("format") != "surface-diagrams-history-retention"
            or retention.get("version") != 1
            or retention.get("history_limit") != 100
            or retention.get("cache_aligned") is not True
            or retention.get("within_source_bounds") is not True
            or totals.get("command_count") != 100
            or totals.get("snapshot_count") != 100
            or totals.get("stale_snapshot_count") != 0
            or totals.get("missing_snapshot_count") != 0
            or totals.get("orphan_snapshot_count") != 0
            or totals.get("snapshot_source_bytes") != 0
            or bounds.get("maximum_snapshot_source_bytes") != 0
            or not 0 < totals.get("serialized_command_bytes", 0) < 128 * 1024 * 1024
            or not 0 < totals.get("logical_source_bytes", 0) <= bounds.get("maximum_logical_source_bytes", 0)):
        raise SystemExit("history retention audit is malformed or outside its bound")
    recovery = integrity.get("workspace_recovery", {})
    if (recovery.get("ok") is not True
            or recovery.get("version") != 3
            or recovery.get("commands") != 100
            or recovery.get("documents") != 101
            or recovery.get("initial_matches") is not True
            or recovery.get("final_matches") is not True
            or recovery.get("cache_aligned") is not True
            or recovery.get("maximum_envelope_bytes") != 32 * 1024 * 1024
            or not 0 < recovery.get("compact_history_bytes", 0) < recovery.get("legacy_history_bytes", 0)
            or recovery.get("saved_history_bytes") != recovery["legacy_history_bytes"] - recovery["compact_history_bytes"]
            or not 0 < recovery.get("envelope_bytes", 0) <= recovery["maximum_envelope_bytes"]
            or any(type(recovery.get(key)) is not str or len(recovery[key]) != 64
                   for key in ("initial_sha256", "final_sha256"))):
        raise SystemExit("compact workspace recovery is malformed or outside its bound")
    return receipt


def deterministic_profile(receipt: dict) -> dict:
    return {key: receipt[key] for key in ("format", "version", "workload", "runtime", "bounds", "fixtures", "integrity")}


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--receipt", required=True, type=Path)
    args = parser.parse_args()
    version = subprocess.run([str(args.godot), "--version"], text=True,
                             capture_output=True, timeout=20, check=True).stdout.strip()
    if not version.startswith(EXPECTED_RUNTIME):
        raise SystemExit(f"expected {EXPECTED_RUNTIME}, got {version}")
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="surface-studio-benchmark-") as directory:
        temporary = Path(directory)
        first_path, second_path = temporary / "first.json", temporary / "second.json"
        first_output = invoke(args.godot.resolve(), first_path)
        invoke(args.godot.resolve(), second_path)
        first, second = validate(first_path), validate(second_path)
        if deterministic_profile(first) != deterministic_profile(second):
            raise SystemExit("two benchmark runs used different fixtures or produced different integrity outputs")
        shutil.copyfile(first_path, args.receipt)
        medians = ", ".join(f"{item['id']}={item['median_us']} us" for item in first["measurements"])
        print(first_output.split("BENCHMARK PASS", 1)[0].strip())
        print("BOUNDED BENCHMARK PASS: deterministic workload and integrity profile reproduced twice")
        print("Observed medians: " + medians)
        print("Receipt: " + str(args.receipt.resolve()))


if __name__ == "__main__":
    main()
