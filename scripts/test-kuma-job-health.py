import importlib.util
from pathlib import Path
import unittest
import sys
from unittest.mock import patch
import tempfile
import json

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "health", Path(__file__).resolve().parents[1] / "modules/kuma-job-health.py"
)
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)


class JobHealthTests(unittest.TestCase):
    def setUp(self):
        self.service = {"LoadState": "loaded", "ActiveState": "inactive", "Result": "success", "ExecMainStatus": "0", "exit_epoch": 1000}
        self.timer = {"ActiveState": "active", "UnitFileState": "enabled"}

    def assess(self, previous=None, now=1100):
        return health.assess(self.service, self.timer, previous or {}, now, 93600)

    def test_success_and_freshness_boundary(self):
        self.assertEqual(self.assess(now=94600)[0], "up")
        self.assertEqual(self.assess(now=94601)[0], "down")

    def test_latest_failure_overrides_recent_success(self):
        self.service.update(Result="exit-code", ExecMainStatus="1", ActiveState="failed")
        status, _, record = self.assess({"last_success": 999})
        self.assertEqual(status, "down")
        self.assertEqual(record["last_success"], 999)
        self.assertTrue(record["failed"])

    def test_reboot_retains_observed_success_and_failure(self):
        self.service["exit_epoch"] = 0
        self.assertEqual(self.assess({"last_success": 1000})[0], "up")
        self.assertEqual(self.assess({"last_success": 1000, "failed": True})[0], "down")
        self.assertEqual(self.assess()[0], "down")

    def test_running_job_does_not_invent_success(self):
        self.service["ActiveState"] = "activating"
        self.assertEqual(self.assess()[0], "down")
        self.assertEqual(self.assess({"last_success": 900})[2]["last_success"], 900)

    def test_recovery_clears_failure(self):
        self.assertEqual(self.assess({"last_success": 900, "failed": True})[0], "up")

    def test_auto_restart_wait_and_running_retry_stay_down(self):
        self.service.update(ActiveState="activating", Result="exit-code", ExecMainStatus="1")
        status, _, record = self.assess({"last_success": 900})
        self.assertEqual(status, "down")
        self.service.update(Result="success", ExecMainStatus="0", exit_epoch=0)
        self.assertEqual(self.assess(record)[0], "down")

    def test_pre_start_failure_survives_reboot(self):
        self.service.update(ActiveState="failed", Result="exit-code", exit_epoch=0)
        status, _, record = self.assess({"last_success": 900})
        self.assertEqual(status, "down")
        self.service.update(ActiveState="inactive", Result="success")
        self.assertEqual(self.assess(record)[0], "down")

    def test_disabled_timer_and_missing_unit(self):
        self.timer["UnitFileState"] = "disabled"
        self.assertEqual(self.assess()[0], "down")
        self.service["LoadState"] = "not-found"
        self.assertEqual(self.assess()[0], "down")

    def test_future_timestamp_fails_closed(self):
        self.assertEqual(self.assess(now=999)[0], "down")

    def test_observation_persists_when_delivery_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "jobs").write_text(json.dumps({"test": {"unit": "test", "max_age": 93600}}))
            (root / "tokens").write_text(json.dumps({"test": "secret"}))
            with patch.object(health, "properties", side_effect=[self.service, self.timer]), patch.object(health, "publish", side_effect=TimeoutError), patch.object(health.time, "time", return_value=1100):
                self.assertEqual(health.run(root / "jobs", root / "tokens", root / "state"), 1)
            self.assertEqual(json.loads((root / "state").read_text())["test"]["last_success"], 1000)


if __name__ == "__main__":
    unittest.main()
