"""Compare the public ChatGPT Site with a tested Studio Web build.

This check is read-only. It never publishes, deploys, or downloads the large
Godot engine assets. A valid ``studio-build.json`` is enough to identify the
exact source and asset bytes that a Site publication claims to contain.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


SITE = "https://surface-diagrams-studio.joshgay.chatgpt.site"
MANIFEST_LIMIT = 64 * 1024
FORMAT = "surface-studio-web-build"
VERSION = 1
ENGINE = "4.7.2.stable.official.ed1daf0bf"
ASSETS = {"index.pck", "index.wasm.gz"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REVISION = re.compile(r"^[0-9a-f]{40}$")


class SiteCheckError(ValueError):
    """The Site response cannot identify a trusted Studio build."""


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise SiteCheckError(f"Duplicate manifest field: {key}")
        result[key] = value
    return result


def parse_manifest(payload: bytes) -> dict:
    if len(payload) > MANIFEST_LIMIT:
        raise SiteCheckError("Site build manifest exceeds 64 KiB.")
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError as error:
        raise SiteCheckError("Site build manifest is not UTF-8.") from error
    if text.lstrip().lower().startswith("<!doctype html"):
        raise SiteCheckError(
            "The Site returned its HTML application shell instead of "
            "studio-build.json; this is a legacy publication without build identity."
        )
    try:
        manifest = json.loads(text, object_pairs_hook=_unique_object)
    except (json.JSONDecodeError, SiteCheckError) as error:
        if isinstance(error, SiteCheckError):
            raise
        raise SiteCheckError("Site build manifest is not valid JSON.") from error
    if not isinstance(manifest, dict):
        raise SiteCheckError("Site build manifest must be a JSON object.")
    expected = {"format", "version", "revision", "dirty", "engine", "assets"}
    if set(manifest) != expected:
        raise SiteCheckError("Site build manifest has missing or unknown fields.")
    if manifest["format"] != FORMAT or manifest["version"] != VERSION:
        raise SiteCheckError("Site build manifest format/version is unsupported.")
    if not isinstance(manifest["revision"], str) or not REVISION.fullmatch(manifest["revision"]):
        raise SiteCheckError("Site build revision is not a full lowercase Git commit.")
    if type(manifest["dirty"]) is not bool:
        raise SiteCheckError("Site build dirty flag must be boolean.")
    if manifest["dirty"]:
        raise SiteCheckError("The published Site identifies an uncommitted source build.")
    if manifest["engine"] != ENGINE:
        raise SiteCheckError("The published Site does not identify the pinned Godot engine.")
    assets = manifest["assets"]
    if not isinstance(assets, dict) or set(assets) != ASSETS:
        raise SiteCheckError("Site build manifest does not identify the exact Web assets.")
    for name in sorted(ASSETS):
        identity = assets[name]
        if not isinstance(identity, dict) or set(identity) != {"bytes", "sha256"}:
            raise SiteCheckError(f"Invalid asset identity for {name}.")
        if type(identity["bytes"]) is not int or identity["bytes"] <= 0:
            raise SiteCheckError(f"Invalid byte count for {name}.")
        if not isinstance(identity["sha256"], str) or not SHA256.fullmatch(identity["sha256"]):
            raise SiteCheckError(f"Invalid SHA-256 for {name}.")
    return manifest


def fetch_manifest(expected_revision: str) -> dict:
    url = SITE + "/studio-build.json?expected=" + quote(expected_revision)
    request = Request(
        url,
        headers={
            "Accept": "application/json",
            "Cache-Control": "no-cache",
            "User-Agent": "Surface-Diagrams-Studio-site-check/1",
        },
    )
    try:
        with urlopen(request, timeout=20) as response:
            length = response.headers.get("Content-Length")
            if length is not None and int(length) > MANIFEST_LIMIT:
                raise SiteCheckError("Site build manifest exceeds 64 KiB.")
            payload = response.read(MANIFEST_LIMIT + 1)
    except (HTTPError, URLError, TimeoutError, OSError) as error:
        raise SiteCheckError(f"Could not read the public Site build manifest: {error}") from error
    return parse_manifest(payload)


def compare(live: dict, expected: dict) -> dict:
    asset_matches = {
        name: live["assets"][name] == expected["assets"][name]
        for name in sorted(ASSETS)
    }
    current = (
        live["revision"] == expected["revision"]
        and live["engine"] == expected["engine"]
        and all(asset_matches.values())
    )
    return {
        "format": "surface-studio-site-check",
        "version": 1,
        "site": SITE,
        "status": "current" if current else "different",
        "expected_revision": expected["revision"],
        "live_revision": live["revision"],
        "engine_matches": live["engine"] == expected["engine"],
        "asset_matches": asset_matches,
    }


def current_revision() -> str:
    repository = Path(__file__).resolve().parents[2]
    return subprocess.check_output(
        ["git", "-C", str(repository), "rev-parse", "HEAD"], text=True, timeout=10
    ).strip()


def expected_manifest(path: Path | None) -> dict:
    if path is not None:
        return parse_manifest(path.read_bytes())
    revision = current_revision()
    if not REVISION.fullmatch(revision):
        raise SiteCheckError("Current checkout does not resolve to a full Git commit.")
    # Without a candidate export, revision comparison remains useful but asset
    # comparison must not pretend to have expected bytes. Use live identities
    # after fetching and label that narrower mode in main().
    return {"revision": revision, "engine": ENGINE}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--expected-manifest",
        type=Path,
        help="candidate studio-build.json; otherwise compare only the checkout revision",
    )
    parser.add_argument("--json", action="store_true", help="print a machine-readable receipt")
    args = parser.parse_args()
    try:
        expected = expected_manifest(args.expected_manifest)
        live = fetch_manifest(expected["revision"])
        if args.expected_manifest is None:
            result = {
                "format": "surface-studio-site-check",
                "version": 1,
                "site": SITE,
                "status": "current" if live["revision"] == expected["revision"] else "different",
                "expected_revision": expected["revision"],
                "live_revision": live["revision"],
                "engine_matches": live["engine"] == expected["engine"],
                "asset_matches": "not compared without --expected-manifest",
            }
        else:
            result = compare(live, expected)
    except (SiteCheckError, OSError, subprocess.SubprocessError) as error:
        print(f"SITE UNIDENTIFIED: {error}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, sort_keys=True))
    elif result["status"] == "current":
        print(f"SITE CURRENT: {result['live_revision']} at {SITE}")
    else:
        print(
            "SITE DIFFERENT: live %s, expected %s at %s"
            % (result["live_revision"], result["expected_revision"], SITE)
        )
    return 0 if result["status"] == "current" else 3


if __name__ == "__main__":
    raise SystemExit(main())
