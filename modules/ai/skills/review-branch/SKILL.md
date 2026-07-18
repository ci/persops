---
name: review-branch
description: "Read-only review of a branch or PR from origin in an isolated workspace or worktree — investigate, triage review comments, report; no changes."
---

# Review Branch

Read-only review of a branch (and its PR, if one exists). Fetch, inspect in
isolation, form an opinion, report back. Never modify the branch, the working
copy, or anything remote — the user decides what happens next.

## Contract

- No product commits, pushes, rebases, or edits to the user's checkout. Only
  disposable isolation metadata and its verified empty working-copy change may
  be created and removed.
- No PR writes: no comments, reviews, labels, thread resolutions.
- `gh`/API reads, local builds, and tests are fine.

## Workflow

1. **Fetch & isolate.** Run `jj status` first. The user is often editing
   locally at the same time, so don't disturb their checkout:
   - jj: use `$jj`, fetch with `jj git fetch --remote origin`, then create
     `jj workspace add /tmp/review-<slug> --name review-<slug> -r
     '<branch>@origin' -m 'chore: isolate branch review'`. Always pass `-r`;
     omitting it creates `@` beside the current working copy rather than on the
     pushed branch.
   - plain Git: `git fetch origin <branch>`, then `git worktree add
     /tmp/review-<slug> origin/<branch>`.
   Review the diff against the merge-base with the default branch, commits as
   pushed — not the new empty workspace `@` or whatever is currently in the
   user's primary working tree.
2. **Pull PR context.** If a PR exists for the branch (`gh pr list --head
   <branch>`), read it — description, review comments, CI status often carry
   intent the diff alone doesn't (`gh pr view`, `gh api` for comment bodies).
   Read-only; never post.
   For a jjpr stack, use `$jjpr` only for read-only `jjpr status <top>` context;
   never submit, merge, or watch.
3. **Review the code.** Read the actual implementation, not just the diff
   hunks. Judge correctness, API shape, fit with surrounding patterns and
   sibling implementations. Run builds/tests in the isolated checkout when
   they'd change the verdict. For depth, follow `$github-deep-review`.
4. **Triage existing comments.** For each unresolved review comment (bot or
   human), check it against the code as pushed and classify: real (with
   evidence), stale (already addressed — say where), or wrong (why).
5. **Report.** Verdict first, then findings with `file:line` refs, comment
   triage, and concrete suggestions ranked by importance. State clearly that
   no changes were made.
6. **Clean up.** In jj, capture the temp workspace's name, root, and change ID;
   verify its diff is empty; forget it from a surviving workspace; abandon only
   that captured disposable empty change; then remove the exact directory. In
   plain Git, remove the temp worktree. If anything is worth keeping, do not
   remove it; report its exact path.

Stop after the report. Apply fixes or reply to comments only on explicit
go-ahead.
