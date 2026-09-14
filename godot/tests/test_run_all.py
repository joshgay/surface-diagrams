"""Contract checks for the aggregate runner, without launching an engine."""
import contextlib
import io
import subprocess
import unittest
from unittest.mock import patch

import run_all


class RunnerTests(unittest.TestCase):
    def test_timeout_is_bounded_and_fails(self):
        with patch.object(run_all.subprocess, "run", side_effect=subprocess.TimeoutExpired("godot", 120)) as call:
            with self.assertRaisesRegex(SystemExit, "exceeded 120 seconds"):
                run_all.run(["godot", "--headless"])
            self.assertEqual(call.call_args.kwargs["timeout"], 120)

    def test_zero_exit_with_script_error_is_failure(self):
        result = subprocess.CompletedProcess(["godot"], 0, "", "SCRIPT ERROR: test failure\n")
        with patch.object(run_all.subprocess, "run", return_value=result), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(SystemExit, "despite exit 0"):
                run_all.run(["godot"])

    def test_expected_nonzero_is_allowed_only_when_requested(self):
        result = subprocess.CompletedProcess(["godot"], 1, "", "FAIL: intentional harness failure\n")
        with patch.object(run_all.subprocess, "run", return_value=result), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(SystemExit, "expected exit 0"):
                run_all.run(["godot"])
            self.assertIn("intentional harness failure", run_all.run(["godot"], expected=1))


if __name__ == "__main__":
    unittest.main()
