#!/usr/bin/env python3
"""Pin a GitHub tree/blob skill URL without losing its ref or subdirectory."""

import json
import re
import subprocess
import sys
from urllib.parse import quote, unquote, urlsplit


def github(endpoint):
    result = subprocess.run(
        ["gh", "api", endpoint], capture_output=True, text=True, check=False
    )
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        raise ValueError(result.stderr.strip() or "GitHub returned invalid JSON") from None
    if result.returncode:
        if isinstance(data, dict):
            status = str(data.get("status"))
            if status == "404" or (
                status == "422" and data.get("message", "").startswith("No commit found for SHA:")
            ):
                return None
        raise ValueError(result.stderr.strip() or "GitHub request failed")
    return data


def resolve(source):
    url = urlsplit(source)
    parts = unquote(url.path).strip("/").split("/")
    if url.scheme != "https" or url.netloc != "github.com" or len(parts) < 4:
        raise ValueError("Expected a GitHub tree/blob URL")
    owner, repo, kind, *tail = parts
    if kind not in {"tree", "blob"} or any(p in {"", ".", ".."} for p in parts):
        raise ValueError("Invalid GitHub skill path")

    # GitHub URLs do not delimit slash-containing refs. Resolve the longest
    # existing ref before handing the unambiguous SHA URL to skills add.
    for length in range(len(tail), 0, -1):
        ref = "/".join(tail[:length])
        commit = github(f"repos/{owner}/{repo}/commits/{quote(ref, safe='')}")
        if commit is None:
            continue
        sha = commit.get("sha", "")
        if not re.fullmatch(r"[0-9a-f]{40}", sha):
            raise ValueError("GitHub did not resolve a commit SHA")
        path = "/".join(tail[length:])
        if path == "SKILL.md":
            path = ""
        elif path.endswith("/SKILL.md"):
            path = path.removesuffix("/SKILL.md")
        if kind == "blob" and tail[-1] != "SKILL.md":
            raise ValueError("A blob URL must select SKILL.md")
        skill_file = f"{path}/SKILL.md" if path else "SKILL.md"
        entry = github(
            f"repos/{owner}/{repo}/contents/{quote(skill_file)}?ref={sha}"
        )
        if not isinstance(entry, dict) or entry.get("type") != "file":
            raise ValueError(f"No SKILL.md at {ref}:{path or '.'}")
        return {
            "url": f"https://github.com/{owner}/{repo}/tree/{sha}" + (f"/{path}" if path else ""),
            "ref": ref,
            "commit": sha,
            "path": path,
        }
    raise ValueError("Requested GitHub revision not found or repository inaccessible")


if __name__ == "__main__":
    try:
        print(json.dumps(resolve(sys.argv[1])))
    except (ValueError, OSError) as exc:
        sys.exit(str(exc))
