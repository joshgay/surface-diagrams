"""Build a deterministic publication bundle from a validated walkthrough.

The adapter invokes only the repository's fixed DiagramDocument API. Supplied
exploratory 3D records remain in walkthrough.json and are listed as excluded;
they are never converted into certified geometry.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src"
MAX_INPUT_BYTES = 256 * 1024
MAX_BUNDLE_BYTES = 64 * 1024 * 1024
MAX_DOCUMENTS = 65
MAX_STEPS = 64
IDENTIFIER = re.compile(r"[A-Za-z][A-Za-z0-9_-]{0,39}\Z")
FORMAT = "surface-diagrams-walkthrough"
BUNDLE_FORMAT = "surface-diagrams-walkthrough-publication"


def _duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON field: " + key)
        result[key] = value
    return result


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _text_bytes(text: str) -> bytes:
    return text.encode("utf-8")


def _exact_keys(value, allowed, required, where):
    if not isinstance(value, dict):
        raise ValueError(where + " must be an object")
    unknown = set(value) - set(allowed)
    missing = set(required) - set(value)
    if unknown or missing:
        raise ValueError(f"{where} has unknown or missing fields")


def _stable_records(data):
    if data["kind"] == "braid":
        return [{"kind": "strand", "id": index}
                for index in range(1, data["braid"]["strands"] + 1)]
    result = [{"kind": "object", "id": item["id"], "object_kind": item["kind"]}
              for item in data["surface"]["objects"]]
    result.extend({"kind": "curve", "id": item["id"], "curve_kind": item["kind"]}
                  for item in data["curves"])
    result.extend({"kind": "label", "id": item["id"]} for item in data["labels"])
    return result


def _entry(path: str, data: bytes) -> dict[str, object]:
    return {"path": path, "bytes": len(data), "sha256": _sha(data)}


def _zip(entries: dict[str, bytes]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9, strict_timestamps=True) as archive:
        for path in sorted(entries):
            info = zipfile.ZipInfo(path, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, entries[path])
    result = output.getvalue()
    if len(result) > MAX_BUNDLE_BYTES:
        raise ValueError("publication bundle exceeds 64 MiB")
    return result


def build(source_text: str) -> tuple[bytes, dict[str, object]]:
    if len(source_text.encode("utf-8")) > MAX_INPUT_BYTES:
        raise ValueError("walkthrough exceeds 256 KiB")
    raw = json.loads(source_text, object_pairs_hook=_duplicates)
    top_allowed = "format version title documents initial_state steps surface_views".split()
    top_required = "format version title documents initial_state steps".split()
    _exact_keys(raw, top_allowed, top_required, "walkthrough")
    if raw["format"] != FORMAT or type(raw["version"]) is not int or raw["version"] != 1:
        raise ValueError("expected walkthrough version 1")
    if not isinstance(raw["title"], str) or not raw["title"] or len(raw["title"]) > 120:
        raise ValueError("invalid walkthrough title")
    documents = raw["documents"]
    if not isinstance(documents, dict) or not 1 <= len(documents) <= MAX_DOCUMENTS:
        raise ValueError("expected 1..65 named documents")
    if SOURCE.is_dir():
        sys.path.insert(0, str(SOURCE))
    from surface_diagrams import DiagramDocument

    parsed = {}
    kinds = set()
    signatures = []
    for identifier, value in documents.items():
        if not isinstance(identifier, str) or IDENTIFIER.fullmatch(identifier) is None:
            raise ValueError("unsafe document reference")
        document = DiagramDocument.from_dict(value)
        data = document.to_dict()
        parsed[identifier] = document
        kinds.add(data["kind"])
        signatures.append(_stable_records(data))
    if len(kinds) != 1 or any(signature != signatures[0] for signature in signatures[1:]):
        raise ValueError("walkthrough documents must preserve one kind and stable records")
    if raw["initial_state"] not in documents:
        raise ValueError("unknown initial state")
    steps = raw["steps"]
    if not isinstance(steps, list) or not 1 <= len(steps) <= MAX_STEPS:
        raise ValueError("expected 1..64 supplied steps")
    expected = raw["initial_state"]
    step_ids = set()
    step_references = []
    for index, step in enumerate(steps):
        common = "id name operation before after selected provenance verification".split()
        optional = ["braid"] if "braid" in step else (["cover"] if "cover" in step else [])
        _exact_keys(step, common + optional, common + optional, f"step {index}")
        if not isinstance(step["id"], str) or IDENTIFIER.fullmatch(step["id"]) is None or step["id"] in step_ids:
            raise ValueError("unsafe or duplicate step ID")
        step_ids.add(step["id"])
        if step["before"] != expected or step["before"] not in documents or step["after"] not in documents:
            raise ValueError("steps must form an explicit chain of complete states")
        expected = step["after"]
        reference = {"id": step["id"], "before": step["before"], "after": step["after"],
                     "selected": step["selected"], "verification": step["verification"],
                     "provenance": step["provenance"]}
        if "braid" in step:
            reference["literal_braid_block"] = step["braid"]["word"]
        if "cover" in step:
            reference["surface_linkage"] = {
                "before": step["cover"]["before_surface"],
                "after": step["cover"]["after_surface"],
                "status": step["cover"]["status"],
                "verification": step["cover"]["verification"],
            }
        step_references.append(reference)

    source_bytes = _text_bytes(source_text)
    entries = {"walkthrough.json": source_bytes}
    document_manifest = []
    for identifier, document in parsed.items():
        base = "documents/" + identifier
        artifacts = {
            base + ".json": _text_bytes(document.to_json()),
            base + ".svg": _text_bytes(document.render_svg()),
            base + ".tikz": _text_bytes(document.render_tikz()),
            base + ".py": _text_bytes(document.python_source()),
        }
        entries.update(artifacts)
        document_manifest.append({
            "id": identifier,
            "kind": document.to_dict()["kind"],
            "stable_records": _stable_records(document.to_dict()),
            "artifacts": [_entry(path, artifacts[path]) for path in sorted(artifacts)],
        })
    excluded = []
    for identifier, surface in raw.get("surface_views", {}).items():
        excluded.append({
            "id": identifier,
            "status": surface.get("status"),
            "reason": "Exploratory 3D data remains only in walkthrough.json; no certified 3D geometry is exported.",
        })
    manifest = {
        "format": BUNDLE_FORMAT,
        "version": 1,
        "title": raw["title"],
        "geometry_authority": "surface-diagrams Python library",
        "geometry_scope": "validated 2D DiagramDocument records only",
        "source": _entry("walkthrough.json", source_bytes),
        "documents": document_manifest,
        "steps": step_references,
        "excluded_exploratory_surface_views": excluded,
    }
    manifest_bytes = _text_bytes(json.dumps(manifest, sort_keys=True, indent=2,
                                             ensure_ascii=True, allow_nan=False) + "\n")
    entries["manifest.json"] = manifest_bytes
    return _zip(entries), manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a deterministic walkthrough publication bundle")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        if args.input.stat().st_size > MAX_INPUT_BYTES:
            raise ValueError("walkthrough exceeds 256 KiB")
        source = args.input.read_text(encoding="utf-8")
        bundle, manifest = build(source)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(bundle)
    except Exception as error:
        print(json.dumps({"ok": False, "error": f"{type(error).__name__}: {error}"}, sort_keys=True))
        return 1
    print(json.dumps({"ok": True, "bundle_bytes": len(bundle), "manifest": manifest},
                     sort_keys=True, ensure_ascii=True, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
