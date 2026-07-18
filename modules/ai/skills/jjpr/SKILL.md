---
name: jjpr
description: "Manage stacked pull requests with jjpr in Jujutsu repositories."
---

# JJPR

Use with the `jj` skill. Let `jj` manage the local change graph; let `jjpr` map bookmarks to forge PRs. This workflow was validated against jjpr 0.34.1. Re-check installed help when the version changes.

## Guardrails

- Start with `jj status`, `jjpr --version`, and the relevant subcommand `--help`.
- Run `jjpr auth test` before the first remote operation in a repository.
- Treat `jjpr submit` as push/PR-write, `jjpr merge` as remote merge, and `jjpr watch` as a live remote mutation loop. Require matching user authorization.
- Preview with `jjpr submit --dry-run` or `jjpr merge --dry-run` before the first live operation or after a graph rewrite.
- Never use raw `git push` in a jj repository.
- On persops-managed machines, edit `modules/jjpr.nix` rather than the generated `~/.config/jjpr/config.toml`.

## Model the stack

- One bookmark equals one PR.
- Commits between bookmarks belong to the upper bookmark's PR. Multiple commits per PR are supported.
- The bottom PR targets trunk or an auto-detected foreign remote branch. Each higher PR targets the bookmark immediately below it.
- Bookmarks follow rewritten changes but do not advance when `jj new` creates a child. Move or create them explicitly at each PR tip.

Create a stack with one bookmark per review unit:

```bash
jj new 'trunk()' -m 'feat: add foundation'
# Make foundation changes.
jj bookmark create stack/01-foundation -r @

jj new -m 'feat: add service'
# Make service changes.
jj bookmark create stack/02-service -r @

jj new -m 'feat: add flow'
# Make flow changes.
jj bookmark create stack/03-flow -r @

jj new
```

Use `jj bookmark set <name> -r @` instead when advancing an existing bookmark. Inspect the finished graph:

```bash
jj log -r 'trunk()..bookmarks()'
jj status
```

## Workspaces

Use a `$jj` workspace when the stack must not disturb the primary checkout. Workspaces share the revision graph and bookmarks but have independent `@` commits. Use one workspace per independent stack or task, not one per PR:

```bash
jj workspace add ../ws-stack-auth --name stack-auth -r 'trunk()' -m 'feat: start auth stack'
```

Create and move the stack bookmarks from that workspace as usual. Keep passing the explicit top bookmark to jjpr: inference follows the current workspace's `@`, while the bookmarks and PRs are repository-wide. Forgetting a workspace does not remove its changes or bookmarks; use the `$jj` teardown checks before deleting its directory.

## Inspect and submit

Prefer the explicit top bookmark:

```bash
jjpr status stack/03-flow
jjpr submit stack/03-flow --dry-run
jjpr submit stack/03-flow
```

Bare inference only works when the working copy is at or below a bookmarked commit. The normal empty `@` above a finished stack does not match; pass the top bookmark.

`submit` is idempotent. Re-run it after edits, rebases, restacks, or bookmark movement to push bookmarks, create or update PRs, repair PR bases, and update stack navigation.

Reviewer behavior:

```bash
jjpr submit <top> --reviewer alice,bob
jjpr submit <top> --reviewer alice,bob --reviewer-scope all
jjpr submit <top> --draft
jjpr submit <top> --ready
```

- Reviewer scope defaults to `bottom`; alternatives are `leaf` and `all`.
- New PRs are ready unless `--draft` is supplied. When the active AGENTS policy
  defaults to draft PRs (for example the work machine), pass `--draft` on every
  first submit and promote with `--ready` only on user ask.
- Use `--base` only to override incorrect auto-detection, such as an unpushed foreign base.

Read status without changing the forge:

```bash
jjpr
jjpr status <top>
jjpr status --all
```

## Update reviewed stacks

Append review fixes when practical. Use this only when the current working copy is empty and its direct parent `@-` is bookmarked `<leaf>`; verify that relationship with `jj log -r '@-'` first:

```bash
jj describe -m 'fix: address review feedback'
# Make the fix in @.
jj bookmark set <leaf> -r @
jj new
jjpr submit <leaf> --dry-run
jjpr submit <leaf>
```

Appending to the leaf is a fast-forward. Amending, squashing, or otherwise rewriting a published change changes its commit ID. Rewriting a lower or middle change also makes jj rebase its descendants; those downstream bookmarks then require force-pushes on the next submit. `reconcile_strategy` does not control this local jj behavior.

After any rewrite, inspect the entire affected graph and diff before submitting:

```bash
jj status
jj log -r 'trunk()..bookmarks()'
jj diff -r <affected-change>
jjpr submit <top> --dry-run
```

## Land the stack

Use squash merge plus rebase reconciliation by default:

```bash
jjpr merge <top> --dry-run
jjpr merge <top>
```

For each PR from the bottom, jjpr verifies draft state, CI, approvals, requested changes, and conflicts; merges it; fetches the updated trunk; rebases the remaining unique changes; pushes their bookmarks; and retargets the next PR. Re-run after a blocker clears.

Keep these separate:

- `merge_method = "squash"` controls how the forge lands each PR.
- `reconcile_strategy = "rebase"` controls how jjpr syncs the remaining stack afterward.

After a squash merge creates a new trunk commit, rebase reconciliation removes the old lower-PR commits from downstream history and replays only their unique changes. Expect force-push events and potentially disrupted GitHub "changes since last review" views; prefer the clean graph for now.

Use merge reconciliation only when explicitly chosen:

```bash
jjpr merge <top> --reconcile-strategy merge
```

It keeps downstream pushes fast-forward by adding merge commits. The Changed Files view stays focused, but old lower-PR commits remain in GitHub's Commits view and branch history grows merge commits.

Do not bypass CI or approval requirements unless explicitly authorized. `--merge-method` changes landing style; it is not a reconciliation strategy.

## Watch

Use `watch` only when the user asks for ongoing lifecycle automation:

```bash
jjpr submit <top> --dry-run
jjpr watch <top> --timeout 60
```

Watch creates drafts, promotes them after CI, and merges approved PRs bottom-up. It polls every 30 seconds and is live; use Ctrl+C or `--timeout`. Do not rely on `--dry-run` with watch.

## Configure

Precedence: CLI flags, repo-local `.jj/jjpr.toml`, global config, built-in defaults. Repo-local config is per clone because it lives under `.jj/`.

```toml
merge_method = "squash"
required_approvals = 1
require_ci_pass = true
reconcile_strategy = "rebase"
stack_nav = "comment"
```

Supported choices:

- `merge_method`: `squash`, `merge`, `rebase`
- `reconcile_strategy`: `rebase`, `merge`
- `stack_nav`: `comment`, `description`
- repo-local `forge`: `github`, `gitlab`, `forgejo`
- repo-local `forge_token_env`: exact token environment-variable name

Authenticate through exact token variables or the forge CLI credential store. Never dump the environment to find credentials.

## Recover

On reconcile or push failure, stop before merging the next PR. Inspect before accepting either local or remote state:

```bash
jj git fetch --remote <remote>
jj status
jj bookmark list
jj log -r 'trunk()..bookmarks()'
jjpr status <top>
jjpr submit <top> --remote <remote> --dry-run
```

Use the same remote selected for the original submit or merge. Resolve conflicts or bookmark divergence with the `jj` skill, then re-run `jjpr submit <top> --remote <remote>`. Use the oldest change in the affected segment when a manual rebase is necessary; rebasing only the bookmark tip can strand earlier commits. Never blindly move a bookmark to its remote counterpart or discard local divergence.
