---
name: jjpr
description: "Manage stacked pull requests with jjpr in Jujutsu repositories."
---

# JJPR

Use with the `$jj` skill. Keep one authority per layer:

- `jj` owns changes, ancestry, bookmarks, workspaces, and recovery.
- `jjpr` owns ordinary GitHub, GitLab, and Forgejo PR submission and landing.
- For native GitHub Stacks only, `jjpr` creates or updates the PRs,
  `gh stack link` or the Stacks REST API registers them, and `gh stack merge`
  lands them.

Never use Git-local `gh stack init`, `add`, `modify`, `rebase`, `sync`, `push`,
or `submit` in a jj-owned repository.

The ordinary workflow is validated with jjpr 0.39.1. The native GitHub path is
additionally validated with gh 2.97.0, gh-stack 0.1.0, and API version
`2026-03-10`. If a selected tool version differs, stop before its first forge
write and revalidate that path.

## Guardrails

- Start with `jj status` and `jjpr --version`. For native GitHub work, also run
  `gh --version` and `gh stack --version`.
- Choose explicit `OWNER/REPO`, Stack base, and Git remote values. Never depend on
  repository inference from a `.git`-less jj workspace.
- Run `jjpr auth test` before the first forge operation. After selecting the
  native GitHub path, or before using GitHub REST to detect native membership,
  also run `gh auth status --active --hostname github.com`. Never use
  `--show-token`.
- Treat `jjpr submit` as push/PR-write, `gh stack link` and `unstack` as remote
  Stack writes, and `gh stack merge` as landing. Require matching authority.
- Never use raw `git push` in a jj repository.
- Use one jj workspace per independent stack, not one per PR. Workspaces share
  bookmarks, so one session owns a stack's bookmarks at a time.
- On persops-managed machines, edit `modules/jjpr.nix`; do not edit the
  generated jjpr config.
- `jjpr status` has no remote selector in 0.39.1. Treat it as an optional local
  hint only; explicit REST reads are authoritative for remote Stack state.

## Check the local stack

Use one bookmark per independently landable PR, ordered bottom to top. Commits
between bookmarks belong to the upper bookmark's PR. Bookmarks follow rewritten
changes but do not move to a newly created child; use `jj bookmark set` when
advancing one. Finish with an empty `@` above the top bookmark.

Before any submission, verify the whole range:

```bash
jj status
jj log -r '<base>..<top>'
jj log -r 'conflicts() & <base>..<top>'
jj bookmark list --all-remotes
```

Stop on conflicts, divergent bookmarks, an unexpected base, or extra changes
inside a PR segment.

For work intended to become a native Stack, declare and count the complete PR
list before the first forge write. Native Stacks contain 2–100 PRs. Keep a
singleton as an ordinary unstacked PR; split a larger series into separately
authorized Stacks before submitting anything.

## Choose the publication model

For ordinary chained PRs on GitHub, GitLab, or Forgejo, read and follow
[Ordinary jjpr stacks](references/ordinary-stacks.md) and do not run `gh stack`.
For an existing GitHub PR chain, use explicitly scoped REST reads to detect
native membership before choosing. Continue below only when the user wants a
new native GitHub Stack or the PRs are already native members.

## Native pre-submit gate

Before any live `jjpr submit` on the native path, obtain exclusive remote-writer
coordination for the desired PR heads and bases and any existing Stack. Hold it
through final projection verification. If that cannot be guaranteed, stop for
manual coordination.

Pass the top bookmark explicitly; a normal empty `@` above the stack is not a
reliable inference target. Preview the complete write:

```bash
jjpr submit <top> --base <base> --remote <remote> --dry-run
```

Require the intended repository, the bottom PR targeting the chosen base, and
every higher PR targeting the bookmark directly below it.

After the dry-run and before its live counterpart, resolve each existing open
PR by exact repository and head ref. Require zero or one result per bookmark;
an ambiguous result is a stop:

```bash
gh pr list --repo OWNER/REPO --state open --head '<bookmark>' --limit 100 \
  --json number,headRefName,headRefOid,baseRefName,state,isDraft,url
```

For every existing result, read both its PR record and landing state:

```bash
gh api 'repos/OWNER/REPO/pulls/PR_NUMBER' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  --jq '{number,head:.head.ref,head_sha:.head.sha,base:.base.ref,state,merged,locked,stack}'
gh api graphql -F owner=OWNER -F repo=REPO -F number=PR_NUMBER \
  -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){state merged mergeQueueEntry{id} autoMergeRequest{enabledAt}}}}'
```

Require the exact expected head ref, the recorded remote bookmark SHA, `OPEN`,
unmerged, unlocked, no merge-queue entry, and no auto-merge request. Any native
membership selects **Update a registered Stack**; the create path additionally
requires every existing PR to be unstacked. Stop before pushing on any drift or
ineligible PR.

## Create the PRs

Use this live-submit path only after the native pre-submit gate, for initial
creation or when every desired PR is proven unstacked. If any PR is a native
member, use **Update a registered Stack** instead.

```bash
jjpr submit <top> --base <base> --remote <remote>
```

Use `--draft` only when requested; otherwise submit ready for review. Optional
reviewer flags are:

```bash
jjpr submit <top> --base <base> --remote <remote> --reviewer alice,bob
jjpr submit <top> --base <base> --remote <remote> --reviewer alice,bob --reviewer-scope all
```

