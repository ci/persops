---
name: jjpr
description: "Manage stacked pull requests with jjpr in Jujutsu repositories."
---

# JJPR

Use with the `$jj` skill. One authority per layer:

- `jj` owns changes, ancestry, bookmarks, workspaces, and recovery.
- `jjpr` pushes bookmarks, creates/updates PRs, and lands ordinary stacks.
- Native GitHub Stacks are optional. `gh stack link` registers jjpr's PRs and
  `gh stack merge` lands them; see [Native GitHub Stacks](references/native-stacks.md).

Validated live on jjpr 0.45.1, jj 0.45.1, gh 2.102.0, gh-stack 0.1.1.

**Always land with `--reconcile-strategy merge`.** The rebase strategy rebases
a surviving PR from its tip and drops every earlier commit in a multi-commit
segment while reporting success (reproduced on 0.39.1 and 0.45.1). Pass the
flag explicitly: a repo-local `.jj/jjpr.toml` can override the global config.

## Guardrails

- Start with `jj status` and `jjpr --version`; run `jjpr auth test` before the
  first forge write.
- Pass the top bookmark, `--base`, and `--remote` explicitly on every write.
  An empty `@` above the stack is not a reliable inference target.
- Never raw `git push`. Never use Git-local `gh stack init`, `add`, `modify`,
  `rebase`, `sync`, `push`, or `submit` in a jj repo.
- One jj workspace per independent stack, not per PR. Workspaces share
  bookmarks, so one session owns a stack's bookmarks at a time.
- On persops-managed machines, change jjpr config in `modules/jjpr.nix`.

## Shape the stack

One bookmark per independently landable PR, ordered bottom to top. Commits
between bookmarks belong to the upper bookmark's PR. Bookmarks follow rewritten
changes but not new children; use `jj bookmark set` to advance one. Finish with
an empty `@` above the top bookmark.

```bash
jj log -r '<base>..<top>'
jj log -r 'conflicts() & <base>..<top>'
```

Stop on conflicts, divergent bookmarks, an unexpected base, or stray changes
inside a segment.

## Submit and update

```bash
jjpr submit <top> --base <base> --remote <remote> --dry-run
jjpr submit <top> --base <base> --remote <remote>
```

The preview must show the bottom PR targeting `<base>` and each higher PR
targeting the bookmark below it. Submit ready for review unless asked;
`--draft`, `--reviewer alice,bob`, and `--reviewer-scope all` only on request.

After every submit, check each PR's commits against its jj segment:

```bash
gh api --paginate 'repos/OWNER/REPO/pulls/PR/commits?per_page=100' --jq '.[].sha'
jj log -r '<lower>..<upper>' --no-graph --reversed -T 'commit_id ++ "\n"'
```

Use `<base>` as `<lower>` for the bottom PR. Fix a wrong title/body with
`gh pr edit`. Wrong commit membership is a stop, not a metadata fix.

To update, rewrite with jj (`jj squash --into`, `jj edit`, `jj rebase -s`),
recheck conflicts, and repeat the dry-run/live pair. Reviewers see a force push.

## Land an ordinary stack

```bash
jjpr merge <top> --base <base> --remote <remote> --reconcile-strategy merge --dry-run
jjpr merge <top> --base <base> --remote <remote> --reconcile-strategy merge
```

jjpr merges from the bottom, fetches, merges the new base into the survivors,
pushes, retargets, and repeats. It enforces the configured approvals, CI, draft,
changes-requested, and conflict gates; re-run it after a gate clears. Override
gates only when the user asks.

Then verify content, not just merged flags:

```bash
jj git fetch --remote <remote>
jj diff --from <original-top-commit> --to '<base>@<remote>' --stat
```

The diff must be empty when the base had no independent changes; otherwise
review what differs. After landing, `jjpr status` may list merged bookmarks
as "no PR yet, run jjpr submit". Don't resubmit them; confirm with
`gh pr list --repo OWNER/REPO --state merged --head <bookmark>` and delete the
local bookmark.

## Recover

- `jjpr undo --dry-run` previews undoing the last jjpr command: it restores the
  jj operation and force-pushes bookmarks back. `--force` also closes PRs it
  opened and overwrites what others changed since; use it only when asked. `jjpr redo` reverses an undo.
- Otherwise use `$jj` recovery with `jj op log`. A manual restack starts at the
  oldest change of the segment (`jj rebase -s OLDEST -d BASE`); rebasing a tip
  strands earlier commits.
- Never blindly move a bookmark to its remote counterpart or discard
  divergence.
