#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


AUTOREVIEW = runpy.run_path(Path(__file__).with_name("autoreview"))


class FindingPathTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "repo"
        (self.repo / "src").mkdir(parents=True)
        (self.repo / "src/changed.py").write_text("original = True\n")
        self.changed = {"src/changed.py", "src/deleted.py"}

    def report(self, *paths: str) -> dict:
        return {
            "findings": [
                {
                    "title": f"Path fixture {index}",
                    "body": "Synthetic actionable finding.",
                    "priority": "P2",
                    "confidence": 0.9,
                    "category": "bug",
                    "code_location": {"file_path": path, "line": 1},
                }
                for index, path in enumerate(paths)
            ],
            "overall_correctness": "patch is incorrect" if paths else "patch is correct",
            "overall_explanation": "Synthetic fixture.",
            "overall_confidence": 0.9,
        }

    def validate(self, report: dict, repo: Path | None = None) -> None:
        AUTOREVIEW["validate_report"](report, repo or self.repo, self.changed, [])

    def test_absolute_paths_normalize_without_losing_relative_or_deleted_findings(self) -> None:
        report = self.report(
            str(self.repo / "src/changed.py"), "src/changed.py", str(self.repo / "src/deleted.py")
        )
        self.validate(report)
        self.assertEqual(
            [finding["code_location"]["file_path"] for finding in report["findings"]],
            ["src/changed.py", "src/changed.py", "src/deleted.py"],
        )
        self.assertEqual(report["findings"][0]["body"], "Synthetic actionable finding.")

    def test_root_aliases_work_in_both_directions(self) -> None:
        alias = self.root / "repo-alias"
        alias.symlink_to(self.repo, target_is_directory=True)
        for repo, path in ((self.repo, alias), (alias, self.repo.resolve())):
            with self.subTest(repo=repo, path=path):
                report = self.report(str(path / "src/changed.py"))
                self.validate(report, repo)
                self.assertEqual(report["findings"][0]["code_location"]["file_path"], "src/changed.py")

    def test_absolute_sibling_prefix_and_symlink_escape_are_rejected(self) -> None:
        sibling = self.root / "repo-other"
        sibling.mkdir()
        (self.repo / "escape").symlink_to(sibling, target_is_directory=True)
        for path in (sibling / "src/changed.py", self.repo / "escape/changed.py"):
            with self.subTest(path=path), self.assertRaisesRegex(SystemExit, "invalid file path"):
                self.validate(self.report(str(path)))

    def test_traversal_remains_rejected(self) -> None:
        for path in ("src/../src/changed.py", str(self.repo / "src/../src/changed.py")):
            with self.subTest(path=path), self.assertRaisesRegex(SystemExit, "invalid file path"):
                self.validate(self.report(path))

    def test_absolute_in_repo_unchanged_file_remains_out_of_scope(self) -> None:
        with self.assertRaisesRegex(SystemExit, "outside the reviewed change"):
            self.validate(self.report(str(self.repo / "src/unchanged.py")))

    def test_cli_preserves_findings_outputs_and_exit_status(self) -> None:
        def git(*arguments: str) -> None:
            subprocess.run(["git", *arguments], cwd=self.repo, check=True, capture_output=True)

        git("init", "--quiet")
        git("add", "src/changed.py")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.com", "-c", "commit.gpgSign=false",
            "commit", "--quiet", "-m", "initial")
        (self.repo / "src/changed.py").write_text("changed = True\n")
        fixture = self.root / "engine-report.json"
        engine = self.root / "codex-fixture"
        engine.write_text(
            f"#!{sys.executable}\nimport sys\nfrom pathlib import Path\n"
            f"Path(sys.argv[sys.argv.index('--output-last-message') + 1]).write_text(Path({str(fixture)!r}).read_text())\n"
        )
        engine.chmod(0o755)
        helper = Path(__file__).with_name("autoreview").resolve()
        cases = [
            ("relative", ["src/changed.py"], True),
            ("absolute", [str(self.repo / "src/changed.py")], True),
            ("mixed", ["src/changed.py", str(self.repo / "src/changed.py")], True),
            ("outside", [str(self.root / "repo-other/src/changed.py")], False),
            ("unchanged", [str(self.repo / "src/unchanged.py")], False),
            ("traversal", ["src/../src/changed.py"], False),
            ("clean", [], True),
        ]
        for label, paths, valid in cases:
            with self.subTest(case=label):
                fixture.write_text(json.dumps(self.report(*paths)))
                output = self.root / f"{label}.json"
                rendered = self.root / f"{label}.txt"
                result = subprocess.run(
                    [sys.executable, str(helper), "--mode", "local", "--engine", "codex",
                     "--codex-bin", str(engine), "--json-output", str(output), "--output", str(rendered)],
                    cwd=self.repo, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 1 if paths else 0, result.stderr)
                self.assertEqual(output.exists(), valid, result.stderr)
                self.assertEqual(rendered.exists(), valid, result.stderr)
                self.assertEqual("autoreview clean:" in result.stdout, not paths)
                if valid:
                    report = json.loads(output.read_text())
                    self.assertEqual(len(report["findings"]), len(paths))
                    for index, finding in enumerate(report["findings"]):
                        self.assertEqual(finding["code_location"]["file_path"], "src/changed.py")
                        self.assertIn(f"Path fixture {index}", result.stdout)
                        self.assertIn("src/changed.py:1", rendered.read_text())
                else:
                    self.assertRegex(result.stderr, "invalid file path|outside the reviewed change")


