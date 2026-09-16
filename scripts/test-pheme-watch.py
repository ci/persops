#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.error

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "watch", Path(__file__).resolve().parents[1] / "infra/pheme-watch/watch.py"
)
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)


class WatchTests(unittest.TestCase):
    def setUp(self):
        self.state = {}
        self.send = Mock(return_value=True)

    def cycle(self, healthy):
        return watch.observe(self.state, {"Amalthea": healthy}, self.send)

    def down(self):
        for _ in range(3):
            self.cycle(False)

    def test_initial_health_and_transient_failures_are_silent(self):
        self.cycle(True)
        self.cycle(False)
        self.cycle(False)
        self.cycle(True)
        self.send.assert_not_called()

    def test_debounce_down_dedup_and_recovery(self):
        self.down()
        self.cycle(False)
        self.assertEqual(self.send.call_count, 1)
        self.assertEqual(self.send.call_args.args[0], "primary")
        self.cycle(True)
        self.assertEqual(self.send.call_count, 2)
        self.assertTrue(self.send.call_args.args[2])
        self.cycle(True)
        self.assertEqual(self.send.call_count, 2)

    def test_fallback_recovery_returns_to_fallback(self):
        self.send.side_effect = [False, True, True]
        self.down()
        self.cycle(True)
        self.assertEqual([c.args[0] for c in self.send.call_args_list], ["primary", "fallback", "fallback"])

    def test_failed_publish_retries_next_cycle(self):
        self.send.return_value = False
        self.down()
        self.assertEqual(self.state["Amalthea"]["routes"], [])
        self.assertFalse(self.cycle(False))
        self.send.return_value = True
        self.assertTrue(self.cycle(False))
        self.assertEqual(self.state["Amalthea"]["routes"], ["primary"])

    def test_failed_recovery_retries_and_survives_restart(self):
        self.down()
        self.send.return_value = False
        self.assertFalse(self.cycle(True))
        self.state = json.loads(json.dumps(self.state))
        self.send.return_value = True
        self.assertTrue(self.cycle(True))
        self.assertEqual(self.state["Amalthea"]["routes"], [])

    def test_state_roundtrip(self):
        self.down()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            watch.save(path, self.state)
            self.assertEqual(json.loads(path.read_text()), self.state)
            self.assertFalse(path.with_suffix(".tmp").exists())

    def test_probe_requires_tsmp_and_health_json(self):
        for result in (subprocess.CompletedProcess([], 0, "pong via TSMP"),
                       subprocess.CompletedProcess([], 0, "pong via DERP"),
                       subprocess.CompletedProcess([], 1, "pong via TSMP")):
            with patch.object(watch.subprocess, "run", return_value=result), patch.object(watch, "request_json", return_value={"healthy": True}):
                healthy = watch.probes()
                self.assertEqual(healthy["Amalthea"], result.returncode == 0 and "TSMP" in result.stdout)
                self.assertTrue(healthy["Private notifications"])

    def test_probe_failure_is_down(self):
        with patch.object(watch.subprocess, "run", side_effect=subprocess.TimeoutExpired("tailscale", 6)), patch.object(watch, "request_json", side_effect=OSError):
            self.assertFalse(any(watch.probes().values()))

    def test_publish_routes_and_no_secret_error_output(self):
        secret = {"primary_token": "tk_" + "a" * 29, "fallback_topic": "f" * 64}
        with patch.object(watch, "request_json", return_value={"event": "message", "id": "test"}) as request:
            self.assertTrue(watch.publish(secret, "primary", "TEST"))
            self.assertIn("Authorization", request.call_args.args[2])
            self.assertTrue(watch.publish(secret, "fallback", "TEST"))
            self.assertNotIn("Authorization", request.call_args.args[2])
        with patch.object(watch, "request_json", return_value={"healthy": True}):
            self.assertFalse(watch.publish(secret, "primary", "TEST"))
        with patch.object(watch, "request_json", side_effect=urllib.error.URLError("secret URL")), patch("builtins.print") as output:
            self.assertFalse(watch.publish(secret, "fallback", "TEST"))
            output.assert_not_called()

    def test_redirect_refused(self):
        self.assertIsNone(watch.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://example.com"))


if __name__ == "__main__":
    unittest.main()
