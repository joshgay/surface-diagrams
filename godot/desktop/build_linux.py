#!/usr/bin/env python3
"""Build and verify a private portable Linux Studio directory."""

from argparse import ArgumentParser
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot"
EXPECTED_RUNTIME = "4.7.2.stable.official.ed1daf0bf"
EXECUTABLE = "SurfaceDiagramsStudio"
PACK = EXECUTABLE + ".pck"


def command(args, cwd, expected=0, env=None, timeout=120):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True,
                            timeout=timeout, env=env)
    output = result.stdout + result.stderr
    if result.returncode != expected:
        raise RuntimeError(f"expected exit {expected}, got {result.returncode}: {' '.join(map(str, args))}\n{output[-4000:]}")
    return output


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def authority_files(package: Path) -> None:
    authority = package / "authority"
    authority.mkdir()
    for name in ("render_document.py", "build_walkthrough_bundle.py", "factor_workspace.py"):
        shutil.copy2(PROJECT / "bridge" / name, authority / name)
    shutil.copytree(ROOT / "src" / "surface_diagrams", authority / "python" / "surface_diagrams",
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    shutil.copy2(ROOT / "LICENSE", authority / "LICENSE.txt")
    (authority / "README.txt").write_text(
        "Bundled fixed Python geometry authority for Surface Diagrams Studio.\n"
        "Imported diagrams cannot select scripts, modules, commands, or paths.\n",
        encoding="utf-8")


def manifest(package: Path) -> dict:
    files = []
    for path in sorted(item for item in package.rglob("*") if item.is_file()):
        files.append({"path": path.relative_to(package).as_posix(),
                      "bytes": path.stat().st_size, "sha256": sha256(path)})
    return {"format": "surface-diagrams-studio-linux-package", "version": 1,
            "runtime": EXPECTED_RUNTIME, "architecture": "x86_64", "files": files}


def receipt(output: str) -> dict:
    marker = "PORTABLE SELF-TEST PASS "
    line = next((line for line in output.splitlines() if line.startswith(marker)), "")
    if not line:
        raise RuntimeError("portable run did not return its self-test receipt\n" + output[-4000:])
    parsed = json.loads(line.removeprefix(marker))
    if (parsed.get("format") != "surface-diagrams-studio-portable-self-test"
            or parsed.get("version") != 1 or parsed.get("authority_source") != "packaged"
            or parsed.get("publication_authority_source") != "packaged"
            or not parsed.get("geometry_ok") or not parsed.get("publication_ok")
            or parsed.get("excluded_exploratory_surface_views") != ["surface_before", "surface_after"]
            or parsed.get("failures") != []):
        raise RuntimeError("portable self-test returned an invalid receipt: " + line)
    return parsed


def verify(package: Path, temporary: Path) -> None:
    executable = package / EXECUTABLE
    run_cwd = temporary / "outside-source-checkout"
    run_cwd.mkdir()
    success = command([str(executable), "--headless", "--", "--portable-self-test"], run_cwd, timeout=45)
    receipt(success)

    absent = temporary / "without-authority"
    absent.mkdir()
    os.link(executable, absent / EXECUTABLE)
    os.link(package / PACK, absent / PACK)
    missing = command([str(absent / EXECUTABLE), "--headless", "--", "--portable-self-test"],
                      run_cwd, expected=1, timeout=45)
    if "Packaged Python authority is unavailable" not in missing:
        raise RuntimeError("missing-authority run did not explain the packaging failure\n" + missing[-4000:])

    bad_env = os.environ.copy()
    bad_env["SURFACE_DIAGRAMS_PYTHON"] = str(temporary / "missing-python")
    unavailable = command([str(executable), "--headless", "--", "--portable-self-test"],
                          run_cwd, expected=1, env=bad_env, timeout=45)
    if "Python geometry unavailable" not in unavailable:
        raise RuntimeError("missing-Python run did not explain the interpreter failure\n" + unavailable[-4000:])


def build(godot: Path, output: Path) -> dict:
    version = command([str(godot), "--version"], ROOT, timeout=20).strip()
    if not version.startswith(EXPECTED_RUNTIME):
        raise RuntimeError(f"expected {EXPECTED_RUNTIME}, got {version}")
    if output.exists():
        raise RuntimeError("output already exists; refusing to replace it: " + str(output))
    with tempfile.TemporaryDirectory(prefix="surface-studio-linux-") as directory:
        temporary = Path(directory)
        package = temporary / "package"
        package.mkdir()
        shutil.copy2(godot, package / EXECUTABLE)
        (package / EXECUTABLE).chmod((package / EXECUTABLE).stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        command([str(godot), "--headless", "--path", str(PROJECT), "--export-pack",
                 "Linux portable pack", str(package / PACK)], ROOT)
        authority_files(package)
        verify(package, temporary)
        result = manifest(package)
        (package / "package.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                                               encoding="utf-8")
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(package, output)
    return result


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = build(args.godot.resolve(), args.output.resolve())
    total = sum(item["bytes"] for item in result["files"])
    print(f"PORTABLE PACKAGE PASS: {len(result['files'])} files, {total} bytes; success, missing-authority, and missing-Python scenarios verified")
    print("Private local package: " + str(args.output.resolve()))


if __name__ == "__main__":
    main()
