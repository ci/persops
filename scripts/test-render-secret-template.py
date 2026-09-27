import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / "modules/secrets/render-secret-template.py"
spec = importlib.util.spec_from_file_location("render", SCRIPT)
render = importlib.util.module_from_spec(spec)
spec.loader.exec_module(render)


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.key = self.root / "key"
        self.key.write_text("-----BEGIN KEY-----\nabc\n-----END KEY-----")
        self.hash = self.root / "hash"
        self.hash.write_text("$2a$10$x'y\n")
        self.sources = {"op://persops/Item With Spaces/key": str(self.key), "op://persops/ntfy/hash": str(self.hash)}

    def tearDown(self):
        self.dir.cleanup()

    def test_template_controls_newlines_and_literal_values(self):
        out = render.render(
            "KEY={{ op://persops/Item With Spaces/key }}\nUSERS='cat:{{op://persops/ntfy/hash}}:user'\n", self.sources
        )
        self.assertEqual(out, "KEY=-----BEGIN KEY-----\nabc\n-----END KEY-----\nUSERS='cat:$2a$10$x'y:user'\n")

    def test_unknown_or_empty_reference_fails_without_value(self):
        with self.assertRaisesRegex(KeyError, "op://persops/missing/x"):
            render.render("{{ op://persops/missing/x }}", self.sources)
        self.hash.write_text("\n")
        with self.assertRaises(ValueError):
            render.render("{{ op://persops/ntfy/hash }}", self.sources)

    def test_cli_writes_atomically_with_mode_and_keeps_old_file_on_failure(self):
        output = self.root / "out" / "env"
        output.parent.mkdir()
        template = self.root / "t.tpl"
        template.write_text("{{ op://persops/Item With Spaces/key }}\n")
        spec_path = self.root / "spec.json"
        spec_path.write_text(json.dumps({"template": str(template), "sources": self.sources, "path": str(output), "mode": "0440"}))
        subprocess.run([sys.executable, SCRIPT, spec_path], check=True, capture_output=True)
        self.assertTrue(output.read_text().endswith("-----END KEY-----\n"))
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o440)
        self.assertEqual(sorted(os.listdir(output.parent)), ["env"])

        template.write_text("{{ op://persops/missing/x }}\n")
        result = subprocess.run([sys.executable, SCRIPT, spec_path], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("abc", result.stderr)
        self.assertTrue(output.read_text().endswith("-----END KEY-----\n"))
        self.assertEqual(sorted(os.listdir(output.parent)), ["env"])


if __name__ == "__main__":
    unittest.main()
