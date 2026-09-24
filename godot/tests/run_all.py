"""Run the reproducible Godot/Python checks from the repository root."""
from pathlib import Path
import argparse
import os
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"


def run(command, expected=0):
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
    except subprocess.TimeoutExpired:
        raise SystemExit("Check exceeded 120 seconds: " + " ".join(map(str, command)))
    output = (result.stdout + result.stderr).strip()
    if output:
        print(output)
    if result.returncode != expected:
        raise SystemExit(f"expected exit {expected}, got {result.returncode}: {' '.join(map(str, command))}")
    if expected == 0 and any(line.startswith("ERROR:") or "SCRIPT ERROR:" in line
                             for line in output.splitlines()):
        raise SystemExit("Godot reported a runtime/script error despite exit 0: " +
                         " ".join(map(str, command)))
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT4", "godot"),
                        help="Godot 4.7.2 standard executable (or GODOT4)")
    args = parser.parse_args()
    version = run([args.godot, "--version"])
    if not version.startswith("4.7.2.stable.official.ed1daf0bf"):
        raise SystemExit("expected official Godot 4.7.2 build ed1daf0bf, got " + version)
    run([args.godot, "--headless", "--path", str(PROJECT), "--editor", "--quit"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/run_tests.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/ui_smoke.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/braid_interaction.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/web_mode_smoke.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/mobile_smoke.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/factor_workspace.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/surface_view.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/walkthrough.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/walkthrough_braid.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/walkthrough_cover.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/walkthrough_publication.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/keyboard_accessibility.gd"])
    run([args.godot, "--headless", "--accessibility", "always", "--accessibility-driver", "dummy",
         "--path", str(PROJECT), "--script", "res://tests/accessibility_semantics.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/modal_focus.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/visual_review.gd"])
    run([args.godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/python_authority.gd"])
    with tempfile.TemporaryDirectory(prefix="surface-studio-demo-") as directory:
        run([sys.executable, str(PROJECT / "demo" / "run_demo.py"),
             "--godot", args.godot,
             "--receipt", str(Path(directory) / "receipt.json"),
             "--bundle", str(Path(directory) / "bundle.zip")])
    with tempfile.TemporaryDirectory(prefix="surface-studio-benchmark-") as directory:
        run([sys.executable, str(PROJECT / "benchmark" / "run_benchmark.py"),
             "--godot", args.godot,
             "--receipt", str(Path(directory) / "receipt.json")])
    with tempfile.TemporaryDirectory(prefix="surface-studio-linux-test-") as directory:
        run([sys.executable, str(PROJECT / "desktop" / "build_linux.py"),
             "--godot", args.godot,
             "--output", str(Path(directory) / "package")])
    run(["node", "--test", str(PROJECT / "tests" / "browser_files.test.cjs")])
    run(["node", "--test", str(PROJECT / "tests" / "viewport.test.cjs")])
    run(["node", "--test", str(PROJECT / "tests" / "wasm_loader.test.cjs")])
    failure = run([args.godot, "--headless", "--path", str(PROJECT), "--script",
                   "res://tests/run_tests.gd", "--", "--self-test-failure"], expected=1)
    if "intentional harness failure" not in failure:
        raise SystemExit("failure harness returned 1 without reporting its assertion")
    run([args.godot, "--headless", "--path", str(PROJECT), "--quit-after", "3"])

    run([sys.executable, str(PROJECT / "tests" / "test_geometry_bridge.py")])
    run([sys.executable, str(PROJECT / "tests" / "test_factor_workspace.py")])
    run([sys.executable, str(PROJECT / "tests" / "test_run_all.py")])
    run([sys.executable, str(PROJECT / "tests" / "test_walkthrough_bundle.py")])
    run([sys.executable, str(PROJECT / "visual_review" / "test_visual_review.py")])

    # The existing Python implementation independently checks both shared
    # fixture recipes and publication SVG generation.
    sys.path.insert(0, str(ROOT / "src"))
    from surface_diagrams import DiagramDocument
    for fixture in sorted((PROJECT / "fixtures").glob("*.json")):
        document = DiagramDocument.from_json(fixture.read_text(encoding="utf-8"))
        if not document.render_svg().startswith("<svg"):
            raise SystemExit(f"Python renderer failed for {fixture}")
        print(f"Python accepted {fixture.name} and rendered SVG")
    print("ALL CHECKS PASSED")


if __name__ == "__main__":
    main()
