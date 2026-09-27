"""Render a secret template from files that opnix materialized.

Templates use `op inject` syntax (`{{ op://Vault/Item/field }}`), so the same
file works with `op inject` on hosts without opnix. The spec JSON maps each
reference to the file holding its value; the template controls surrounding
text, including trailing newlines that 1Password field values lack.
"""

import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

# Keep in sync with refsOf in modules/secrets/lib.nix.
PLACEHOLDER = re.compile(r"\{\{([^}]*)\}\}")


def render(template, sources):
    def value(match):
        reference = match.group(1).strip()
        if reference not in sources:
            raise KeyError(f"no source file for {reference}")
        text = Path(sources[reference]).read_text().rstrip("\n")
        if not text:
            raise ValueError(f"empty value for {reference}")
        return text

    return PLACEHOLDER.sub(value, template)


def write(path, content, owner, group, mode):
    path = Path(path)
    # Same-directory temp file so the rename is atomic for concurrent readers.
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(content)
        os.chmod(temporary, int(mode, 8))
        if owner or group:
            shutil.chown(temporary, owner or None, group or None)
        os.replace(temporary, path)
    except BaseException:
        os.unlink(temporary)
        raise


def main(spec_path):
    spec = json.loads(Path(spec_path).read_text())
    template = Path(spec["template"]).read_text()
    content = render(template, spec["sources"])
    write(spec["path"], content, spec.get("owner"), spec.get("group"), spec["mode"])
    print(f"rendered {spec['path']}")
    return 0


if __name__ == "__main__":
    os.umask(0o077)
    try:
        sys.exit(main(sys.argv[1]))
    except (KeyError, OSError, ValueError) as error:
        # Messages name references and paths only, never values.
        print(f"render failed: {error}", file=sys.stderr)
        sys.exit(1)
