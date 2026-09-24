# Ordinary jjpr stacks

Use this path for ordinary chained PRs on GitHub, GitLab, or Forgejo. Do not run
any `gh stack` command. Keep the explicit top bookmark, base, and Git remote on
every write-capable command.

## Submit and update

Verify the full range before publishing, then preview and submit:

```bash
jj status
jj log -r 'conflicts() & <base>..<top>'
jjpr submit <top> --base <base> --remote <remote> --dry-run
jjpr submit <top> --base <base> --remote <remote>
```

The preview must show the bottom PR targeting the intended base and each higher
PR targeting the bookmark immediately below it. Repeat this preview/live pair
after edits, restacks, or bookmark moves. `jjpr status <top>` is read-only and
useful when forge detection is unambiguous, but it has no remote selector in
0.39.1; do not use it as proof in a multi-remote repository.

Use `--draft`, `--ready`, `--reviewer`, and `--reviewer-scope` only as requested.
After every submit/restack, check each PR's title/body, exact head/base, and
complete commit list against the intended oldest-to-newest segment (`jj log -r
'<lower>..<upper>' --no-graph --reversed -T 'commit_id ++ "\n"'`; use the
bottom base for the first PR). Page forge commit lists; counts alone miss
misassignment.
Before landing, reshape with jj and let scoped submit update ordinary PR bases;
the manual landing exception below applies only after a lower PR merges.

## Land

Resolve the actual bottom base first: it may be repository trunk or an intended
coworker/foreign remote branch. Require the local base bookmark to track and
equal that selected remote base. Record every original reviewed PR head SHA and
tree, its complete commit segment (including the oldest commit), base, title,
reviews, and CI. Check the effective jjpr policy and merge/reconciliation config
(CLI, repo, global, built-in), the exact remote PR state, and native Stack
membership. Before **each** manual merge, enforce jjpr's effective
`required_approvals` and `require_ci_pass` even if forge branch protection is
weaker: require an open, non-draft, mergeable PR, no outstanding changes requests,
and enough current approvals and passing checks. On GitHub, use the paginated
latest-per-reviewer calculation in [Native Stack landing](native-land.md#enforce-policy-gates);
use equivalent forge checks elsewhere. After every write, verify remote
heads/bases/commit lists and reacquire gates before merging another PR. A
rewritten head may dismiss approvals.

**Multi-commit segments on jjpr 0.39.1/0.40.0:** never use `jjpr merge` or
`jjpr watch` with rebase reconciliation. Live private-repo E2E showed both
versions report a successful squash merge while omitting earlier commits in
surviving segments. Merge reconciliation avoids that specific tip-only rebase
but retains old ancestry and does not repair segment attribution; do not treat
it as a general fix. Do not convert already-reviewed ordinary PRs to a native
Stack without separately checking membership, review continuity, and authority.

For a **GitHub native Stack**, use [Native Stack landing](native-land.md) when
the PRs are registered members and the selected scope is authorized. A direct
whole-Stack merge avoids jjpr's intermediate reconciliation; queued merges are
not atomic whole-Stack completion. For **ordinary PRs**, land manually from the
bottom, using the repository's allowed merge method and the gates above. On
GitHub, for squash use `gh pr merge PR --repo
OWNER/REPO --squash --match-head-commit CURRENT_GATED_HEAD`. Read this SHA
fresh for each PR after any survivor rewrite; keep the original reviewed
SHA/tree separately for the content audit. That option guards the head, not the
base: recheck the base immediately before merging. Do not delete survivor branches.

After each lower merge, fetch the new base and rebase the **oldest commit of the
first surviving PR segment** onto it with `jj rebase -s OLDEST -d BASE`. This
moves the entire surviving subtree; rebasing the tip drops earlier commits.
Stop on conflicts. Push only the affected survivor bookmarks with `jj git push
-b NAME --remote REMOTE`; verify every remote head and segment against the
original snapshots. Retarget the first surviving GitHub PR with `gh pr edit
PR --repo OWNER/REPO --base BASE` (or the equivalent forge operation), preserving
its PR number and discussion. This direct base edit is a landing-only exception to
the submit rule above. Recheck the complete chain and gates before the next
merge. Stop rather than silently resubmitting or repairing an unexpected graph.

Finally verify the actual merged commit(s) are on the intended base and compare
the landed base tree to the **original reviewed top tree** when no independent
base changes intervened. Otherwise independently compose/review the expected
integration tree and compare against that. Rewritten local tips, change IDs,
PR counts, green CI, and `jjpr` success are not content proof.

Never bypass a native-membership refusal.

## Recover

On fetch, reconcile, or push failure, stop before the next merge. Inspect exact
local and remote state before any retry:

```bash
jj git fetch --remote <remote>
jj status
jj bookmark list --all-remotes
jj log -r '<base>..bookmarks()'
jj log -r 'conflicts() & <base>..<top>'
jjpr submit <top> --base <base> --remote <remote> --dry-run
```

Use `$jj` recovery. If a manual rebase is necessary, start at the oldest change
in the affected PR segment; rebasing only its tip can strand earlier commits.
Never blindly move a bookmark to its remote counterpart or discard divergence.
