---
name: land
description: "Merge a finished PR or PR stack and tear down the session worktree. Only on a direct ask: /land, 'land it', 'merge & cleanup worktree'. Never proactively."
---

# Land

Close the loop on approved work: merge, then clean up. Invoke only when the
user directly asks — `/land`, "land it", "merge & cleanup worktree", "merge the
stack". Never run this on your own initiative after opening a PR; opening a PR
ends at the PR.

## Contract

- Merge only PRs this session owns or ones the user named.
- Conflicts and stale base are yours to fix: get the branch on latest main
  (rebase or merge, whichever is simpler — don't ask which), resolve conflicts,
  rerun the repo gate if code changed, push, continue.
- Stacks merge in order, base-most first. After each merge, retarget the next
  PR onto main (or its new base), rebase it, wait for its CI, then merge it.
- Release PRs (release-please and similar) and staging/prod deploy watching are
  explicit-ask only. Do not merge a release PR or babysit deploy workflows
  unless the user asked for that in this session.
- Use the repo's standard merge method (check repo settings or recent merge
  history); ask only if genuinely ambiguous.
- Leave the user's main checkout alone unless asked to update it.

## Workflow

1. Identify target: the current branch's PR, the named PR, or the stack.
2. Watch checks (`gh pr checks --watch`, background). Red CI: fix, push,
   re-watch until green.
3. Behind base or conflicted: sync with main per contract, push.
4. Merge; delete the remote branch if the merge didn't.
5. Stack: repeat 2-4 per child in order.
6. Only if explicitly asked: merge the release PR, watch staging/prod deploy
   workflows, report deployed versions.
7. Teardown: verify the session worktree is clean, remove it
   (`git worktree remove` / `jj workspace forget`), delete the local branch,
   prune.
8. Report: merged PR URLs + merge SHAs, CI state, what was cleaned up, and
   anything left (e.g. release PR untouched).
