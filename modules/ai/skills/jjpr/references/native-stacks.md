# Native GitHub Stacks

Use only when the user wants GitHub's native Stack UI. jj and jjpr still own
history, pushes, and PRs; gh-stack only registers and lands them. A Stack holds
2–100 PRs; keep a single PR unstacked.

Run `gh auth status --active --hostname github.com` (never `--show-token`) and
`gh stack --version` first. Set `GH_REPO=OWNER/REPO` on every `gh stack` call.

## Create

Submit with jjpr (see the main skill), record the PR numbers bottom to top,
then link by number only (branch names let gh-stack push):

```bash
GH_REPO=OWNER/REPO gh stack link --base <base> PR1 PR2 PR3
gh api repos/OWNER/REPO/pulls/PR1 -H 'X-GitHub-Api-Version: 2026-03-10' --jq .stack
```

## Update

Rewrite with jj and run `jjpr submit` as usual. A content change updates
cleanly. To add PRs on top, submit them, then link the full list in order:
`gh stack link --base <base> PR1 PR2 PR3 PR4`.

jjpr refuses before pushing when the local graph would retarget a native
member. That is a reshape (insert, reorder, remove); ask the user first, then
`gh stack unstack STACK`, reshape with jj, `jjpr submit`, and link again.
`gh stack link` can rewrite PR bases before it rejects a bad order, so never
use it to test an order.

## Land

Never `jjpr merge`, `jjpr watch`, `gh pr merge`, or auto-merge for members.

```bash
GH_REPO=OWNER/REPO gh stack merge PR --yes --merge-method METHOD
```

Use the repo's standard merge method (see `$land`). This lands `PR` and every
member below it. gh-stack 0.1.x reads a bare number as a Stack number first:
if `gh api repos/OWNER/REPO/stacks/PR` exists, stop and ask which one is
meant. Check approvals and CI on every PR in the merged range first; gh-stack
doesn't apply jjpr's gates.

## Reconcile after a partial land

GitHub retargets and rebases the survivors on its side. The rebased commits
lose jj change IDs, so after a fetch they show up as new changes and the old
local copies stay behind (persops keeps unreachable commits) without a
divergence marker.

```bash
jj git fetch --remote <remote>
jj bookmark list --all-remotes
jj log -r '<base>@<remote>..'
```

1. Wait until the survivors' heads stop changing on GitHub.
2. Point each survivor bookmark at its fetched head if jj didn't:
   `jj bookmark set <bm> -r '<bm>@<remote>'`. Do this only after checking that
   the old local copy has no unpushed edits.
3. Move the empty `@`: `jj rebase -r @ -d <top>`.
4. Abandon the old copies by exact commit ID, after checking they have no
   bookmarks, workspaces, or descendants: `jj abandon OLD_ID...`.
5. Abandon the merged PRs' local commits the same way, then delete their
   local bookmarks.

Before the next write, require every local bookmark to equal its
`@<remote>` counterpart and no conflicts in `<base>..<top>`. After the final
land, compare `<base>@<remote>` with the original top tree as in the main
skill.
