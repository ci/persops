# Native Stack landing

Use only with explicit landing authority. Never use `jjpr merge`, `jjpr watch`,
`gh pr merge`, or auto-merge for native members.

## Resolve scope and local state

Resolve the intended landing PR numbers first. One `gh stack merge` invocation
may cover exactly one native Stack's complete open membership or one explicit
bottom prefix through the selected PR. If the local jj chain contains unstacked
PRs or members of another Stack, partition them into separately authorized
landing scopes; never report or tear down the whole chain after merging only
one native Stack.

gh-stack 0.1.0 does not send an expected-head SHA with its merge request.
Obtain exclusive remote-writer coordination for Stack membership and every
member ref, and hold it from the initial snapshot through remote settlement.
If that cannot be guaranteed, stop; a point-in-time policy check cannot protect
against an intervening push.

Require `@` to be empty directly above the top bookmark, every member bookmark
to equal its published PR head, and this query to return no non-empty
unpublished descendant or side branch:

```bash
jj status
jj log -r '((<stack-base>..<top>):: & ~::<top>) & ~empty()'
```

Record the result, exact `@` commit ID, and every member change and commit ID
before GitHub can rewrite survivors. Stop if the query finds work; move,
publish, or otherwise resolve it before landing.

## Enforce policy gates

Resolve effective jjpr config before merging. Repo-local `.jj/jjpr.toml`
overrides global config; built-in defaults are one approval and CI required.
For every PR in the selected prefix, reproduce jjpr's review calculation: page
through all reviews and keep each reviewer's latest meaningful state.

```bash
set -o pipefail
for pr in PR1 PR2; do
  gh api --paginate "repos/OWNER/REPO/pulls/$pr/reviews?per_page=100" |
    jq -s 'add
      | reduce .[] as $review ({};
          ($review.user.login // "") as $login
          | ($review.state // "") as $state
          | if ($login != "" and
                ($state == "APPROVED" or
                 $state == "CHANGES_REQUESTED" or
                 $state == "DISMISSED"))
            then .[$login] = $state else . end)
      | {approvals: ([to_entries[] | select(.value == "APPROVED")] | length),
         changes_requested: any(.[]; . == "CHANGES_REQUESTED")}' || exit 1
done
```

Require no outstanding changes request and at least `required_approvals` for
every selected PR. Any API/pagination/parse failure blocks. When
`require_ci_pass` is true, require `gh pr checks` to pass for every selected PR,
not only the top. Also require every member open, non-draft, and mergeable.
Immediately before `gh stack merge`, repeat the complete membership, head SHA,
review, CI, draft, and mergeability reads and require exact equality with the
gated snapshot.

## Merge the authorized scope

For a direct merge, resolve the allowed repository-standard `merge`, `squash`,
or `rebase` method using `$land`; never hard-code it. If the base uses a merge
queue, omit the method because the queue owns it.

```bash
gh api repos/OWNER/REPO \
  --jq '{allow_merge_commit,allow_squash_merge,allow_rebase_merge}'
# Whole Stack only with whole-Stack authorization:
GH_REPO=OWNER/REPO gh stack merge STACK_NUMBER --yes --merge-method MERGE_METHOD
# Partial Stack through one explicitly authorized PR:
GH_REPO=OWNER/REPO gh stack merge SELECTED_PR_NUMBER --yes --merge-method MERGE_METHOD
```

gh-stack 0.1.0 treats a bare number as a Stack number before trying it as a PR.
Before a partial merge, require the selected number to resolve to the intended
member PR and require `GET /repos/OWNER/REPO/stacks/SELECTED_PR_NUMBER` to
return 404. If that number is also a Stack, stop: headless selection is
ambiguous.

A queue submission is not a completed landing. Poll until every selected and
lower PR has REST `.merged == true` or report the queue/failure state without
cleanup. If a grouped merge reports failure, assume lower PRs may have landed
until remote state proves otherwise. Do not trust one `merge_commit_sha` field.

## Settle a partial merge

GitHub asynchronously retargets survivors and attempts a cascading rebase.
Poll the complete Stack and every survivor every 5 seconds for at most 5
minutes. Require the selected/lower PRs merged, the bottom survivor targeting
the Stack base, and each higher survivor targeting the preceding survivor's
head. Then require the complete number/base/head-SHA/membership snapshot to be
identical on two consecutive polls.

On timeout or queue failure, stop with observed remote state. Once bases settle,
classify survivors bottom-to-top as a contiguous server-rebased prefix whose
heads changed followed by an unchanged suffix. A changed head above an
unchanged one is inconsistent; stop. Reread immediately before any later push.

```bash
jj git fetch --remote REMOTE
jj log -r '<stack-base> | <stack-base>@<remote>'
jj log -r 'conflicts() & <stack-base>..<surviving-top>'
```

For each server-rebased prefix member, require the REST SHA to equal both its
`<bookmark>@REMOTE` and local bookmark. jj may retain its old same-change-ID
revision under the unchanged suffix or recorded empty working-copy change.

If an unchanged suffix exists, rebase the oldest commit in its first PR segment
onto the fetched Stack base, or the new preceding survivor bookmark when a
server-rebased prefix exists. This moves the complete suffix and empty `@` as a
subtree. Stop on conflicts. If all survivors were server-rebased, rebase only
the exact recorded empty working-copy commit onto the new top.

```bash
jj workspace list
jj rebase -s FIRST_UNCHANGED_SEGMENT_COMMIT_ID -d DESTINATION
# Or, when every survivor changed:
jj rebase -r RECORDED_EMPTY_COMMIT_ID -d <surviving-top>
```

After the subtree moves, verify every old server-rebased prefix commit has no
bookmark or workspace and no descendants outside that exact stale prefix. Then
abandon only the exact old commit IDs:

```bash
jj abandon OLD_PREFIX_COMMIT_ID...
```

Never abandon by change ID or broad revset. On unpublished content, an
unexpected descendant/bookmark/workspace, or a different divergence, stop and
use `$jj` recovery.

For a clean locally rebased suffix, preview and push through jjpr; never push an
old head back:

```bash
jj log -r 'conflicts() & STACK_BASE..<surviving-top>'
jjpr submit <surviving-top> --base <stack-base> --remote <remote> --dry-run
jjpr submit <surviving-top> --base <stack-base> --remote <remote>
```

Report approvals dismissed by a rewrite; survivors must reacquire gates before
a later landing. Recheck conflicts, recorded change-ID divergence, local/remote
bookmark equality, and native REST projection before cleanup. `jj undo` cannot
undo remote PR, Stack, or merge writes.
