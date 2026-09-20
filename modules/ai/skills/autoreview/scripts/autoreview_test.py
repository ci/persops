#!/usr/bin/env python3
from __future__ import annotations

import os
import runpy
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

    def test_orb_selects_amp_astra_high(self) -> None:
        reviewer = self.reviewer(env={"AMP_ORB": "1"})
        self.assertEqual(reviewer.engine, "amp")
        self.assertEqual(reviewer.model, "openai/gpt-6-astra")
        self.assertEqual(reviewer.thinking, "high")
        self.assertIsNone(reviewer.fallback_model)

    def test_outside_orb_selects_codex_astra_high_without_fallback(self) -> None:
        reviewer = self.reviewer()
        self.assertEqual(reviewer.engine, "codex")
        self.assertEqual(reviewer.model, "gpt-6-astra")
        self.assertEqual(reviewer.thinking, "high")
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
        self.assertEqual(reviewer.model, "gpt-6-astra")
        self.assertEqual(reviewer.thinking, "xhigh")
        reviewer = self.reviewer(env={"AUTOREVIEW_THINKING": "medium"})
        self.assertEqual(reviewer.thinking, "medium")

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
