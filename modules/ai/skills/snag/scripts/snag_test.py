#!/usr/bin/env python3
"""Exercise the public CLI against isolated stores, including concurrent writers."""

import concurrent.futures
from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import runpy

SCRIPT = Path(__file__).with_name("snag")


class SnagTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="snag-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.store = self.root / "state"
        self.env = {**os.environ, "SNAG_HOME": str(self.store),
                    "SNAG_HARNESS": "test", "SNAG_SOURCE": "", "CODEX_THREAD_ID": ""}

    def run_cli(self, *args, code=0, stdin=None, env=None):
        result = subprocess.run([sys.executable, str(SCRIPT), *args],
                                env=env or self.env, cwd=self.root, input=stdin,
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result

    def add(self, title="Broken export", *args, **kwargs):
        return self.run_cli("add", "--repo", "forge/team/a", "-e", "first evidence",
                            *args, title, **kwargs)

    def rows(self, *args):
        return json.loads(self.run_cli("ls", "--json", *args).stdout)

    def db_path(self):
        return self.store / "snags.sqlite3"

    def test_capture_context_and_history(self):
        env = {**self.env, "SNAG_SOURCE": "task-1", "SNAG_CONTEXT": "stage=review"}
        self.add("Broken export", "--key", "bad-json", "-d", "-", "-f", "emit JSON",
                 stdin="long details", env=env)
        self.add("Different wording", "--key", "bad-json", "-e", "second evidence",
                 "--source", "task-2", "--impact", "high")
        row, = self.rows()
        self.assertEqual((row["seen"], row["sources"], row["impact"]), (2, 2, "high"))
        self.assertEqual(row["owner"], "repo:forge/team/a")
        first, second = row["observations"]
        self.assertEqual((first["detail"], first["fix"], first["context"]),
                         ("long details", "emit JSON", "stage=review"))
        self.assertEqual(second["evidence"], "second evidence")
        self.assertEqual(first["harness"], "test")
        self.assertEqual(json.loads(self.run_cli("show", row["id"]).stdout), row)
        self.assertEqual(self.db_path().stat().st_mode & 0o777, 0o600)

    def test_owner_boundaries_and_repo_filter(self):
        self.add()
        self.add("Broken export", "--repo", "forge/team/b")
        self.add("Broken export", "-s", "exporter")
        self.add("Broken export", "-s", "exporter", "--repo", "forge/team/b")
        self.add("Broken export", "--owner", "tool:exporter")
        self.assertEqual(len(self.rows()), 4)
        skill, = self.rows("--owner", "skill:exporter")
        self.assertEqual(skill["seen"], 2)
        self.assertEqual(len(self.rows("--repo", "forge/team/b")), 2)
        self.assertEqual(self.rows("--owner", "absent"), [])

    def test_normalization_has_no_expiry(self):
        self.add(" Broken  EXPORT ")
        with closing(sqlite3.connect(self.db_path())) as db, db:
            db.execute("UPDATE observations SET ts='2000-01-01T00:00:00+00:00'")
        self.add("broken export")
        row, = self.rows()
        self.assertEqual(row["seen"], 2)

    def test_recurrence_and_explicit_status_preserve_observations(self):
        self.add("Broken export", "--impact", "high")
        original, = self.rows()
        issue_id = original["id"]
        for state in ("done", "wontfix"):
            self.run_cli(state, issue_id)
            self.assertEqual(self.rows(), [])
            closed, = self.rows("--all")
            self.assertEqual(closed["last_seen"], original["last_seen"])
            self.assertEqual(closed["status"], state)
            self.run_cli("reopen", issue_id)
            self.assertEqual(self.rows()[0]["status"], "open")
        self.run_cli("done", issue_id)
        self.add("Broken export", "--impact", "low")
        reopened, = self.rows()
        self.assertEqual((reopened["id"], reopened["seen"], reopened["impact"]),
                         (issue_id, 2, "high"))

    def test_triage_uses_impact_then_independent_sources(self):
        for _ in range(3):
            self.add("Many retries", "--source", "one-session")
        for source in ("session-a", "session-b"):
            self.add("Independent recurrence", "--source", source)
        self.add("Serious issue", "--impact", "high")
        self.add("Unknown source", "--source", "")
        rows = json.loads(self.run_cli("triage", "--json").stdout)
        self.assertEqual([row["title"] for row in rows],
                         ["Serious issue", "Independent recurrence", "Many retries", "Unknown source"])
        self.assertEqual([row["sources"] for row in rows], [0, 2, 1, 0])
        self.assertIn("Machine-local inbox:", self.run_cli("triage").stdout)

    def test_concurrent_first_writes_preserve_all_evidence(self):
        def capture(index):
            return self.add("Same issue", "-e", f"observation-{index}",
                            "--source", f"task-{index % 2}")
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(capture, range(20)))
        row, = self.rows()
        self.assertEqual((row["seen"], row["sources"]), (20, 2))
        self.assertEqual({o["evidence"] for o in row["observations"]},
                         {f"observation-{index}" for index in range(20)})

    def test_readonly_empty_inbox_does_not_create_storage(self):
        self.assertEqual(self.rows(), [])
        self.assertIn("No matching snags.", self.run_cli("triage").stdout)
        self.run_cli("show", "missing", code=1)
        self.run_cli("path")
        self.assertFalse(self.store.exists())

    def test_rejects_invalid_arguments_without_writing(self):
        for args in (("add", "-e"), ("add", "-e", "e", "-k", "bug tooling", "title"),
                     ("add", "-e", " ", "title"), ("add", "-e", "e", " "),
                     ("add", "-e", "e", "--impact", "urgent", "title"),
                     ("done", "id", "extra")):
            self.run_cli(*args, code=2)
        self.assertFalse(self.store.exists())

    def test_missing_id_does_not_change_existing_records(self):
        self.add()
        before = self.rows()
        self.run_cli("done", "missing", code=1)
        self.run_cli("show", "missing", code=1)
        self.assertEqual(self.rows(), before)

    def test_busy_database_fails_without_losing_existing_records(self):
        self.add()
        before = self.rows()
        with closing(sqlite3.connect(self.db_path())) as db, db:
            db.execute("BEGIN IMMEDIATE")
            result = self.add("another", code=1)
            self.assertIn("locked", result.stderr)
            self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(self.rows(), before)

    def test_legacy_store_and_unwritable_location_fail_clearly(self):
        self.store.mkdir()
        legacy = self.store / "snags.jsonl"
        legacy.write_text('{"title":"existing data"}\n')
        self.assertIn("legacy JSONL", self.add(code=1).stderr)
        self.run_cli("ls", code=1)
        self.assertFalse(self.db_path().exists())
        self.assertEqual(legacy.read_text(), '{"title":"existing data"}\n')
        file = self.root / "not-a-directory"
        file.write_text("keep")
        self.add(code=1, env={**self.env, "SNAG_HOME": str(file)})
        self.assertEqual(file.read_text(), "keep")

    def test_harness_detection_ignores_global_configuration(self):
        detect = runpy.run_path(str(SCRIPT))["harness"]
        settings = {"CODEX_HOME": "/tmp/codex", "AMP_SETTINGS_FILE": "/tmp/amp",
                    "PI_CODING_AGENT_DIR": "/tmp/pi"}
        cases = [({}, "unknown"), ({"CODEX_THREAD_ID": ""}, "unknown"),
                 ({"CODEX_THREAD_ID": "task-1"}, "codex"),
                 ({"CLAUDECODE": "1"}, "claude"),
                 ({"AMP_THREAD_ID": "T-1"}, "amp"),
                 ({"SNAG_HARNESS": "pi", "CODEX_THREAD_ID": "parent-task"}, "pi")]
        for session, expected in cases:
            with self.subTest(expected=expected), patch.dict(os.environ, settings | session, clear=True):
                self.assertEqual(detect(), expected)

    def test_remote_identity_keeps_host_and_drops_credentials(self):
        # This module has no import-time effects; loading it tests URL normalization.
        repo_name = runpy.run_path(str(SCRIPT))["repo_name"]
        self.assertEqual(repo_name("git@forge.test:team/repo.git"), "forge.test/team/repo")
        self.assertEqual(repo_name("https://user:secret@forge.test/team/repo.git?token=secret"),
                         "forge.test/team/repo")
        self.assertNotEqual(repo_name("https://a.test/team/repo.git"),
                            repo_name("https://b.test/team/repo.git"))


if __name__ == "__main__":
    unittest.main()