After submission, resolve each bookmark to exactly one open PR and record the
PR numbers bottom to top. Verify the head and base, not only the number:

```bash
gh pr view <bookmark> --repo OWNER/REPO \
  --json number,headRefName,headRefOid,baseRefName,state,isDraft,url
jj log -r '<bookmark>' --no-graph -T 'commit_id ++ "\n"'
```

Require `headRefOid == commit_id` for every bookmark before continuing.

Do not pass bookmark or branch names to `gh stack link`; PR-number-only linking
prevents another tool from pushing the branches.

## Preflight native Stack registration

`gh stack link` has no dry-run. It can attempt PR-base writes before rejecting
an invalid reorder, so read remote state and classify it before calling `link`.
Reconfirm that the complete desired list still contains 2–100 PRs.

The link API has no expected-membership or compare-and-swap guard. Keep the
exclusive remote-writer coordination acquired before live submission through
this read/write/verification sequence.

Read every desired PR using the preview API:

```bash
for pr in PR1 PR2 PR3; do
  gh api "repos/OWNER/REPO/pulls/$pr" \
    -H 'X-GitHub-Api-Version: 2026-03-10' \
    --jq '{number,head:.head.ref,head_sha:.head.sha,base:.base.ref,state,merged,draft,locked,auto_merge,stack}'
  gh api graphql -F owner=OWNER -F repo=REPO -F number="$pr" \
    -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){state merged mergeQueueEntry{id} autoMergeRequest{enabledAt}}}}'
done
```

Require every desired PR to remain open, unmerged, unlocked, unqueued, and
without auto-merge. Draft state may differ only when the authorized
`jjpr submit` changed it. Immediately before `link` or the REST add, repeat the
PR and complete-Stack reads and require the recorded heads, bases, membership,
order, eligibility, and intended classification to be unchanged.

If a PR reports Stack membership, read that complete Stack:

```bash
gh api 'repos/OWNER/REPO/stacks/STACK_NUMBER' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  --jq '{number,base:.base.ref,pull_requests:[.pull_requests[] | {number,head:.head.ref,state}]}'
```

Permit exactly one case:

1. **All unstacked:** create a Stack from the complete desired order.
2. **Exact match:** do nothing; skip `link`.
3. **Top append:** current ordered membership is a strict prefix of the desired
   order and every appended PR is unstacked; append only those PRs.
4. **Anything else:** stop. Do not call `link`; insertion, reorder, removal,
   mixed Stack membership, or a base mismatch needs an explicit reshape.

For a new Stack, pass every PR bottom to top:

```bash
GH_REPO=OWNER/REPO gh stack link --base BASE PR1 PR2 PR3
```

For a clean top append, bypass gh-stack 0.1.0's unpaginated Stack-number lookup
and call the already-preflighted official add endpoint with only the new top
PRs:

```bash
gh api --method POST 'repos/OWNER/REPO/stacks/STACK_NUMBER/add' \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  -F 'pull_requests[]=PR3' -F 'pull_requests[]=PR4'
```

Let jjpr own draft/ready state; do not pass `--open` to `link`. Never retry a
failed link blindly: reread membership and every PR base first because an
earlier write may have succeeded.

## Verify the projection

Read the Stack again and prove all of these:

- the ordered PR numbers equal the desired bottom-to-top list;
- the Stack base equals the intended base;
- the bottom PR targets that base;
- each higher PR targets the preceding PR's head branch;
- every PR head still matches its jjpr-pushed bookmark;
- explicitly scoped REST reads report the expected Stack number and positions.

Fail closed on any partial or inconsistent result. Do not make `jjpr status`
part of this gate; it cannot select the submitted Git remote.

## Update a registered Stack

After REST confirms the current membership and exact base chain, rewrite or
append changes with jj and range-check:

```bash
jj status
jj log -r 'conflicts() & <base>..<top>'
```

Repeat **Native pre-submit gate**. Run the live update only if the dry-run
preserves every native member's target branch. A lower head commit changing is
a content update; a member targeting a different branch is a shape change.

```bash
jjpr submit <top> --base <base> --remote <remote>
```

Resolve every desired PR number, head ref, and head SHA again, then repeat
**Preflight native Stack registration** and **Verify the projection**. A new top
PR remains unstacked until the top-append REST add succeeds. Do not call an
update complete merely because `jjpr submit` succeeded.

An unchanged PR chain can be updated normally. jjpr 0.39.1 refuses before
pushing when the local graph would require retargeting a native member. Treat
that refusal as a shape conflict; do not bypass it with `gh pr edit` or a raw
base update.

GitHub supports only exact reuse and top append in place. Insertion, reorder,
removal, or a member target-branch change requires separate authorization to
recreate the remote Stack. “Update the PRs” is not reshape authorization. After
the user approves a stated final PR order and target-branch chain, read and
follow [Native Stack reshape](references/native-reshape.md). It journals local
and remote state, checks for concurrent drift immediately before unstacking,
and fails closed on partial writes.

## Land a native Stack

Never use `jjpr merge` or `jjpr watch` for native members; jjpr 0.39.1 refuses
them intentionally. Native landing has separate policy, scope, asynchronous
settlement, and JJ reconciliation requirements. Resolve the intended landing
scope, then read and follow [Native Stack landing](references/native-land.md)
in full. It handles approval/CI parity with jjpr, merge-method selection,
partial-merge number ambiguity, survivor restacking, and final verification.
