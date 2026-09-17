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
        reviewer = self.reviewer()
        self.assertEqual(reviewer.model, "gpt-5.6-sol")
        self.assertIsNone(reviewer.thinking)

        for effort in ("none", "minimal"):
            with self.subTest(effort=effort):
                self.assertEqual(self.reviewer("--thinking", effort).thinking, effort)


if __name__ == "__main__":
    unittest.main()
