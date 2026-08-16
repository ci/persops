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
Never repair a base with raw Git or direct forge edits; reshape with jj, inspect
the graph, and let the next scoped submit update ordinary PR bases.

## Land

Resolve the actual bottom base first: it may be repository trunk or an intended
coworker/foreign remote branch. Require the local base bookmark to track and
equal that selected remote base. Preview the exact stack and use jjpr for the
whole ordinary lifecycle:

```bash
jj log -r '<base> | <base>@<remote>'
jjpr merge <top> --base <base> --remote <remote> --dry-run
jjpr merge <top> --base <base> --remote <remote>
```

jjpr checks draft state, CI, approvals, requested changes, conflicts, and native
GitHub membership before each merge. It lands bottom-up, fetches the base,
reconciles and pushes survivors, and retargets the next ordinary PR. Re-run only
after a reported blocker clears. Never bypass a native-membership refusal; use
the main skill's native landing path.

Merge method and reconciliation are separate: `merge_method` controls forge
history; `reconcile_strategy` controls survivor sync (`rebase` or `merge`). Read
effective config before landing. Precedence is CLI, repo-local
`.jj/jjpr.toml`, global config, then built-in defaults. On persops-managed
machines, edit `modules/jjpr.nix`, not generated config.

## Watch and recover

`jjpr watch` is a live remote mutation loop with no useful dry-run. Use it only
when explicitly requested, with an explicit bookmark, base, remote, and bounded
timeout:

```bash
jjpr watch <top> --base <base> --remote <remote> --timeout MINUTES
```

On fetch, reconcile, or push failure, stop before the next merge. Inspect exact
local and remote state:

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
