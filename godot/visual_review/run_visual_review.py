"""Capture fixed Studio frames on a real display and validate their evidence."""
from __future__ import annotations

from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"
ENGINE_PREFIX = "4.7.2.stable.official.ed1daf0bf"
PROFILES = {
    "desktop": (1280, 800),
    "phone-portrait": (390, 844),
    "phone-landscape": (844, 390),
}
WORKSPACES = {"editor", "factor", "surface", "walkthrough"}
FOCUS_NAMES = {
    "editor": {"Editable diagram canvas", "Mathematical records"},
    "factor": {"Selected factor support diagram", "Supplied factor before-state diagram",
               "Continuous supplied factor braid"},
    "surface": {"Linked two dimensional recipe", "Linked exploratory three dimensional view"},
    "walkthrough": {"Complete supplied before-state diagram", "Complete supplied after-state diagram"},
}


def command_for(godot: Path, output: Path, profile: str, display_driver: str | None = None):
    width, height = PROFILES[profile]
    command = [str(godot), "--path", str(PROJECT), "--single-window",
               "--audio-driver", "Dummy", "--resolution", f"{width}x{height}"]
    if display_driver:
        command += ["--display-driver", display_driver]
    command += ["--script", "res://visual_review/capture.gd", "--",
                "--output", str(output), "--profile", profile]
    return command


def png_dimensions(path: Path):
    header = path.read_bytes()[:24]
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"not a PNG with an IHDR header: {path}")
    return struct.unpack(">II", header[16:24])


