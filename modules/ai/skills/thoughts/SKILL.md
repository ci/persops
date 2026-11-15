---
name: thoughts
description: "Investigate, verify, and report without making any changes — run local checks, then wait for a go/no-go. Use for /thoughts, 'investigate only', 'look but don't touch', 'report back first'."
---

# Thoughts

Read-only investigation mode. Look, verify, and check whatever is needed —
including running local commands and tests — then reply with a report. Make no
lasting changes and take no remote or write actions. The user decides afterward
whether to act.

Use when the user types `/thoughts <question/task>`, or asks to investigate,
look into, verify, or report on something without changing anything yet.

## Contract

Freely allowed (read + local verification):

- Read, search, and list files; inspect code, docs, tests, recent commits.
- Run read-only VCS: `git status/diff/log`, `jj status/diff/log`.
- Run builds, typecheck, lint, tests, the app, and ad-hoc queries to verify
  behavior locally.
- Read remote/service state read-only: `gh pr/issue/run view`, `gh ... diff`,
  read-only MCP/API queries (e.g. Grafana/GitHub reads).
- Write scratch notes to `/tmp`.

Never (stop and report instead):

- No commit, push, branch/bookmark publish, rebase, reset, restore, or stash on
  the user's working copy.
- No remote/GitHub writes: open/merge/close PRs or issues, comment, label,
  review, resolve threads.
- No external-service writes: Slack/email sends, dashboards, feature flags,
  experiments, scheduled tasks, cloud state.
- No MCP tool whose name implies a write (create/update/delete/send/trigger…).

## If you must change something to verify

Default to not editing — describe the change instead. Only apply one when you
genuinely need to run it to answer the question. Then, in order of preference:

1. Isolate it. Run `jj status` first. If it succeeds, use `$jj` and create
   `jj workspace add /tmp/thoughts-<slug> --name thoughts-<slug> -r @ -m
   'chore: isolate investigation'`; explicit `-r @` makes the temp `@` a child
   of the current tracked state. In plain Git, use `git worktree add
   /tmp/thoughts-<slug> HEAD`. Run and observe there. During teardown, discard
   only edits made in that temp checkout. For jj, verify the temp diff, capture
   its workspace name/root/change ID, forget it from a surviving workspace,
   abandon only the captured disposable change, and remove the exact directory.
   For Git, use `git worktree remove`. If anything is worth keeping, leave it
   and report the exact path.
2. Edit in place only if an isolated checkout doesn't apply (not a repo, or a
   trivial check) AND the working tree has no other pending changes to
   entangle. Keep it minimal and revert afterward, or clearly flag what's left.
3. Either way: local only. Never commit, push, or touch remote/external state,
   and report exactly what you changed.

## Workflow

1. Pin the question — from the user's text plus current repo, branch, recent
   discussion, and linked issue/PR. State scope in one line if ambiguous.
2. Investigate — read and run whatever read-only checks answer it. Prefer
   evidence (commands run, `file:line` refs) over assertion.
3. Report (shape below). Lead with the answer, not the journey.
4. Stop — offer concrete next actions and wait. Do not start acting on them.

## Report shape

Keep it tight; scale to the question.

- **Answer / TL;DR** — the conclusion in 1–3 lines.
- **Evidence** — what you checked: key files (`path:line`), commands run + what
  they showed. Enough to trust the answer, not a transcript.
- **Findings** — what's true, what's uncertain, risks/edge cases noticed.
- **Options** — candidate next actions, numbered, each with a one-line tradeoff
  and rough effort. Mark a recommendation if you have one.
- **No lasting changes made.** — state it, and note any temporary
  workspace/worktree/edit and its location.

End by inviting the user to pick an option or stop. Do not proceed without a
go-ahead.
