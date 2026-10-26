#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlparse

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "health", Path(__file__).resolve().parents[1] / "modules/monitoring/health.py"
)
health = importlib.util.module_from_spec(spec)
spec.loader.exec_module(health)


class HealthTests(unittest.TestCase):
    def metrics(self, value):
        return {"status": "success", "data": {"result": [{"value": [0, value]}]}}

    def test_requires_metrics_and_grafana_database(self):
        for value, database, expected in [("1", "ok", True), ("0", "ok", False), ("1", "fail", False)]:
            with self.subTest(value=value, database=database), patch.object(
                health, "request_json", side_effect=[self.metrics(value), {"database": database}]
            ) as request:
                self.assertEqual(health.healthy(9), expected)
                query = parse_qs(urlparse(request.call_args_list[0].args[0]).query)["query"][0]
                self.assertIn('count(up{host="amalthea"}) == bool 9', query)
                self.assertIn('timestamp(up{host="amalthea"})', query)

    def test_missing_malformed_or_unreachable_metrics_fail_closed(self):
        for response in [{}, {"status": "error"}, {"status": "success", "data": {"result": []}},
                         self.metrics("NaN"), self.metrics("invalid")]:
            with self.subTest(response=response), patch.object(health, "request_json", return_value=response):
                self.assertFalse(health.healthy(9))
        with patch.object(health, "request_json", side_effect=OSError):
            self.assertFalse(health.healthy(9))

    def test_grafana_failure_is_down(self):
        with patch.object(health, "request_json", side_effect=[self.metrics("1"), OSError]):
            self.assertFalse(health.healthy(9))


if __name__ == "__main__":
    unittest.main()
