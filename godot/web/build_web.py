"""Export the pinned Godot browser prototype, with its trusted file adapter.

The output is static website content, not a Python/server application. Run this
from a source checkout. Engine binaries/templates are separate dependencies.
"""
import argparse
import gzip
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2.stable.official.ed1daf0bf"


def run(command):
    result = subprocess.run(command, text=True, capture_output=True, timeout=180)
    output = result.stdout + result.stderr
    if result.returncode or "SCRIPT ERROR:" in output or any(
        line.startswith("ERROR:") for line in output.splitlines()
    ):
        raise SystemExit(output)
    return output.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if run([args.godot, "--version"]) != VERSION:
        raise SystemExit("Use the pinned official Godot " + VERSION)
    run([args.godot, "--headless", "--path", str(PROJECT), "--editor", "--quit"])
    # Never expose a partly exported build. Only copy after validation passes.
    with tempfile.TemporaryDirectory(prefix="surface-studio-web-") as temporary:
        stage = Path(temporary)
        run([args.godot, "--headless", "--path", str(PROJECT), "--export-release",
             "Web proof of concept", str(stage / "index.html")])
        shutil.copyfile(PROJECT / "web" / "browser_files.js", stage / "browser_files.js")
        html = (stage / "index.html").read_text()
        if 'src="browser_files.js"' not in html:
            raise SystemExit("Generated HTML does not load the trusted browser adapter")
        for name in ["index.html", "index.js", "index.wasm", "index.pck", "browser_files.js"]:
            if not (stage / name).is_file() or not (stage / name).stat().st_size:
                raise SystemExit("Missing/empty web asset: " + name)
        with (stage / "index.wasm").open("rb") as wasm:
            if wasm.read(8) != b"\0asm\x01\0\0\0":
                raise SystemExit("Invalid WebAssembly header")
        # Sites source storage rejected the 39 MB uncompressed object. Deliver
        # gzip as static data and verify/decompress it in the browser, preserving
        # the exact official engine bytes. No HTTP content-encoding rule needed.
        wasm_path = stage / "index.wasm"
        wasm = wasm_path.read_bytes()
        compressed = gzip.compress(wasm, compresslevel=9, mtime=0)
        if gzip.decompress(compressed) != wasm:
            raise SystemExit("Engine compression round trip failed")
        (stage / "index.wasm.gz").write_bytes(compressed)
        loader = (PROJECT / "web" / "wasm_loader.js").read_text()
        loader = loader.replace("__WASM_SHA256__", hashlib.sha256(wasm).hexdigest())
        loader = loader.replace("__WASM_BYTES__", str(len(wasm)))
        (stage / "wasm_loader.js").write_text(loader)
        engine_path = stage / "index.js"
        engine = engine_path.read_text()
        original = 'preloader.loadPromise(`${loadPath}.wasm`, size, true)'
        replacement = 'SurfaceStudioLoader.loadWasm(`${loadPath}.wasm.gz`, size)'
        if engine.count(original) != 1:
            raise SystemExit("Godot loader changed; review compression adapter before export")
        engine_path.write_text(engine.replace(original, replacement))
        wasm_path.unlink()
        # Drop only a prior uncompressed build product if the destination has it.
        (args.output / "index.wasm").unlink(missing_ok=True)
        args.output.mkdir(parents=True, exist_ok=True)
        for asset in sorted(stage.iterdir()):
            shutil.copyfile(asset, args.output / asset.name)
            print(f"{asset.name}: {asset.stat().st_size} bytes")
    print("Web export complete. This is not browser/WebGL acceptance.")


if __name__ == "__main__":
    main()
