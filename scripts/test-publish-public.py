#!/usr/bin/env python3
"""Tests for scripts/publish-public, run against a throwaway git repo."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "publish-public"

# Fixtures that must trip the scan, assembled at runtime because this file is
# published and scanned too.
LAN_IP = "192." + "168.1.10"
TS_IP = "100." + "101.102.103"
MAC = ":".join(["aa", "bb", "cc", "dd", "ee", "ff"])
EMAIL = "me" + "@" + "personal.dev"
TAILNET = "box.some-tailnet" + ".ts.net"


def run(*args: str, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, check=check, capture_output=True, text=True)


class PublishPublicTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "repo"
        self.root.mkdir()
        files = {
            ".public-paths": "# comment\nmodules/shared  # trailing comment\n",
            ".claude-plugin/marketplace.json": json.dumps(
                {
                    "plugins": [
                        {"name": "base", "source": "./", "skills": ["./skills/one"]},
                        {"name": "mod", "source": "./plugins/mod"},
                    ]
                }
            ),
            "public/README.md": "# public\n",
            "modules/shared/tool.nix": "{ }\n",
            "skills/one/SKILL.md": "Ask git@github.com:org/repo or you@example.com.\n",
            "skills/two/SKILL.md": "unlisted\n",
            "plugins/mod/plugin.json": "{}\n",
            "machines/home.nix": f'lan = "{LAN_IP}";\n',
        }
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        run("git", "init", "-q", cwd=self.root)
        self.commit("init")

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def commit(self, message: str) -> None:
        run("git", "add", "-A", cwd=self.root)
        run(
            "git", "-c", "user.name=T", "-c", "user.email=t@example.com",
            "-c", "commit.gpgSign=false", "commit", "-qm", message, cwd=self.root,
        )

    def publish(self, *args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
        return run(str(SCRIPT), *args, cwd=self.root, check=check)

    def test_paths_merge_allowlist_and_marketplace(self) -> None:
        out = self.publish("paths", check=True).stdout.split()
        self.assertEqual(out, ["modules/shared", "plugins/mod", "skills/one"])

    def test_export_holds_only_public_files(self) -> None:
        out = Path(self.tmp.name) / "out"
        result = self.publish("export", str(out), "--no-deny")
        self.assertEqual(result.returncode, 0, result.stderr)
        files = sorted(str(p.relative_to(out)) for p in out.rglob("*") if p.is_file())
        self.assertEqual(
            files,
            [
                ".public-paths",
                "README.md",
                "modules/shared/tool.nix",
                "plugins/mod/plugin.json",
                "skills/one/SKILL.md",
            ],
        )

    def test_export_uses_committed_content(self) -> None:
        (self.root / "modules/shared/tool.nix").write_text(f'ip = "{LAN_IP}";\n')
        out = Path(self.tmp.name) / "out"
        result = self.publish("export", str(out), "--no-deny")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((out / "modules/shared/tool.nix").read_text(), "{ }\n")

    def test_builtin_patterns_block_without_echoing_the_value(self) -> None:
        (self.root / "modules/shared/tool.nix").write_text(
            f'a = "{LAN_IP}";\nb = "{TS_IP}";\nc = "{MAC}";\n'
            f'd = "{EMAIL}";\ne = "{TAILNET}";\n'
        )
        self.commit("leak")
        result = self.publish("export", str(Path(self.tmp.name) / "out"), "--no-deny")
        self.assertEqual(result.returncode, 1)
        for name in ("private IPv4", "Tailscale IPv4", "MAC address", "email address", "tailnet name"):
            self.assertIn(name, result.stderr)
        self.assertNotIn(LAN_IP, result.stderr)
        self.assertNotIn("personal.dev", result.stderr)

    def test_deny_file_is_required_unless_no_deny(self) -> None:
        result = self.publish("export", str(Path(self.tmp.name) / "out"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("deny file", result.stderr)

    def test_deny_file_patterns_match_case_insensitively(self) -> None:
        (self.root / ".public-deny").write_text("# private names\nsecret-room\n")
        (self.root / "modules/shared/tool.nix").write_text("# Secret-Room lamp\n")
        self.commit("deny")
        result = self.publish("export", str(Path(self.tmp.name) / "out"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("modules/shared/tool.nix:1: .public-deny line 2", result.stderr)

    def test_rejects_paths_that_escape_or_glob(self) -> None:
        for entry in (".", "../x", "/etc", "modules/*"):
            (self.root / ".public-paths").write_text(entry + "\n")
            self.commit(f"bad {entry}")
            result = self.publish("paths")
            self.assertNotEqual(result.returncode, 0, entry)

    def test_binary_files_are_scanned(self) -> None:
        (self.root / "modules/shared/blob.bin").write_bytes(b"\xff\xfe" + LAN_IP.encode() + b"\x00")
        self.commit("blob")
        result = self.publish("export", str(Path(self.tmp.name) / "out"), "--no-deny")
        self.assertEqual(result.returncode, 1)
        self.assertIn("modules/shared/blob.bin:1: private IPv4", result.stderr)

    def test_missing_public_path_fails(self) -> None:
        (self.root / ".public-paths").write_text("modules/gone\n")
        self.commit("stale")
        result = self.publish("paths")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("modules/gone", result.stderr)

    def test_diff_covers_only_public_paths(self) -> None:
        base = run("git", "rev-parse", "HEAD", cwd=self.root).stdout.strip()
        (self.root / "modules/shared/tool.nix").write_text("{ x = 1; }\n")
        (self.root / "machines/home.nix").write_text("{ }\n")
        self.commit("change")
        diff = self.publish("diff", base, check=True).stdout
        self.assertIn("modules/shared/tool.nix", diff)
        self.assertNotIn("machines/home.nix", diff)

    def test_diff_shows_paths_that_stop_being_public(self) -> None:
        base = run("git", "rev-parse", "HEAD", cwd=self.root).stdout.strip()
        (self.root / ".public-paths").write_text("plugins/mod\n")
        (self.root / "modules/shared/tool.nix").write_text("{ y = 1; }\n")
        self.commit("unpublish")
        diff = self.publish("diff", base, check=True).stdout
        self.assertIn("modules/shared/tool.nix", diff)


if __name__ == "__main__":
    unittest.main()
