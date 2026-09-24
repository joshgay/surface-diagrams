import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

import run_visual_review as review


def fake_png(width, height):
    return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", width, height)


class VisualReviewTests(unittest.TestCase):
    def test_png_dimensions_reads_ihdr_without_image_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "frame.png"
            path.write_bytes(fake_png(390, 844))
            self.assertEqual(review.png_dimensions(path), (390, 844))

    def test_png_dimensions_rejects_non_png(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "frame.png"
            path.write_bytes(b"not an image")
            with self.assertRaisesRegex(ValueError, "not a PNG"):
                review.png_dimensions(path)

    def test_command_pins_resolution_and_capture_script(self):
        command = review.command_for(Path("/opt/godot"), Path("/tmp/out"),
                                     "phone-landscape", "x11")
        self.assertIn("844x390", command)
        self.assertIn("res://visual_review/capture.gd", command)
        self.assertEqual(command[-4:], ["--output", "/tmp/out", "--profile", "phone-landscape"])
        self.assertEqual(command[command.index("--display-driver") + 1], "x11")

    def test_profile_receipt_validates_every_workspace_and_png(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = self._receipt(output)
            path = output / "desktop.json"
            path.write_text(json.dumps(receipt), encoding="utf-8")
            self.assertEqual(review.validate_profile_receipt(path, output)["profile"], "desktop")

    def test_profile_receipt_rejects_png_checksum_mismatch(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = self._receipt(output)
            receipt["frames"][0]["image_sha256"] = "0" * 64
            path = output / "desktop.json"
            path.write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                review.validate_profile_receipt(path, output)

    def test_profile_receipt_cannot_claim_visual_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = self._receipt(output)
            receipt["visual_acceptance_claimed"] = True
            path = output / "desktop.json"
            path.write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "explicitly unreviewed"):
                review.validate_profile_receipt(path, output)

    def test_combined_manifest_is_sorted_and_unreviewed(self):
        receipts = []
        for profile in review.PROFILES:
            receipts.append({
                "profile": profile, "engine": "4.7.2", "engine_hash": "ed1daf0bf",
                "display_driver": "x11", "rendering_method": "gl_compatibility",
                "frames": [{"id": profile + "-editor"}],
            })
        combined = review.combine_receipts(list(reversed(receipts)))
        self.assertEqual([frame["id"] for frame in combined["frames"]], sorted(frame["id"] for frame in combined["frames"]))
        self.assertFalse(combined["visual_acceptance_claimed"])
        self.assertEqual(combined["manual_inspection_status"], "not-reviewed")

    def _receipt(self, output):
        frames = []
        focus = {
            "editor": "Mathematical records",
            "factor": "Selected factor support diagram",
            "surface": "Linked exploratory three dimensional view",
            "walkthrough": "Complete supplied after-state diagram",
        }
        for workspace in sorted(review.WORKSPACES):
            name = f"desktop-{workspace}.png"
            image = output / name
            image.write_bytes(fake_png(1280, 800))
            frames.append({
                "id": f"desktop-{workspace}", "workspace": workspace,
                "fixture": "res://fixtures/example.json", "fixture_sha256": "a" * 64,
                "viewport": {"width": 1280, "height": 800},
                "selected_id": "stable-id", "content_target": "grid",
                "focus": {"accessibility_name": focus[workspace], "path": "Root/Focus"},
                "image": name, "image_width": 1280, "image_height": 800,
                "image_bytes": image.stat().st_size,
                "image_sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
                "manual_inspection_status": "not-reviewed",
            })
        return {
            "format": "surface-diagrams-studio-visual-profile", "version": 1,
            "profile": "desktop", "viewport": {"width": 1280, "height": 800},
            "manual_inspection_status": "not-reviewed", "visual_acceptance_claimed": False,
            "frames": frames, "failures": [],
        }


if __name__ == "__main__":
    unittest.main()