def file_sha256(path: Path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_profile_receipt(receipt_path: Path, output: Path):
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("format") != "surface-diagrams-studio-visual-profile" or receipt.get("version") != 1:
        raise ValueError(f"invalid visual profile receipt: {receipt_path}")
    profile = receipt.get("profile")
    if profile not in PROFILES:
        raise ValueError(f"unknown profile in {receipt_path}: {profile}")
    width, height = PROFILES[profile]
    if receipt.get("viewport") != {"width": width, "height": height}:
        raise ValueError(f"wrong viewport in {receipt_path}")
    if receipt.get("visual_acceptance_claimed") is not False or receipt.get("manual_inspection_status") != "not-reviewed":
        raise ValueError(f"capture must remain explicitly unreviewed: {receipt_path}")
    if receipt.get("failures") != []:
        raise ValueError(f"capture reports failures: {receipt_path}")
    frames = receipt.get("frames")
    if not isinstance(frames, list) or len(frames) != 4:
        raise ValueError(f"expected four workspace frames in {receipt_path}")
    if {frame.get("workspace") for frame in frames} != WORKSPACES:
        raise ValueError(f"workspace coverage is incomplete in {receipt_path}")
    for frame in frames:
        frame_id = frame.get("id", "")
        workspace = frame.get("workspace", "")
        if frame_id != f"{profile}-{workspace}":
            raise ValueError(f"noncanonical frame ID in {receipt_path}: {frame_id}")
        image_name = frame.get("image", "")
        if not image_name or Path(image_name).name != image_name:
            raise ValueError(f"unsafe image path in {receipt_path}: {image_name}")
        image = output / image_name
        if not image.is_file() or image.stat().st_size != frame.get("image_bytes"):
            raise ValueError(f"missing or wrongly sized frame: {image}")
        if png_dimensions(image) != (width, height):
            raise ValueError(f"wrong PNG dimensions: {image}")
        if frame.get("image_width") != width or frame.get("image_height") != height:
            raise ValueError(f"receipt dimensions disagree with PNG: {image}")
        if file_sha256(image) != frame.get("image_sha256"):
            raise ValueError(f"PNG checksum mismatch: {image}")
        fixture = frame.get("fixture", "")
        if not fixture.startswith("res://fixtures/") or len(frame.get("fixture_sha256", "")) != 64:
            raise ValueError(f"fixture evidence is incomplete for {frame_id}")
        focus = frame.get("focus", {})
        if focus.get("accessibility_name") not in FOCUS_NAMES[workspace] or not focus.get("path"):
            raise ValueError(f"focus evidence is incomplete for {frame_id}")
        if not frame.get("selected_id") or frame.get("manual_inspection_status") != "not-reviewed":
            raise ValueError(f"selection or inspection status is incomplete for {frame_id}")
    return receipt


def combine_receipts(receipts):
    frames = sorted((frame for receipt in receipts for frame in receipt["frames"]),
                    key=lambda frame: frame["id"])
    return {
        "format": "surface-diagrams-studio-visual-review",
        "version": 1,
        "engine": receipts[0]["engine"],
        "engine_hash": receipts[0]["engine_hash"],
        "profiles": [receipt["profile"] for receipt in receipts],
        "display_drivers": sorted({receipt["display_driver"] for receipt in receipts}),
        "rendering_methods": sorted({receipt["rendering_method"] for receipt in receipts}),
        "manual_inspection_status": "not-reviewed",
        "visual_acceptance_claimed": False,
        "controller_acceptance": "separate evidence",
        "frames": frames,
    }


def review_markdown(manifest):
    lines = [
        "# Surface Diagrams Studio visual review",
        "",
        "This capture set is evidence awaiting human inspection. Its existence does not",
        "mean desktop, phone, WebGL, visible-focus, or screen-reader acceptance passed.",
        "",
        "## Capture set",
        "",
    ]
    for frame in manifest["frames"]:
        lines.append(f"- [ ] `{frame['image']}`: {frame['workspace']}, "
                     f"{frame['viewport']['width']}x{frame['viewport']['height']}, "
                     f"selected `{frame['selected_id']}`, focus `{frame['focus']['accessibility_name']}`, "
                     f"content `{frame['content_target']}`")
    lines += [
        "",
        "## Review questions",
        "",
        "- [ ] Text and controls are not clipped, overlapped, or hidden unexpectedly.",
        "- [ ] The recorded focused control has an unmistakable visible focus indicator.",
        "- [ ] The selected stable ID is visible and consistent across linked views.",
        "- [ ] Phone frames show usable controls and the intended scrolled content.",
        "- [ ] Braid crossings retain the fixed sign convention and clear over/under gaps.",
        "- [ ] Exploratory and supplied-data warnings remain visible and honest.",
        "",
        "Record real-browser WebGL, physical-phone, and screen-reader results separately.",
        "",
    ]
    return "\n".join(lines)


def run(command, env):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            capture_output=True, timeout=180)
    output = (result.stdout + result.stderr).strip()
    if output:
        print(output)
    if result.returncode:
        raise SystemExit(f"capture exited {result.returncode}: {' '.join(command)}")
    if any(line.startswith("ERROR:") or "SCRIPT ERROR:" in line for line in output.splitlines()):
        raise SystemExit("Godot reported a script/runtime error during visual capture")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path,
                        help="official Godot 4.7.2 standard executable")
    parser.add_argument("--output", required=True, type=Path,
                        help="new output directory for PNGs and review metadata")
    parser.add_argument("--display-driver", choices=("x11", "wayland"),
                        help="explicit real display driver; auto-detected by default")
    args = parser.parse_args()
    if not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
        raise SystemExit("visual review requires a real X11 or Wayland display; "
                         "headless capture is not visual evidence")
    if args.output.exists():
        raise SystemExit(f"refusing to replace existing visual-review output: {args.output}")
    version = subprocess.run([str(args.godot), "--version"], text=True,
                             capture_output=True, timeout=20, check=True).stdout.strip()
    if not version.startswith(ENGINE_PREFIX):
        raise SystemExit(f"expected official Godot {ENGINE_PREFIX}, got {version}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=args.output.name + ".tmp-", dir=args.output.parent))
    try:
        with tempfile.TemporaryDirectory(prefix="surface-studio-visual-user-") as user_home:
            env = os.environ.copy()
            env["XDG_DATA_HOME"] = str(Path(user_home) / "data")
            env["XDG_CONFIG_HOME"] = str(Path(user_home) / "config")
            env["XDG_CACHE_HOME"] = str(Path(user_home) / "cache")
            env["SURFACE_DIAGRAMS_PYTHON"] = sys.executable
            for profile in PROFILES:
                run(command_for(args.godot, staging, profile, args.display_driver), env)
        receipts = [validate_profile_receipt(staging / f"{profile}.json", staging)
                    for profile in PROFILES]
        manifest = combine_receipts(receipts)
        (staging / "manifest.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (staging / "REVIEW.md").write_text(review_markdown(manifest), encoding="utf-8")
        staging.rename(args.output)
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    print(f"VISUAL REVIEW EVIDENCE READY: {args.output}")
    print("Manual inspection status: not-reviewed")


if __name__ == "__main__":
    main()
