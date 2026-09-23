#!/usr/bin/env python3
"""Run the fixed Studio review workflow twice and retain identical artifacts."""

from argparse import ArgumentParser
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"
EXPECTED_RUNTIME = "4.7.2.stable.official.ed1daf0bf"


def run_once(godot: Path, receipt: Path, bundle: Path) -> str:
    command = [str(godot), "--headless", "--path", str(PROJECT), "--script",
               "res://demo/run_demo.gd", "--", f"--receipt={receipt}",
               f"--bundle={bundle}"]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
    output = result.stdout + result.stderr
    if result.returncode != 0 or "DEMO WORKFLOW PASS" not in output:
        raise SystemExit("demo workflow failed:\n" + output[-4000:])
    return output


def validate(receipt_path: Path, bundle_path: Path) -> dict:
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("format") != "surface-diagrams-studio-demo-receipt" or receipt.get("version") != 1:
        raise SystemExit("demo returned an unsupported receipt")
    expected = ["validated-edit", "exact-history", "linked-factor-review",
                "signed-braid-walkthrough", "deterministic-publication"]
    if [item.get("id") for item in receipt.get("checks", [])] != expected:
        raise SystemExit("demo receipt is missing or reorders required checks")
    publication = receipt["checks"][-1]
    data = bundle_path.read_bytes()
    import hashlib
    if len(data) != publication["bundle_bytes"] or hashlib.sha256(data).hexdigest() != publication["bundle_sha256"]:
        raise SystemExit("demo bundle does not match its receipt")
    return receipt


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--bundle", required=True, type=Path)
    args = parser.parse_args()
    version = subprocess.run([str(args.godot), "--version"], text=True,
                             capture_output=True, timeout=20, check=True).stdout.strip()
    if not version.startswith(EXPECTED_RUNTIME):
        raise SystemExit(f"expected {EXPECTED_RUNTIME}, got {version}")
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.bundle.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="surface-studio-demo-") as directory:
        temporary = Path(directory)
        first_receipt, second_receipt = temporary / "first.json", temporary / "second.json"
        first_bundle, second_bundle = temporary / "first.zip", temporary / "second.zip"
        first_output = run_once(args.godot, first_receipt, first_bundle)
        run_once(args.godot, second_receipt, second_bundle)
        first = validate(first_receipt, first_bundle)
        second = validate(second_receipt, second_bundle)
        if first_receipt.read_bytes() != second_receipt.read_bytes() or first_bundle.read_bytes() != second_bundle.read_bytes() or first != second:
            raise SystemExit("two clean demo runs did not produce identical artifacts")
        shutil.copyfile(first_receipt, args.receipt)
        shutil.copyfile(first_bundle, args.bundle)
        print(first_output.split("DEMO WORKFLOW PASS", 1)[0].strip())
        print(f"DEMO REVIEW PASS: deterministic receipt {args.receipt} and bundle {args.bundle}")


if __name__ == "__main__":
    main()
