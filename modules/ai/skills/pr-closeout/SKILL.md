---
name: pr-closeout
description: "Close out a branch or PR with clean commit boundaries, autoreview loops, focused fixes, validation gates, and stacked-PR support."
---

# PR Closeout

Use when the user asks to finish, polish, close out, prepare, or PR a branch;
handle review items; run autoreview in a loop; or get a change ready for review.

This skill is about turning working code into a reviewable branch. Use
`$autoreview` for the structured review helper itself.

## Contract

- Preserve reviewable commit boundaries. Do not squash or amend unless asked.
- Review the initial work before making one coherent commit. Keep private
  review iterations in that pending change; make later fixes to an already
  committed or shared change as new focused commits so the user can track them.
- Open or update remote PRs only when the user asked for that outcome; the
  draft/non-draft state follows the global AGENTS.md preference unless the
  user says otherwise.
- Close out where the work already lives — per the global start-in-isolation
  default that is usually a `$jj` workspace or Git worktree. Create a new
  isolated checkout only when the user asks, the current checkout has unrelated
  changes, or the primary checkout must stay untouched; jj workspaces go
  outside the current workspace tree, Git worktrees are for plain Git repos.
- Push only when the user asked to push, open/update a PR, fix CI, or otherwise
  gave clear remote-write consent.

## Workflow

1. Inspect state:
   - run `jj status` first; use `jj` if it succeeds, otherwise git
   - identify branch, base, existing PR, dirty files, and unrelated changes
   - note which checkout holds the work; create a new workspace/worktree only
     per the contract, and then do all closeout work there
   - read repo docs and PR/CI guidance relevant to the touched surface
2. Establish commit shape:
   - identify a coherent initial change or a focused follow-up to an existing commit
   - review and validate each pending change before creating its conventional commit
   - do not hide generated-artifact or test updates inside unrelated commits
3. Review loop:
   - run focused tests or typechecks for the touched surface
   - run `$autoreview` against the right target: local dirty patch, commit, or
     branch vs PR base
   - verify every accepted/actionable finding by reading the real code path
   - fix true findings, rerun focused validation, then rerun autoreview on the updated change
   - stop when autoreview reports no accepted/actionable findings; commit after
     the required validation gate passes, reusing the clean review while code is unchanged
4. Generated and contract surfaces:
   - if serializers, schemas, APIs, SDK payloads, or tools changed, check
     downstream generated clients, snapshots, docs, and consumers
   - regenerate only the surfaces required by the repo's established commands
5. PR handling:
   - if no PR exists and the user wants one, open a PR (draft state per the
     global preference or the user's ask)
   - if a PR exists, simplify the body to problem, changes, and tests when the
     user asks for cleanup
   - write PR bodies through a temp file and `--body-file`; inspect before
     sending
6. Final gate:
   - run the requested or repo-standard closeout gate
   - report commits, tests, autoreview result, PR URL/state, the isolated
     checkout's path (it stays for `$land` teardown), and any residual risk

## Stacked PRs

For phased or multi-part work when the user asks for stacked PRs:

- In a jj repo, use `$jjpr`: one bookmark per PR and one workspace per
  independent stack, not per PR. Preview and submit the explicit top bookmark.
- In a plain Git repo, use one branch per phase, stacked on the previous.
- Keep each PR small: target under 500 changed lines, avoid exceeding ~1k —
  split further instead.
- Run the full closeout loop (gate + autoreview) per phase before opening its
  PR.
- Follow `$jjpr`'s ordinary or native path for submission and landing. Verify
  every PR's title, head/base, and complete commit segment after submit or
  restack. Do not rely on jjpr rebase reconciliation for multi-commit segments
  on 0.39.1/0.40.0; preserve original reviewed SHAs/trees for landing proof.
- In plain Git, phase N bases on phase N-1; after a parent merges, retarget and
  rebase the child as needed.
- Between phases, report what's next with a go/no-go recommendation and wait
  for the user's signal, unless they pre-approved all phases up front.

## Output

Keep it short:

- Commits created.
- Review/fix loop result.
- Validation run and result.
- PR state: draft/open/updated/not opened.
- Remaining risks or skipped gates.
