#!/usr/bin/env python3
"""Verify retirement preserves mutable files and leaves unrelated Pi content alone."""

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "modules/ai/scripts/retire-pi-compound-engineering.sh"


class RetirementTests(unittest.TestCase):
    def run_retirement(self, root):
        subprocess.run(["bash", str(SCRIPT), str(root)], check=True, capture_output=True)

    def test_preserves_content_and_is_idempotent(self):
        with tempfile.TemporaryDirectory(prefix="pi retirement ") as temp:
            root = Path(temp)
            retired = [
                "skills/ce-work/SKILL.md",
                "skills/lfg/SKILL.md",
                "agents/ce-reviewer.md",
                "compound-engineering/install-manifest.json",
            ]
            retained = ["skills/grilling/SKILL.md", "agents/custom.md", "settings.json"]
            for name in retired + retained:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"local edit: {name}")
            self.run_retirement(root)
            backups = list((root / "backups").iterdir())
            self.assertEqual(len(backups), 1)
            for name in retired:
                self.assertFalse((root / name).exists())
                self.assertEqual((backups[0] / name).read_text(), f"local edit: {name}")
            for name in retained:
                self.assertEqual((root / name).read_text(), f"local edit: {name}")
            self.run_retirement(root)
            self.assertEqual(list((root / "backups").iterdir()), backups)

    def test_preserves_broken_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "skills").mkdir()
            link = root / "skills/ce-old"
            link.symlink_to("missing-target")
            self.run_retirement(root)
            self.assertFalse(link.is_symlink())
            backup = next((root / "backups").iterdir()) / "skills/ce-old"
            self.assertEqual(backup.readlink(), Path("missing-target"))

    def test_empty_install_is_unchanged(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.run_retirement(root)
            self.assertEqual(list(root.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
