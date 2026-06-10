---
name: review-branch
description: "Read-only review of a branch or PR from origin in a temp worktree — investigate, triage review comments, report; no changes. Use for 'review this branch, no changes, lmk what you find'."
---

# Review Branch

Read-only review of a branch (and its PR, if one exists). Fetch, inspect in
isolation, form an opinion, report back. Never modify the branch, the working
copy, or anything remote — the user decides what happens next.

## Contract

- No commits, pushes, rebases, or edits to the user's checkout.
- No PR writes: no comments, reviews, labels, thread resolutions.
- `gh`/API reads, local builds, and tests are fine.

## Workflow

1. **Fetch & isolate.** `git fetch origin <branch>` (or jj equivalent). The
   user is often editing locally at the same time — don't disturb their
   checkout. Use a temp worktree by default:
   - `git worktree add /tmp/review-<slug> origin/<branch>`, or
   - `jj workspace add /tmp/review-<slug>` in jj repos.
   Review the diff against the merge-base with the default branch, commits as
   pushed — not whatever is currently in the user's working tree.
2. **Pull PR context.** If a PR exists for the branch (`gh pr list --head
   <branch>`), read it — description, review comments, CI status often carry
   intent the diff alone doesn't (`gh pr view`, `gh api` for comment bodies).
   Read-only; never post.
3. **Review the code.** Read the actual implementation, not just the diff
   hunks. Judge correctness, API shape, fit with surrounding patterns and
   sibling implementations. Run builds/tests in the worktree when they'd
   change the verdict. For depth, follow `$github-deep-review`.
4. **Triage existing comments.** For each unresolved review comment (bot or
   human), check it against the code as pushed and classify: real (with
   evidence), stale (already addressed — say where), or wrong (why).
5. **Report.** Verdict first, then findings with `file:line` refs, comment
   triage, and concrete suggestions ranked by importance. State clearly that
   no changes were made.
6. **Clean up.** Remove the temp worktree (`git worktree remove`) unless it
   holds something worth keeping — then report its path.

Stop after the report. Apply fixes or reply to comments only on explicit
go-ahead.
