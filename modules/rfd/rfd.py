#!@python3@
"""Find and open Oxide RFDs from a local clone of oxidecomputer/rfd.

Every RFD lives on a branch named after its 4-digit number until it is
published and merged to master, so the index reads README headers straight
from origin/HEAD plus every origin/NNNN branch. Only `rfd fetch` touches
the network.
"""

import os
import re
import subprocess
import sys

GIT = "@git@"
FZF = "@fzf@"
SITE = "https://rfd.shared.oxide.computer/rfd"
REPO = os.path.expanduser(os.environ.get("RFD_REPO", "~/p/oxide/rfd"))
USAGE = """usage: rfd [N]            pick an RFD (no N) or open RFD N
       rfd -d N           open RFD N's discussion PR
       rfd fetch          git fetch the RFD repo
       rfd list | show N  print the index / RFD N's source"""


def git(*args, stdin=None):
    return subprocess.run(
        [GIT, "-C", REPO, *args], input=stdin, capture_output=True, check=True
    ).stdout


def cat_files(paths):
    """Map each existing `rev:path` to its contents with one git process."""
    out = git("cat-file", "--batch", stdin="".join(p + "\n" for p in paths).encode())
    blobs, i = {}, 0
    for path in paths:
        nl = out.index(b"\n", i)
        header = out[i:nl].decode()
        i = nl + 1
        if header.endswith(" missing"):
            continue
        size = int(header.split()[2])
        blobs[path] = out[i : i + size].decode("utf-8", "replace")
        i += size + 1
    return blobs


def attr(lines, name):
    for line in lines:
        m = re.match(rf"^:?{name}:\s*(.*)$", line)
        if m:
            return m.group(1).strip()
    return ""


def sources():
    """Yield (number, rev) candidates, master first so it wins over a stale branch."""
    master = git("ls-tree", "--name-only", "origin/HEAD", "rfd/").decode().split()
    for path in master:
        n = os.path.basename(path)
        if re.fullmatch(r"\d{4}", n):
            yield int(n), "origin/HEAD"
    refs = git("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin/")
    for ref in refs.decode().split():
        m = re.fullmatch(r"origin/(\d{4})", ref)
        if m:
            yield int(m.group(1)), ref


def index():
    candidates = list(sources())
    paths = [
        f"{rev}:rfd/{n:04d}/README.{ext}" for n, rev in candidates for ext in ("adoc", "md")
    ]
    blobs = cat_files(paths)
    rfds = {}
    for path in paths:
        body = blobs.get(path)
        n = int(path.split("/")[-2])
        if body is None or n in rfds:
            continue
        head = body.splitlines()[:40]
        title = next((line for line in head if re.match(r"^[#=] RFD ", line)), "")
        title = re.sub(r"^[#=] RFD 0*\d+:?\s*", "", title)
        rfds[n] = {
            "title": title or "(untitled)",
            "state": attr(head, "state") or "?",
            "discussion": attr(head, "discussion"),
            "path": path,
            "body": body,
        }
    return rfds


def lookup(arg):
    if not re.fullmatch(r"\d{1,4}", arg or ""):
        sys.exit(f"rfd: not an RFD number: {arg}")
    rfd = index().get(int(arg))
    if rfd is None:
        sys.exit(f"rfd: RFD {int(arg)} not found locally (try `rfd fetch`)")
    return int(arg), rfd


def open_url(url):
    subprocess.run(["/usr/bin/open", url], check=True)


def open_discussion(n, rfd):
    # Fresh RFDs have an empty :discussion: until their PR opens.
    open_url(rfd["discussion"] or f"{SITE}/{n:04d}/discussion")


def lines(rfds):
    return "".join(
        f"{n:04d}  {r['state']:<13}  {r['title']}\n" for n, r in sorted(rfds.items(), reverse=True)
    )


def pick():
    rfds = index()
    newest = git(
        "for-each-ref", "--sort=-committerdate", "--count=1",
        "--format=%(committerdate:relative)", "refs/remotes/origin/",
    ).decode().strip()
    me = os.path.abspath(sys.argv[0])
    result = subprocess.run(
        [
            # Match number + title only (state words match nearly anything);
            # equal scores keep the newest-first input order.
            FZF, "--nth=1,3..", "--tiebreak=index",
            f"--header=enter: open · ctrl-d: discussion · newest RFD commit {newest}",
            f"--preview={me} show {{1}}", "--preview-window=right,60%,wrap",
            f"--bind=ctrl-d:execute-silent({me} -d {{1}})",
        ],
        input=lines(rfds).encode(),
        stdout=subprocess.PIPE,
    )
    if result.returncode == 0:
        n = int(result.stdout.split()[0])
        open_url(f"{SITE}/{n:04d}")


def main(argv):
    if not os.path.isdir(os.path.join(REPO, ".git")):
        sys.exit(f"rfd: no RFD clone at {REPO} (set RFD_REPO)")
    match argv:
        case []:
            pick()
        case ["fetch"]:
            subprocess.run([GIT, "-C", REPO, "fetch", "--prune", "origin"], check=True)
        case ["list"]:
            sys.stdout.write(lines(index()))
        case ["show", arg]:
            sys.stdout.write(lookup(arg)[1]["body"])
        case ["-d", arg]:
            open_discussion(*lookup(arg))
        case [arg] if re.fullmatch(r"\d{1,4}", arg):
            open_url(f"{SITE}/{int(arg):04d}")
        case _:
            sys.exit(USAGE)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except subprocess.CalledProcessError as e:
        sys.exit(f"rfd: {' '.join(map(str, e.cmd))} failed: {e.stderr.decode().strip() if e.stderr else e}")
