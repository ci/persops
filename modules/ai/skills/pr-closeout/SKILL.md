---
name: pr-closeout
description: "Close out a branch or PR with clean commit boundaries, autoreview loops, focused fixes, validation gates, and a draft PR when appropriate."
---

# PR Closeout

Use when the user asks to finish, polish, close out, prepare, or PR a branch;
handle review items; run autoreview in a loop; or get a change ready for review.

This skill is about turning working code into a reviewable branch. Use
`$autoreview` for the structured review helper itself.

## Contract

- Preserve reviewable commit boundaries. Do not squash or amend unless asked.
- Make follow-up fixes as new focused commits so the user can track the loop.
- Open or update remote PRs only when the user asked for that outcome; default
  to draft when opening a PR.
- Use a worktree only when the user asks, the current checkout has unrelated
  changes, or the main checkout must stay untouched.
- Push only when the user asked to push, open/update a PR, fix CI, or otherwise
  gave clear remote-write consent.

## Workflow

1. Inspect state:
   - run `jj status` first; use `jj` if it succeeds, otherwise git
   - identify branch, base, existing PR, dirty files, and unrelated changes
   - read repo docs and PR/CI guidance relevant to the touched surface
2. Establish commit shape:
   - if work is dirty but coherent, suggest or create a commit before review
   - keep review fixes in separate conventional commits
   - do not hide generated-artifact or test updates inside unrelated commits
3. Review loop:
   - run focused tests or typechecks for the touched surface
   - run `$autoreview` against the right target: local dirty patch, commit, or
     branch vs PR base
   - verify every accepted/actionable finding by reading the real code path
   - fix true findings, rerun focused validation, commit, then rerun autoreview
   - stop when autoreview reports no accepted/actionable findings
4. Generated and contract surfaces:
   - if serializers, schemas, APIs, SDK payloads, or tools changed, check
     downstream generated clients, snapshots, docs, and consumers
   - regenerate only the surfaces required by the repo's established commands
5. PR handling:
   - if no PR exists and the user wants one, open a draft PR
   - if a PR exists, simplify the body to problem, changes, and tests when the
     user asks for cleanup
   - write PR bodies through a temp file and `--body-file`; inspect before
     sending
6. Final gate:
   - run the requested or repo-standard closeout gate
   - report commits, tests, autoreview result, PR URL/state, and any residual
     risk

## Output

Keep it short:

- Commits created.
- Review/fix loop result.
- Validation run and result.
- PR state: draft/open/updated/not opened.
- Remaining risks or skipped gates.
