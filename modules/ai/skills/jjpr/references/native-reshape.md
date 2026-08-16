# Native Stack reshape

Use this only after the user explicitly authorizes remote Stack
destruction/recreation and approves the intended final PR order and target
branches. Ordinary PR-update authority is insufficient.

The unstack API has no expected-membership or compare-and-swap guard. Obtain
exclusive remote-writer coordination for the Stack and its PR bases for the
whole transaction. If that cannot be guaranteed, stop and use manual
coordination. Authorization covers the complete Stack in the last fresh read;
any observed membership change requires renewed authorization.

Before the first remote write, require the approved final list to contain
1–100 PRs. A singleton's approved result is one ordinary unstacked PR. A list
of 2–100 becomes the replacement native Stack. Split a larger series into
separately authorized transactions before unstacking; do not discover an
invalid size after destruction.

## Journal the original state

Record:

- the relevant entries from `jj op log`;
- every stack change ID and bookmark target;
- the exact `OWNER/REPO`, jjpr Git remote name and URL, and Stack base bookmark;
- the Stack number, base, and complete ordered membership;
- every known asynchronous merge UUID and its terminal result;
- every PR number, head ref, head SHA, base ref, state, draft state, and Stack
  metadata.

Use the REST reads from the main skill. Check merge-queue and auto-merge state
for every member:

```bash
gh api graphql -F owner=OWNER -F repo=REPO -F number=PR_NUMBER \
  -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){state locked merged mergeQueueEntry{id} autoMergeRequest{enabledAt}}}}'
```

Stop unless every member is `OPEN`, unlocked, unmerged, unqueued, and without
auto-merge.

Those read-only fields do not expose an in-flight direct asynchronous merge;
GitHub's status endpoint requires the UUID returned to the merge initiator, and
probing with `PUT .../merge-async` could start a merge. Never use that write as
an eligibility check. Automated reshape may continue only when exclusive
remote-writer coordination has been held continuously since before any merge
request could have started and every journaled merge UUID is terminal. If that
history is unavailable, absence of an in-flight merge is unprovable: stop and
do not call `unstack` until an external coordinator establishes quiescence.

## Prepare locally

Reshape only with jj. Keep the work in its existing isolated workspace. Verify
the complete stack range, conflicts, bookmark targets, intended order, and
expected target branch for every PR. Do not submit while the old native Stack
exists. Preserve the original change IDs and bookmark targets for scoped local
recovery.

## Recheck and unstack

Immediately before unstacking, reread the complete Stack, every PR REST record,
and every eligibility GraphQL record. Require exact equality with the journaled
Stack number/base/order and every recorded head SHA, base, and membership.
Require the eligibility conditions to remain true. Any new member or head,
base, state, queue, lock, auto-merge, or Stack drift means stop for manual
coordination.

Only then run:

```bash
GH_REPO=OWNER/REPO gh stack unstack STACK_NUMBER
```

Reread the complete Stack and every original member. Stop unless unstacking was
complete and every member's `stack` field is null. Do not push or relink after a
partial unstack.

## Submit and relink

Recheck that the journaled remote still maps to the exact `OWNER/REPO`. Run the
fully scoped preview against the now-unstacked PRs:

```bash
jj git remote list
jjpr submit <top> --base <base> --remote <remote> --dry-run
```

Require the approved final base chain, repository, and bookmark heads, then run
the same command without `--dry-run`; do not re-infer any argument after
unstacking.

Resolve the approved retained PR numbers by exact head ref and SHA. For a
singleton, verify its approved base and head plus null Stack membership, then
skip `gh stack link`. For 2–100 PRs, re-run the main skill's all-unstacked
PR-number-only `gh stack link` path and verify the complete native projection.
Reread every removed original member and require its head, base, state, and null
membership to match the approved disposition; never close one implicitly.

## Failure recovery

After any remote failure, stop and reread complete Stack and PR state before
another write. Never assume a failed command was atomic.

Do not automatically roll back if any head, base, membership, or eligibility
field differs from the expected original or new state. Do not overwrite another
actor's push or mutate a different Stack.

Restore local state only by targeting the recorded stack change IDs and
bookmarks. `jj op restore` is repository-wide; use it only after proving no
intervening operation from any workspace and obtaining explicit approval.

Recreating the original remote Stack is a new remote write. Do it only with
explicit approval, after scoped local restoration, and only when every original
PR has the recorded head/base, is unstacked, and remains eligible. Otherwise
report the journal plus current partial state for manual recovery.
