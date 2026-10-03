#!/usr/bin/env python3
from __future__ import annotations

import os
import runpy
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock


AUTOREVIEW = runpy.run_path(Path(__file__).with_name("autoreview"))


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
