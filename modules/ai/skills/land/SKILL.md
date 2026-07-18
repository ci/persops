---
name: land
description: "Merge a finished PR or PR stack and tear down the session workspace or worktree. Only on a direct ask: /land, 'land it', or 'merge and clean up'. Never proactively."
---

# Land

Close the loop on approved work: merge, then clean up. Invoke only when the
user directly asks — `/land`, "land it", "merge & cleanup worktree", "merge the
stack". Never run this on your own initiative after opening a PR; opening a PR
ends at the PR.

## Contract

- Merge only PRs this session owns or ones the user named.
- Run `jj status` first. When it succeeds, use `$jj`; for a stack managed by
  bookmarks, use `$jjpr` for status, reconciliation, and landing.
- Conflicts and stale base are yours to fix: get the branch on latest main
  (rebase or merge, whichever is simpler — don't ask which), resolve conflicts,
  rerun the repo gate if code changed, push, continue.
- `$jjpr` stacks merge base-most first and reconcile the remainder according to
  config. For plain Git stacks, retarget/rebase each child, wait for CI, then
  merge it.
- Release PRs (release-please and similar) and staging/prod deploy watching are
  explicit-ask only. Do not merge a release PR or babysit deploy workflows
  unless the user asked for that in this session.
- Use the repo's standard merge method (check repo settings or recent merge
  history); ask only if genuinely ambiguous.
- Leave the user's main checkout alone unless asked to update it.

## Workflow

1. Identify target: the current bookmark/branch's PR, the named PR, or the
   explicit top bookmark of a stack. In jj, record `jj workspace list` and the
   session workspace name/root before landing.
2. Watch checks (`gh pr checks --watch`, background). Red CI: fix, push,
   re-watch until green.
3. JJ stack: run `jjpr status <top>`, `jjpr merge <top> --dry-run`, then
   `jjpr merge <top>`. Re-run after any CI/review blocker clears; do not
   reproduce its reconciliation manually with Git commands.
4. Single PR or plain Git stack: sync a stale/conflicted branch per contract,
   push, merge, and delete the remote branch if the merge did not.
5. Plain Git stack: repeat 2 and 4 per child in order.
6. Only if explicitly asked: merge the release PR, watch staging/prod deploy
   workflows, report deployed versions.
7. Teardown only the session's isolated checkout. In jj, inspect its `@` and
   diff, resolve its exact root, forget it from a surviving workspace, and
   abandon only a captured disposable empty working-copy change. `forget` does
   not delete files, changes, or bookmarks; remove only the verified directory.
   In plain Git, verify clean, remove the worktree, delete the local branch,
   and prune.
8. Report: merged PR URLs + merge SHAs, CI state, what was cleaned up, and
   anything left (e.g. release PR untouched).