class AstraValidationTests(unittest.TestCase):
    def reviewer(self, *arguments: str, env: dict[str, str] | None = None):
        with mock.patch.dict(os.environ, env or {}, clear=True), mock.patch.object(
            sys,
            "argv",
            ["autoreview", "--engine", "codex", *arguments],
        ):
            args = AUTOREVIEW["parse_args"]()
            return AUTOREVIEW["reviewer_args"](args)[0]

    def test_astra_defaults_to_high_without_fallback(self) -> None:
        reviewer = self.reviewer("--model", "gpt-6-astra")

        self.assertEqual(reviewer.model, "gpt-6-astra")
        self.assertEqual(reviewer.thinking, "high")
        self.assertIsNone(reviewer.fallback_model)

    def test_astra_accepts_supported_efforts(self) -> None:
        for effort in ("low", "medium", "high", "xhigh", "max"):
            with self.subTest(effort=effort):
                reviewer = self.reviewer("--model", "gpt-6-astra", "--thinking", effort)
                self.assertEqual(reviewer.thinking, effort)

    def test_astra_rejects_unsupported_efforts_after_override_resolution(self) -> None:
        for effort in ("none", "minimal", "ultra"):
            for source in ("cli", "environment"):
                with self.subTest(effort=effort, source=source):
                    with self.assertRaisesRegex(
                        SystemExit,
                        rf"invalid thinking level for codex model gpt-6-astra: {effort}",
                    ):
                        if source == "cli":
                            self.reviewer("--model", "gpt-6-astra", "--thinking", effort)
                        else:
                            self.reviewer(
                                env={
                                    "AUTOREVIEW_MODEL": "gpt-6-astra",
                                    "AUTOREVIEW_THINKING": effort,
                                }
                            )

    def test_cli_effort_overrides_invalid_astra_environment_default(self) -> None:
        reviewer = self.reviewer(
            "--thinking",
            "high",
            env={
                "AUTOREVIEW_MODEL": "gpt-6-astra",
                "AUTOREVIEW_THINKING": "none",
            },
        )

        self.assertEqual(reviewer.model, "gpt-6-astra")
        self.assertEqual(reviewer.thinking, "high")

    def test_other_codex_models_keep_config_default_and_full_effort_range(self) -> None:
        reviewer = self.reviewer("--model", "gpt-5.6-sol")
        self.assertEqual(reviewer.model, "gpt-5.6-sol")
        self.assertIsNone(reviewer.thinking)

        for effort in ("none", "minimal"):
            with self.subTest(effort=effort):
                self.assertEqual(self.reviewer("--model", "gpt-5.6-sol", "--thinking", effort).thinking, effort)


