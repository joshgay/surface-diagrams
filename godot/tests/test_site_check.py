"""The public Site comparison must fail closed and distinguish exact builds."""

import importlib.util
import json
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "studio_site_check", Path(__file__).resolve().parents[1] / "web" / "check_site.py"
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


def manifest(revision="1" * 40):
    return {
        "format": CHECK.FORMAT,
        "version": CHECK.VERSION,
        "revision": revision,
        "dirty": False,
        "engine": CHECK.ENGINE,
        "assets": {
            "index.pck": {"bytes": 123, "sha256": "a" * 64},
            "index.wasm.gz": {"bytes": 456, "sha256": "b" * 64},
        },
    }


def encoded(value):
    return (json.dumps(value, separators=(",", ":")) + "\n").encode()


class SiteCheckTests(unittest.TestCase):
    def test_valid_manifest_and_exact_comparison(self):
        expected = CHECK.parse_manifest(encoded(manifest()))
        live = CHECK.parse_manifest(encoded(manifest()))
        result = CHECK.compare(live, expected)
        self.assertEqual(result["status"], "current")
        self.assertEqual(result["live_revision"], "1" * 40)
        self.assertEqual(result["asset_matches"], {"index.pck": True, "index.wasm.gz": True})

    def test_revision_and_same_length_asset_changes_are_distinguished(self):
        expected = manifest()
        live = manifest("2" * 40)
        live["assets"]["index.pck"]["sha256"] = "c" * 64
        result = CHECK.compare(live, expected)
        self.assertEqual(result["status"], "different")
        self.assertFalse(result["asset_matches"]["index.pck"])
        self.assertTrue(result["asset_matches"]["index.wasm.gz"])

    def test_legacy_html_fallback_is_not_mistaken_for_a_manifest(self):
        with self.assertRaisesRegex(CHECK.SiteCheckError, "legacy publication"):
            CHECK.parse_manifest(b"<!doctype html><title>Surface Diagrams Studio</title>")

    def test_dirty_future_duplicate_and_unknown_records_fail_closed(self):
        dirty = manifest()
        dirty["dirty"] = True
        with self.assertRaisesRegex(CHECK.SiteCheckError, "uncommitted"):
            CHECK.parse_manifest(encoded(dirty))
        future = manifest()
        future["version"] = 2
        with self.assertRaisesRegex(CHECK.SiteCheckError, "unsupported"):
            CHECK.parse_manifest(encoded(future))
        duplicate = encoded(manifest()).replace(b'"version":1', b'"version":1,"version":1')
        with self.assertRaisesRegex(CHECK.SiteCheckError, "Duplicate"):
            CHECK.parse_manifest(duplicate)
        unknown = manifest()
        unknown["deployed_at"] = "never trusted"
        with self.assertRaisesRegex(CHECK.SiteCheckError, "missing or unknown"):
            CHECK.parse_manifest(encoded(unknown))

    def test_asset_shape_hash_byte_and_payload_bounds_are_strict(self):
        wrong_assets = manifest()
        wrong_assets["assets"]["index.js"] = {"bytes": 1, "sha256": "c" * 64}
        with self.assertRaisesRegex(CHECK.SiteCheckError, "exact Web assets"):
            CHECK.parse_manifest(encoded(wrong_assets))
        bad_hash = manifest()
        bad_hash["assets"]["index.pck"]["sha256"] = "A" * 64
        with self.assertRaisesRegex(CHECK.SiteCheckError, "SHA-256"):
            CHECK.parse_manifest(encoded(bad_hash))
        bad_bytes = manifest()
        bad_bytes["assets"]["index.pck"]["bytes"] = True
        with self.assertRaisesRegex(CHECK.SiteCheckError, "byte count"):
            CHECK.parse_manifest(encoded(bad_bytes))
        with self.assertRaisesRegex(CHECK.SiteCheckError, "64 KiB"):
            CHECK.parse_manifest(b" " * (CHECK.MANIFEST_LIMIT + 1))


if __name__ == "__main__":
    unittest.main()
