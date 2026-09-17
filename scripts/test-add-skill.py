#!/usr/bin/env python3
"""Exercise revision/path preservation and all-or-nothing collision preflight."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHA = "a" * 40


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ai = self.root / "modules/ai"
        self.scripts = self.ai / "scripts"
        self.scripts.mkdir(parents=True)
        self.skills = self.ai / "skills"
        self.skills.mkdir()
        self.overrides = self.ai / "skill-overrides.json"
        self.overrides.write_text('{"existing":{"profile":"coding","recursive":true}}\n')
        for filename in ("add-skill.sh", "resolve-skill-source.py"):
            shutil.copy2(ROOT / "modules/ai/scripts" / filename, self.scripts / filename)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.write_executable("gh", '''#!/usr/bin/env python3
import json, os, sys
from urllib.parse import unquote
fixture = json.loads(os.environ["IMPORT_FIXTURE"])
endpoint = unquote(sys.argv[2])
if fixture.get("api_error"):
    print(json.dumps({"status": "403", "message": "rate limited"}))
    sys.exit(1)
if endpoint == "repos/owner/repo/commits/" + fixture["ref"]:
    print(json.dumps({"sha": "a" * 40}))
elif endpoint == "repos/owner/repo/contents/" + fixture["path"] + "/SKILL.md?ref=" + "a" * 40 and not fixture.get("missing_path"):
    print(json.dumps({"type": "file"}))
else:
    print(json.dumps({"status": "422" if "/commits/" in endpoint else "404", "message": "No commit found for SHA: " + endpoint}))
    sys.exit(1)
''')
        self.write_executable("bunx", '''#!/usr/bin/env python3
import json, os, pathlib, sys
fixture = json.loads(os.environ["IMPORT_FIXTURE"])
pathlib.Path(os.environ["IMPORT_CALL"]).write_text(json.dumps(sys.argv[1:]))
source = sys.argv[4]
expected = "https://github.com/owner/repo/tree/" + "a" * 40 + "/" + fixture["path"]
if source.startswith("https://github.com/") and source != expected:
    sys.exit("wrong revision or path: " + source)
lock = {"skills": {}}
for name in fixture.get("skills", ["display-name"]):
    path = pathlib.Path("skills") / name
    path.mkdir(parents=True)
    (path / "SKILL.md").write_text("---\\nname: " + name + "\\ndescription: fixture\\n---\\npinned revision content\\n")
    lock["skills"][name] = {"source": "owner/repo", "sourceType": "github", "computedHash": "fixture-hash"}
pathlib.Path("skills-lock.json").write_text(json.dumps(lock))
''')
        self.fixture = {"ref": "v1.2", "path": "skills/folder-name"}
        self.call = self.root / "bunx-call.json"

    def write_executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_import(self, source, *args):
        return subprocess.run(
            ["bash", str(self.scripts / "add-skill.sh"), source, *args],
            env={**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}",
                 "IMPORT_FIXTURE": json.dumps(self.fixture), "IMPORT_CALL": str(self.call)},
            text=True, capture_output=True, check=False,
        )

    def test_ref_and_subpath_pinned(self):
        for ref in ("v1.2", "main", "feature/secret-flow", SHA, SHA[:8]):
            for kind, suffix in (("tree", ""), ("blob", "/SKILL.md")):
                with self.subTest(ref=ref, kind=kind):
                    self.fixture["ref"] = ref
                    source = f"https://github.com/owner/repo/{kind}/{ref}/skills/folder-name{suffix}"
                    result = self.run_import(source)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    target = self.skills / "display-name"
                    metadata = (target / "UPSTREAM.txt").read_text()
                    self.assertIn(f"requested_source = {source}\n", metadata)
                    self.assertIn(f"requested_ref = {ref}\n", metadata)
                    self.assertIn(f"revision = {SHA}\n", metadata)
                    self.assertIn("subpath = skills/folder-name\n", metadata)
                    self.assertIn("pinned revision content", (target / "SKILL.md").read_text())
                    shutil.rmtree(target)

    def test_batch_collision_leaves_no_partial_import_or_profile_change(self):
        self.fixture["skills"] = ["aaa-new", "zzz-existing"]
        existing = self.skills / "zzz-existing"
        existing.mkdir()
        (existing / "SKILL.md").write_text("keep me")
        before = self.overrides.read_bytes()
        result = self.run_import("owner/repo")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Target already exists", result.stderr)
        self.assertEqual(list(self.skills.iterdir()), [existing])
        self.assertEqual((existing / "SKILL.md").read_text(), "keep me")
        self.assertEqual(self.overrides.read_bytes(), before)

    def test_dangling_destination_symlink_is_collision(self):
        self.fixture["skills"] = ["aaa-new", "zzz-existing"]
        existing = self.skills / "zzz-existing"
        existing.symlink_to(self.root / "missing")
        result = self.run_import("owner/repo")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(existing.is_symlink())
        self.assertFalse((self.skills / "aaa-new").exists())

    def test_missing_ref_or_path_never_runs_installer(self):
        for missing in ("ref", "path"):
            with self.subTest(missing=missing):
                self.fixture["missing_path"] = missing == "path"
                ref = "missing" if missing == "ref" else "v1.2"
                result = self.run_import(f"https://github.com/owner/repo/tree/{ref}/skills/folder-name")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.call.exists())
                self.assertEqual(list(self.skills.iterdir()), [])

    def test_api_failure_is_not_treated_as_missing_ref(self):
        self.fixture["api_error"] = True
        result = self.run_import("https://github.com/owner/repo/tree/v1.2/skills/folder-name")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.call.exists())

    def test_repo_source_preserves_selection_arguments(self):
        result = self.run_import("owner/repo", "--skill", "display-name")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(self.call.read_text())
        self.assertEqual(args[-2:], ["--skill", "display-name"])
        self.assertIn("owner/repo", args)


if __name__ == "__main__":
    unittest.main()