class EngineRoutingTests(unittest.TestCase):
    def reviewer(self, *arguments: str, env: dict[str, str] | None = None):
        with mock.patch.dict(os.environ, env or {}, clear=True), mock.patch.object(
            sys, "argv", ["autoreview", *arguments]
        ):
            args = AUTOREVIEW["parse_args"]()
            return AUTOREVIEW["reviewer_args"](args)[0]

    def test_orb_selects_amp_sol_6_1_xhigh(self) -> None:
        reviewer = self.reviewer(env={"AMP_ORB": "1"})
        self.assertEqual(reviewer.engine, "amp")
        self.assertEqual(reviewer.model, "openai/gpt-6.1-sol")
        self.assertEqual(reviewer.thinking, "xhigh")
        self.assertIsNone(reviewer.fallback_model)

    def test_outside_orb_selects_codex_sol_6_1_xhigh_without_fallback(self) -> None:
        reviewer = self.reviewer()
        self.assertEqual(reviewer.engine, "codex")
        self.assertEqual(reviewer.model, "gpt-6.1-sol")
        self.assertEqual(reviewer.thinking, "xhigh")
        self.assertIsNone(reviewer.fallback_model)

    def test_explicit_sol_keeps_access_fallback_and_config_effort(self) -> None:
        for arguments, env in (
            (("--model", "gpt-5.6-sol"), {}),
            ((), {"AUTOREVIEW_MODEL": "codex=gpt-5.6-sol"}),
        ):
            with self.subTest(arguments=arguments, env=env):
                reviewer = self.reviewer(*arguments, env=env)
                self.assertEqual(reviewer.model, "gpt-5.6-sol")
                self.assertIsNone(reviewer.thinking)
                self.assertEqual(reviewer.fallback_model, "gpt-5.6-terra")

    def test_codex_default_respects_effort_overrides(self) -> None:
        reviewer = self.reviewer(
            "--thinking", "xhigh", env={"AUTOREVIEW_THINKING": "medium"}
        )
        self.assertEqual(reviewer.model, "gpt-6.1-sol")
        self.assertEqual(reviewer.thinking, "xhigh")
        reviewer = self.reviewer(env={"AUTOREVIEW_THINKING": "medium"})
        self.assertEqual(reviewer.thinking, "medium")

    def test_sol_6_1_accepts_supported_efforts_and_rejects_unsupported(self) -> None:
        for effort in ("low", "medium", "high", "xhigh", "max"):
            with self.subTest(effort=effort):
                self.assertEqual(self.reviewer("--thinking", effort).thinking, effort)
        for effort in ("none", "minimal", "ultra"):
            with self.subTest(effort=effort):
                with self.assertRaisesRegex(SystemExit, f"invalid thinking level for codex model gpt-6.1-sol: {effort}"):
                    self.reviewer(env={"AUTOREVIEW_THINKING": effort})

    def test_claude_selection_defaults_to_opus_5_5_high(self) -> None:
        for arguments, env in (
            (("--engine", "claude"), {}),
            ((), {"AUTOREVIEW_ENGINE": "claude"}),
            (("--reviewers", "claude"), {"AMP_ORB": "1"}),
        ):
            with self.subTest(arguments=arguments, env=env):
                reviewer = self.reviewer(*arguments, env=env)
                self.assertEqual(reviewer.engine, "claude")
                self.assertEqual(reviewer.model, "claude-opus-5-5")
                self.assertEqual(reviewer.thinking, "high")

    def test_claude_explicit_model_and_effort_override_defaults(self) -> None:
        reviewer = self.reviewer(
            "--engine", "claude", "--model", "claude=sonnet", "--thinking", "claude=max",
            env={"AUTOREVIEW_MODEL": "claude=fable", "AUTOREVIEW_THINKING": "claude=low"},
        )
        self.assertEqual(reviewer.model, "sonnet")
        self.assertEqual(reviewer.thinking, "max")

    def test_claude_passes_opus_5_5_and_high_to_cli(self) -> None:
        reviewer = self.reviewer("--reviewers", "claude:claude-opus-5-5:high")
        run = AUTOREVIEW["run_claude"]
        heartbeat = mock.Mock(return_value=subprocess.CompletedProcess([], 0, stdout="{}"))
        with mock.patch.dict(run.__globals__, {"run_with_heartbeat": heartbeat}):
            self.assertEqual(run(reviewer, Path.cwd(), "review fixture"), "{}")
        command = heartbeat.call_args.args[0]
        self.assertEqual(command[command.index("--model") + 1], "claude-opus-5-5")
        self.assertEqual(command[command.index("--effort") + 1], "high")

    def test_explicit_engine_wins_over_orb_and_environment(self) -> None:
        reviewer = self.reviewer(
            "--engine", "codex",
            env={"AMP_ORB": "1", "AUTOREVIEW_ENGINE": "amp"},
        )
        self.assertEqual(reviewer.engine, "codex")

    def test_environment_engine_wins_over_orb(self) -> None:
        reviewer = self.reviewer(env={"AMP_ORB": "1", "AUTOREVIEW_ENGINE": "codex"})
        self.assertEqual(reviewer.engine, "codex")

    def test_explicit_model_and_effort_win_over_orb_defaults(self) -> None:
        reviewer = self.reviewer(
            "--model", "amp=openai/gpt-5.6-sol", "--thinking", "amp=xhigh",
            env={"AMP_ORB": "1"},
        )
        self.assertEqual(reviewer.model, "openai/gpt-5.6-sol")
        self.assertEqual(reviewer.thinking, "xhigh")


if __name__ == "__main__":
    unittest.main()
