# GitHub stacked pull requests public preview

Research date: 2026-08-01. Primary-source investigation plus live end-to-end validation for a future `jjpr` integration. The `jjpr` skill remains unchanged; persops now manages the validated CLI baseline.

## Executive result

The intended integration is supported directly by GitHub: keep Jujutsu and `jjpr` authoritative for changes, workspaces, bookmarks, rebases, pushes, and PR creation; use `gh stack link` only to project the already-created PRs into GitHub's native Stack object. GitHub explicitly documents `link` for Jujutsu and says it does not create local gh-stack state. Passing PR numbers instead of branch names also prevents gh-stack from pushing branches. ([Using other tools, including Jujutsu](https://docs.github.com/en/pull-requests/reference/use-other-tools-with-stacked-pull-requests), [`link` implementation at v0.1.0](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go))

Recommended boundary:

```text
jj / jjpr                         GitHub Stacks
------------------------------    ---------------------------------
changes and workspace graph       native stack map in PR UI
bookmarks and restacks            ultimate-base protections/checks
push safety and PR creation       remote membership and position
local conflict handling           contiguous bottom-up merge
post-merge fetch/reconciliation   REST/GraphQL/webhook metadata
```

Do not mix `gh stack init/add/checkout/rebase/sync/push/modify` into the jj workflow. Those commands own Git branches, raw-Git rebases/force-pushes, worktrees, and `.git/gh-stack`; they duplicate or conflict with jj's responsibilities. `gh stack link`, remote APIs, and optionally `gh stack merge --yes` are the useful compatibility surface.

## Preview and machine setup

- GitHub announced public preview on 2026-07-30. It is rolling out to **all repositories over several days**, so a repository can still return feature-unavailable/404 during rollout. Merge-queue integration has a separate progressive rollout over the following weeks. ([Announcement](https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/))
- Install: `gh extension install github/gh-stack`; update: `gh extension upgrade stack`. The current extension release is `v0.1.0` (2026-07-29), which added `gh stack merge` and fixed stale-trunk and amended-parent rebase bugs. ([v0.1.0 release](https://github.com/github/gh-stack/releases/tag/v0.1.0))
- Initial machine state was `gh 2.93.0` plus a manually installed `github/gh-stack v0.1.0`. Persops now sources both `gh 2.97.0` and `gh-stack 0.1.0` from `nixpkgs-master` and registers the latter as a pinned GitHub CLI extension. The `gh` upgrade matters because 2.97.0 fixes four security issues, including terminal escape injection affecting `gh skills preview`; GitHub says to update immediately. ([gh 2.97.0 release](https://github.com/cli/cli/releases/tag/v2.97.0))
- The extension documents a low baseline (`gh >= 2.0`), but agent-skill tutorials use `gh >= 2.90`. For persops, set the practical baseline to `gh >= 2.97.0`, both for the skill command and the security fixes. ([CLI reference](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands), [gh 2.90.0 release](https://github.com/cli/cli/releases/tag/v2.90.0))
- If a repository is not enabled yet, gh-stack's documented exit code is `9`. Other extension exit codes: `0` success, `1` generic, `2` not in a stack, `3` rebase conflict, `4` API failure, `5` invalid arguments, `6` ambiguous branch membership, `7` rebase already in progress, `8` locked, and `10` modify recovery. ([Official gh-stack agent skill](https://github.com/github/gh-stack/blob/v0.1.0/skills/gh-stack/SKILL.md))

## What GitHub means by a Stack

A Stack is an explicit GitHub object containing 2–100 ordinary pull requests in one repository. It is a strict line, ordered bottom to top:

```text
PR 3: feature-c -> feature-b
PR 2: feature-b -> feature-a
PR 1: feature-a -> main
```

The bottom PR targets trunk; every higher PR targets the branch immediately below. Each PR shows only its layer's diff and is independently reviewable. Fork-based/cross-repository stacks, tree-shaped stacks, and GitHub Desktop are unsupported. The website, CLI, GitHub Mobile, REST, GraphQL, webhooks, and coding-agent skill are supported. ([About stacked pull requests](https://docs.github.com/en/pull-requests/get-started/about-stacked-prs))

A conventional chain of PR base branches is not yet the native Stack object. GitHub can detect it and show a recommendation banner, but the user or tooling must confirm it through UI, `gh stack submit`, `gh stack link`, or REST. The native object supplies the stack map, stack position/size metadata, native merge semantics, and GitHub's final-base evaluation. ([Creating stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-stacked-pull-requests))

### Rules, review, and CI

GitHub evaluates every layer against the Stack's **ultimate base**, not only its direct PR base. Required checks, required reviews, CODEOWNERS, code scanning, and branch-targeted `pull_request` workflows therefore apply to every PR as if it targeted trunk. This fixes a major weakness of plain branch-to-branch PR chains, but it can multiply CI usage by the stack size. GitHub exposes stack position and size so expensive jobs can be limited to the lowest unmerged PR or the top PR. Standalone PRs have `stack: null`, which CI conditions must handle. ([Optimizing CI](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/optimizing-ci-for-stacked-pull-requests), [REST reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/rest-api.md))

Webhook ordering matters: `pull_request.opened` cannot contain Stack metadata because PR creation happens before linking. Consumers should listen for the new `pull_request` action `stacked`; later lifecycle payloads include `pull_request.stack`. ([Webhook reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/webhooks.md))

### Merge semantics

- Selecting the top PR merges the whole stack; selecting a middle PR merges that PR plus every unmerged PR below it, bottom-up. Selecting the bottom merges only it.
- Remaining PRs above a partial merge are automatically retargeted/rebased; the new bottom targets trunk.
- Merge commit, squash, and rebase methods are supported. With squash, each PR becomes one commit. With merge commit, the group gets one merge commit while preserving its commits.
- Auto-merge is unsupported. Admin/ruleset bypass is unsupported for stack merge.
- A closed middle PR blocks everything above. It must be reopened or the open portion unstacked/recreated.
- A fully merged Stack is historical and cannot be extended; new PRs form a new Stack.
- Server-side “Rebase stack” force-pushes affected branches, reruns CI, and produces unsigned commits. Local `gh stack rebase` honors Git signing, but it is still raw Git and should not be used to restack jj history.

([Merging stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/merging-stacked-pull-requests), [Managing stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests))

Merge queues enqueue the selected contiguous group together and process dependencies bottom-up. GitHub may split a large Stack across consecutive queue groups while retaining order; if a lower PR is ejected, its descendants are ejected too. Public-preview merge-queue support is still in its own staged rollout. ([Merging stacked pull requests](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/merging-stacked-pull-requests), [public-preview announcement](https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/))

`gh pr merge` and the legacy synchronous PR merge endpoint are not the native stack-merge path. Use `gh stack merge` or the asynchronous merge REST endpoint. The API returns an operation UUID to poll; a result is retained for 24 hours and ends as `merged`, `enqueued`, or `failed`. ([Stack merge CLI](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands#gh-stack-merge), [asynchronous merge API](https://docs.github.com/en/rest/pulls/pulls?apiVersion=2026-03-10#merge-a-pull-request-asynchronously))

The docs currently disagree on failure atomicity: CLI/product copy describes direct stack merge as all-or-nothing, while the troubleshooting page says a runtime failure can leave lower PRs merged and higher PRs open. Preview automation should always re-read every PR and its base after a merge attempt, rather than assuming transactionality. ([CLI reference](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands#gh-stack-merge), [Troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-stacked-pull-requests))

## CLI behavior and ownership

### Git-local workflow

| Command | Behavior relevant to jj |
| --- | --- |
| `init [branches...] --base` | Adopts/creates Git branches, enables rerere, writes local Stack state. |
| `add [branch]` | Adds a new top Git branch and optionally commits staged/updated files. |
| `checkout` | Imports a remote Stack into local tracking and checks out a Git branch. |
| `rebase` | Cascading raw-Git rebase; can force-update branch history. |
| `modify` | Interactive TUI for drop/fold/insert/rename/reorder; requires a clean linear Git stack. |
| `push` | Pushes active branches with force-with-lease; non-atomic across branches; does not create/update PRs. |
| `submit` | Sequentially force-with-lease pushes, creates/updates PRs, and creates/updates remote Stack; non-atomic. |
| `sync` | Fetch/reconcile/fast-forward trunk/rebase/push/update PR and Stack state; atomic ref push, but owns local Git history. |
| `view --json` | Reads gh-stack's locally tracked state, not just the remote object. |
| navigation commands | Switch raw Git branches. |

`submit --auto` is the noninteractive mode and creates drafts unless `--open` is supplied. It has no noninteractive title/body flags; generated titles come from commit or branch names, after which `gh pr edit` is needed. A true local/remote composition divergence makes noninteractive `sync` abort without mutation but exit successfully, so an agent cannot rely on exit status alone. ([CLI reference](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands), [official skill](https://github.com/github/gh-stack/blob/v0.1.0/skills/gh-stack/SKILL.md), [`sync` implementation](https://github.com/github/gh-stack/blob/v0.1.0/cmd/sync.go))

Local state is versioned JSON in `.git/gh-stack`, plus `.git/gh-stack-rebase-state` and `.git/gh-stack.lock`. The lock is advisory and local operations also use a checksum for optimistic concurrency. Since native jj workspaces share one Git backing repository, this would be centralized shared state even though their working copies are independent. Avoiding it keeps the integration simpler. ([schema](https://github.com/github/gh-stack/blob/v0.1.0/internal/stack/schema.json), [state implementation](https://github.com/github/gh-stack/blob/v0.1.0/internal/stack/stack.go), [lock implementation](https://github.com/github/gh-stack/blob/v0.1.0/internal/stack/lock.go))

Push behavior is not uniform in `v0.1.0`: `link` atomically pushes branch arguments without force; `push` uses non-atomic force-with-lease; `submit` pushes branches sequentially with force-with-lease; `sync` uses an atomic multi-ref push and force-with-lease after a rebase. This is another reason not to let gh-stack own jj bookmark publication. ([`link`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go), [`push`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/push.go), [`submit`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit.go), [`sync`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/sync.go), [Git push helper](https://github.com/github/gh-stack/blob/v0.1.0/internal/git/gitops.go))

### External-tool workflow: `gh stack link`

`link` is the intended Jujutsu bridge:

```sh
# New Stack from already-created PRs, bottom to top
GH_REPO=OWNER/REPO gh stack link --open 101 102 103

# Append new PRs to an existing Stack
GH_REPO=OWNER/REPO gh stack link STACK_NUMBER 104 105
```

Properties:

- accepts branch names, PR numbers, or PR URLs, ordered bottom to top;
- with branch arguments, atomically/non-force pushes them, reuses an open PR or creates a draft PR, and corrects PR bases;
- with PR numbers/URLs, performs no local push, corrects PR bases, and creates the remote Stack;
- creates drafts by default; `--open` makes newly created PRs ready;
- `--base` selects a non-default trunk for a new Stack;
- writes no `.git/gh-stack` and does not initialize local gh-stack tracking;
- can append only at the top; normal updates must include existing members and cannot remove or reorder them;
- rejects new members that are merged, closed, queued, auto-merge-enabled, or already in another Stack.

([Using other tools, including Jujutsu](https://docs.github.com/en/pull-requests/reference/use-other-tools-with-stacked-pull-requests), [`link` implementation](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go))

Unstacking can remove open/draft/closed members; merged or queued members stay in the historical Stack. Removing members may dissolve a Stack once fewer than two remain. There is no replace/reorder API. ([REST reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/rest-api.md))

## Reordering and structural edits: Git-native vs jj/external tools

The apparently richer Git-native behavior does **not** use an unpublished in-place reorder mutation. In `v0.1.0`, `gh stack modify` rewrites the local Git stack; the following `gh stack submit` automates a destructive remote unstack-and-recreate sequence. `gh stack link` deliberately refuses that sequence and exposes only the additive operations that the public Stacks API can express. ([modify guide](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/guides/modify.md), [`modify` apply engine](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/apply.go), [`submit` recreation path](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit.go), [`link` update validation](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go))

### Git-native `modify` then `submit`

`modify` is an interactive TUI. It requires the active stack in a Git checkout, a clean working tree, no rebase, no unmerged PR in a merge queue, and a linear/non-diverged commit chain. Merged rows are locked. Reordering is mutually exclusive with structural actions (drop, fold, insert, rename) in one session. If a remote Stack is affected, a `.git/gh-stack-modify-state` snapshot blocks another `modify` until submission. Conflicts can be continued or aborted, but once the phase reaches `pending_submit`, `modify --abort` does **not** restore the old branch tips; it only tells the user to submit. ([modify CLI](https://github.com/github/gh-stack/blob/v0.1.0/cmd/modify.go), [preconditions](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/preconditions.go), [recovery state](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/state.go), [TUI action modes](https://github.com/github/gh-stack/blob/v0.1.0/internal/tui/modifyview/model.go))

On save, the local apply engine:

1. snapshots branch names/tips and local Stack metadata;
2. locally renames branches and creates inserted branches;
3. implements fold-down by cherry-picking the folded layer into its lower neighbor, and fold-up by widening the upper neighbor's replay range;
4. removes dropped/folded branches from Stack metadata without deleting their local branch refs;
5. rebuilds the requested branch order; and
6. cascades raw `git rebase --onto <new-parent> <old-parent-tip> <branch>` through active layers, then checks out the best surviving branch.

The rebased layers receive new commit SHAs. Conflicts stop in a recoverable state for `gh stack modify --continue` or `--abort`. ([apply engine](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/apply.go), [Git operation implementation](https://github.com/github/gh-stack/blob/v0.1.0/internal/git/gitops.go))

The subsequent `gh stack submit` performs this remote sequence:

1. `POST /repos/{owner}/{repo}/stacks/{old-number}/unstack`;
2. clears the locally remembered remote Stack ID and number;
3. fetches, then force-with-lease pushes each surviving active branch **sequentially**, bottom to top;
4. reuses an open PR found for the same head branch, creates a PR if none exists, and—now that the PR is unstacked—uses `PATCH /repos/{owner}/{repo}/pulls/{number}` to correct its base;
5. `POST /repos/{owner}/{repo}/stacks` with the complete new PR-number order; and
6. records the returned new Stack ID/number.

This preserves ordinary PR identities when their head branch name is preserved, but it does **not** preserve the Stack object or Stack number. The source explicitly zeroes both old identifiers before `CreateStack`; tests model old Stack `#7` becoming new Stack `#99`. It is also non-atomic: the old Stack is removed before sequential pushes, PR-base edits, and recreation. ([submit implementation and tests](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit.go), [`TestSubmit_WithPendingModify_SequentialPush`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit_test.go), [REST implementation](https://github.com/github/gh-stack/blob/v0.1.0/internal/github/github.go))

One `v0.1.0` recovery sharp edge is visible in source: `runSubmit` does not inspect `syncStack`'s success boolean before clearing the pending-modify state. A failed best-effort remote recreation can therefore leave pushed/retargeted PRs unstacked while `submit` still reaches its normal success path and removes the retry guard. Always read back remote membership rather than trusting the command exit alone. ([submit implementation](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit.go))

### Identity and rewrite matrix

| Action | Branches/commits | Existing PRs | Remote Stack |
| --- | --- | --- | --- |
| Reorder | Same branch names; moved layers and affected descendants are rebased, so commit SHAs change. | Same PR numbers, with corrected direct bases, because head branch names are unchanged. | Old Stack unstacked; new Stack ID/number with the same PR numbers in new order. |
| Insert | Creates a new empty local branch at its lower parent's tip; surrounding layers remain/rebase as required. | Existing PR numbers stay; the inserted branch needs a new PR number. | Recreated under a new Stack ID/number. |
| Drop | Dropped branch/ref and its unique commits are excluded from surviving upstack history; the local branch is retained. | Dropped PR is retained and reported as still open, but becomes standalone; surviving PR numbers stay. | Recreated without the dropped PR under a new Stack ID/number. |
| Fold down/up | Folded local branch remains but leaves Stack metadata; its commits are cherry-picked down or replayed into the upper target. Target and descendants can receive new SHAs. | Folded PR becomes standalone; surviving/target PR numbers stay. | Recreated without the folded PR under a new Stack ID/number. |
| Rename | `git branch -m` changes only the local branch; submit pushes the new remote ref and does not delete the old remote ref. | Unless an open PR already exists for the new head name, `ensurePR` creates a new PR and overwrites the local association. The old PR remains unstacked; its PR number/review is not migrated. | Recreated with the new PR number and a new Stack ID/number. |

The rename row is a direct source-path consequence (`RenameBranch` is local-only; `submit` looks up PR by the new branch name and creates when absent), but deserves a live preview test because GitHub-side branch-management behavior can add edge cases. ([rename apply](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/apply.go), [`ensurePR`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit.go), [Git rename/push implementation](https://github.com/github/gh-stack/blob/v0.1.0/internal/git/gitops.go))

An inserted branch is intentionally empty at apply time. Before publication it needs a unique commit and the branches above it must be restacked to contain that commit; otherwise GitHub may have no diff from which to create the new PR or the chain may diverge. The exact immediate-`submit` failure mode is another live-test item—the docs currently tell the user to submit after modifying without spelling out this empty-layer interval. ([modify guide](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/guides/modify.md), [insert implementation](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/apply.go))

### Why `link` rejects reorder, insert-in-middle, and drop

The remote mutation API has only:

- `POST /stacks` — create a new Stack from a complete, already-valid PR chain;
- `POST /stacks/{number}/add` — append a delta to the top; and
- `POST /stacks/{number}/unstack` — remove every removable member/dissolve the Stack.

There is no replace-members, reorder, insert-at-position, or remove-one-member endpoint; GraphQL Stack fields are read-only. `link` consequently requires the current remote membership to be an exact ordered prefix of the requested order. It prevalidates that no current member is omitted, then `appendDelta` rejects any different position as a reorder/removal. This is an additive-membership design for external tools, not an inability to calculate a desired graph. ([REST reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/rest-api.md), [GraphQL reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/graphql-api.md), [`prevalidateStack`, `updateLink`, and `appendDelta`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go))

However, the `v0.1.0` reorder check is **too late to make a rejected call non-mutating**. In create/update mode, `link` first pushes branch arguments, creates missing PRs, and calls `PATCH /pulls/{number}` to make bases match the requested order; only afterward does `upsertStack -> updateLink -> appendDelta` reject the order. Even PR-number arguments avoid only the push, not the base PATCH. Therefore `gh stack link 101 103 102` against remote order `[101, 102, 103]` can change PR bases and then fail without changing Stack membership. `jjpr` must compare the full remote ordered list itself and refuse a non-prefix request **before** invoking `link`. The older partial-mutation report in issue `#374` concerned membership on `v0.0.8`; `v0.1.0` added omission prevalidation, but the late reorder/base-mutation path remains in source. ([`runLinkCreateOrUpdate`, `fixBaseBranches`, and `updateLink`](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go), [Issue #374](https://github.com/github/gh-stack/issues/374))

For an all-open jj-managed Stack, a deliberate external rebuild is possible:

```text
read and journal old Stack/PR/base/head state
-> unstack old Stack
-> jj restack and push bookmarks
-> gh stack link PRs in new bottom-to-top order
-> verify every PR base/head and the new Stack object
```

With PR-number arguments, the final `link` does not push and will correct bases before creating the replacement Stack. PR numbers remain stable as long as head bookmark names remain stable; the Stack number changes. This must be an explicit recreate operation with recovery data, not an automatic fallback inside ordinary `link`/submit, because the operation is not transactional. ([external-tool workflow](https://docs.github.com/en/pull-requests/reference/use-other-tools-with-stacked-pull-requests), [`link` implementation](https://github.com/github/gh-stack/blob/v0.1.0/cmd/link.go))

#### Live Git-versus-jj structural test

A second private-repository test on 2026-08-02 validated the replacement mechanics with PRs `#23`, `#24`, and `#25`:

| Operation | Remote identity result | Local-history result |
| --- | --- | --- |
| Git-native create | Created Stack `#26` in order `#23, #24, #25`. | Linear branches alpha, beta, gamma. |
| Git-native reorder | `submit` deleted Stack `#26` (subsequent GET returned 404), preserved the three PR numbers, and created Stack `#27` in order `#23, #25, #24`. All PRs returned `CLEAN`/`MERGEABLE`. | `modify` kept alpha's SHA and rebased gamma and beta to new SHAs. Before `submit`, the remote Stack and PR heads remained completely unchanged while `.git/gh-stack-modify-state` recorded `pending_submit`. |
| Git-native drop | `submit` deleted Stack `#27`, created two-PR Stack `#28` containing `#23, #24`, and left dropped PR `#25` open with `stack: null`. | The gamma branch/ref remained; beta was rebased directly onto alpha. |
| jj structural rebuild | An explicit `unstack` plus jj push/base retarget plus PR-number `link` deleted Stack `#28` and created Stack `#29` in order `#23, #25, #24`. Same PR numbers; new Stack number; all PRs clean/mergeable. | A `.git`-less jj workspace first refused to rewrite the published beta head because it was immutable. After deliberate `--ignore-immutable`, jj rebased beta onto gamma, retained its jj change ID, range-checked conflicts, dry-ran the push, then published only beta. |

The rejected jj-workspace command `GH_REPO=ci/jjpr-validation gh stack link --base main 23 25 24` against Stack `#28` also confirmed the late-validation hazard: `link` attempted to PATCH PR `#24`'s base to gamma first; GitHub rejected that PATCH with HTTP 422 because `#24` was still a member of the old Stack; only then did `link` report that new PRs must be added at the top. This instance did not mutate the base, but the attempted write proves `jjpr` cannot use `link` itself as a safe structural preflight.

The test ended by unstacking Stack `#29` and closing all three test PRs. The repository had no open PRs afterward.

Merged and queued history is the hard boundary. Those PRs cannot be unstacked or added anew, so a rebuild leaves them in the old historical Stack while the open tail moves to a new Stack. Official issue `#382` demonstrates the resulting permanent loss of full-stack grouping for a middle insertion. The native pending-modify handler also ignores the `Unstack` response indicating that locked members remain, clears its old ID anyway, and proceeds toward recreation; a partially merged Stack can therefore retain an old merged object and then fail to create the requested replacement. Merged branches can separately block local `modify` when their refs were pruned (`#146`). ([Issue #382](https://github.com/github/gh-stack/issues/382), [pending-modify handler](https://github.com/github/gh-stack/blob/v0.1.0/cmd/submit.go), [`Unstack` return contract](https://github.com/github/gh-stack/blob/v0.1.0/internal/github/github.go), [Issue #146](https://github.com/github/gh-stack/issues/146), [unstack rules](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/faq.md))

### Worktree and jj workspace implications

`modify` is not a metadata-only planner: it invokes local branch rename/create, checkout, cherry-pick, and three-argument Git rebase, and requires a clean interactive Git worktree. gh-stack stores `gh-stack`, its lock, and modify recovery under Git's reported `$GIT_DIR`; linked Git worktrees have private administrative Git dirs but share branch refs. The result is isolated gh-stack metadata/locks operating on shared refs, so two worktrees can hold divergent local models and the lock does not serialize their branch rewrites. Branches checked out in another worktree can reject force-updates; the official tracker has a labeled worktree bug for the analogous `sync` trunk update. `modify` also treats untracked files as dirty (`#111`) and can fail if a merged branch was pruned (`#146`). ([stack storage](https://github.com/github/gh-stack/blob/v0.1.0/internal/stack/stack.go), [modify state](https://github.com/github/gh-stack/blob/v0.1.0/internal/modify/state.go), [Git worktree details](https://git-scm.com/docs/git-worktree#_details), [Git operations](https://github.com/github/gh-stack/blob/v0.1.0/internal/git/gitops.go), [worktree issue #87](https://github.com/github/gh-stack/issues/87), [untracked-file issue #111](https://github.com/github/gh-stack/issues/111), [pruned-branch issue #146](https://github.com/github/gh-stack/issues/146))

In a native jj workspace model, raw Git rebases would rewrite shared bookmark targets behind other workspaces, bypass jj's operation/recovery model, and strip jj change-ID commit headers. Therefore jj/jjpr should reproduce only the desired graph with jj operations, then use an explicit remote unstack/re-link transaction when structural replacement is requested. It should never call `gh stack modify` or the Git-local submit recreation path. ([Jujutsu Git compatibility](https://docs.jj-vcs.dev/latest/git-compatibility/), [Jujutsu workspaces](https://docs.jj-vcs.dev/latest/working-copy/#workspaces))

## APIs and agent integration

REST adds `stack` to PR resources: repository-scoped Stack number/id, size, one-based position, and ultimate base ref/SHA. It also provides list/get/create/add-to-top/unstack endpoints. Create takes 2–100 ordered PR numbers. GraphQL is read-only (`PullRequest.stack`, `stackEntry`, and entries connection). ([REST and GraphQL overview](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests-rest-and-graphql-apis), [REST reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/rest-api.md), [GraphQL reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/graphql-api.md))

Useful headless reads:

```sh
gh api repos/OWNER/REPO/pulls/PR --jq '.stack'
gh api 'repos/OWNER/REPO/stacks?pull_request=PR'
```

The official skill is installed through GitHub CLI, for example:

```sh
gh skill install github/gh-stack gh-stack --agent codex --scope user --pin v0.1.0
gh skill update --dry-run
```

`gh skill` supports project or user scope; project-scope Codex skills share `.agents/skills`. Version resolution prefers the latest repository tag, then default-branch HEAD, unless pinned. ([gh 2.90.0 release](https://github.com/cli/cli/releases/tag/v2.90.0), [official gh-stack skill](https://github.com/github/gh-stack/blob/v0.1.0/skills/gh-stack/SKILL.md))

The upstream `gh-stack` skill is large and Git-first. Its useful jj-compatible pieces are the noninteractive contract (`submit --auto`, `view --json`, explicit branch/remote arguments, `merge --yes`), `link`, remote merge, API/status handling, and exit codes. A future `jjpr` skill should incorporate that limited contract and explicitly prohibit gh-stack's raw-Git lifecycle rather than installing/composing the whole upstream skill. There is already an upstream request to reduce the skill's roughly 15.6k-token footprint. ([Issue #377](https://github.com/github/gh-stack/issues/377))

## Jujutsu workspace compatibility probe

Official Jujutsu behavior:

- A colocated repository's main workspace has `.jj` and `.git`; jj commands automatically import/export refs. Git normally sees a detached HEAD, and interleaving mutating Git commands with jj can cause conflicts or bugs.
- Native `jj workspace add` workspaces share repository storage and each have their own `@`, but they are not Git worktrees.
- Git's `rebase` strips jj's commit `change-id` header. Native jj rebasing should remain authoritative.

([Jujutsu Git compatibility](https://docs.jj-vcs.dev/latest/git-compatibility/), [Jujutsu workspaces](https://docs.jj-vcs.dev/latest/working-copy/#workspaces), [`jj git export`](https://docs.jj-vcs.dev/latest/cli-reference/#jj-git-export))

A local scratch probe on 2026-08-01 confirmed the boundary:

1. Create a colocated repository, then `jj workspace add /tmp/.../ws2 --name probe2 -r main`.
2. The main workspace has `.jj` and `.git`; the added workspace has `.jj` but no `.git`.
3. `git status` and therefore gh-stack repository discovery fail inside the added workspace.
4. Bookmarks created from the added workspace do not appear as `.git/refs/heads/*` until `jj git export`; export operates against the shared main Git store.

The live GitHub test refined this: explicit `GH_REPO=OWNER/REPO` is sufficient for `gh stack link` from a secondary, `.git`-less jj workspace. Passing PR numbers or already-pushed bookmark names avoids local Git discovery and local pushes; no `.git/gh-stack` state is created. `jjpr` can therefore stay in the caller's workspace and does not need to hop back to the main colocated checkout.

### Live end-to-end GitHub validation

The private `ci/jjpr-validation` repository was exercised with `gh-stack v0.1.0`, four jj bookmarks, and three native jj workspaces:

1. jj created and pushed a three-PR bookmark chain; `gh stack link --base main BRANCH...` created draft PRs and a native Stack.
2. A second, `.git`-less jj workspace successfully ran `GH_REPO=ci/jjpr-validation gh stack link --base main PR...`; PR-number linking was idempotent and wrote no local gh-stack state.
3. A lower-layer jj edit plus descendant rebase produced real conflicts. They were resolved with jj, pushed, and the remote Stack remained valid.
4. Appending a fourth top PR worked. Attempts to reorder or omit an existing member failed with exit code 5; Stack membership stayed unchanged.
5. `gh stack link --open` promoted the PRs to ready. `gh stack merge` on the second PR merged the lower pair.
6. Contrary to the optimistic product description, GitHub retargeted the oldest survivor to `main` but did **not** rewrite its head. The survivor became `CONFLICTING`/`DIRTY`; `gh stack merge` still reported success. jj repaired this by fetching, rebasing the oldest survivor onto the new `main`, validating the whole remaining range, and pushing only the surviving bookmarks. Both remaining PRs returned to clean two-line diffs.
7. Re-linking the original full membership after a partial merge would be unsafe because it can try to restore the old direct-base chain. Post-merge reconciliation must read REST state, fetch/rebase/push survivors with jj, and avoid full `link`.
8. A final native merge closed the Stack. A fresh two-PR stack was then created entirely from a `.git`-less jj workspace using `GH_REPO` plus bookmark names, proving the clean workspace bridge; remote `unstack` also worked.

The repository finished with no open test PRs. Test branches remain as harmless fixtures.

## Preview sharp edges to test or defend against

These are official-repository reports and should be treated as open preview issues, not all as independently reproduced platform facts:

- `gh stack push` data-loss report in `v0.1.0`: it fetches immediately before force-with-lease, so the refreshed lease may allow overwriting remote-only commits. The reporter provides a reproduction. The proposed jj design never calls it. ([Issue #380](https://github.com/github/gh-stack/issues/380))
- Multi-remote repository selection report in `v0.1.0`: `--remote` controls Git push while API resolution can still use `origin`; `gh repo set-default` may not override it. Always set `GH_REPO=OWNER/REPO` in `jjpr`. ([Issue #381](https://github.com/github/gh-stack/issues/381))
- Stale/missing `refs/pull/N/merge` can silently prevent `pull_request` workflows from starting. Detect missing expected check runs instead of treating no run as success. ([Issue #319](https://github.com/github/gh-stack/issues/319))
- `gh stack sync` can fail when trunk is checked out in another Git worktree. This is less directly relevant to native jj workspaces, but reinforces avoiding Git-local gh-stack state. ([Issue #87](https://github.com/github/gh-stack/issues/87))
- Force-push restacks can erase GitHub's “changes since last view” review context and may dismiss approvals under repository rules. Avoid routine `gh stack sync`; make jj restacks intentional. ([Issue #354](https://github.com/github/gh-stack/issues/354))
- Remote membership is append-only; inserting/reordering in the middle can require unstacking and recreating open portions and cannot rewrite merged history. ([Issue #382](https://github.com/github/gh-stack/issues/382), [REST reference](https://github.com/github/gh-stack/blob/v0.1.0/docs/src/content/docs/reference/rest-api.md))
- An older `v0.0.8` report says a failed `link` partially changed membership. Even on `v0.1.0`, verify Stack membership and every PR base after linking rather than trusting exit status alone. ([Issue #374](https://github.com/github/gh-stack/issues/374))

## Proposed future `jjpr` contract

1. Require `gh >= 2.97.0`, install/upgrade `github/gh-stack`, and capability-check the target repository.
2. Preserve current jj workspace, bookmark, push, and PR mechanics.
3. After creating/updating all PRs, collect their numbers in bottom-to-top order.
4. Before invoking `link`, read the current remote membership and classify the desired order as exact match, clean top append, or structural divergence. Never rely on `link` as the preflight because its rejection can follow pushes, PR creation, or base PATCH attempts.
5. For a new Stack or clean append, run `GH_REPO=OWNER/REPO gh stack link [--open] PR...`; never pass branch names. Read back the Stack via REST and verify ID/number, size, ordering, ultimate base, and every direct PR base. Fail closed on a partial result.
6. For insertion/reorder/removal, default to explaining that GitHub cannot update membership in place. Offer a separate explicit recreate operation only when every member is removable: journal the jj operation ID plus old Stack/PR/base/head state; restack and range-check locally with jj; unstack the old object; dry-run and push affected bookmarks with expected-head protection; retarget bases/re-link the preserved PR numbers; then verify the complete new Stack. Never recreate across merged or queued members.
7. Use remote REST state rather than `gh stack view`; avoid `.git/gh-stack` entirely.
8. If native merging is adopted, use `gh stack merge PR --yes --<method>`, then poll/read every PR, fetch with jj, reconcile remote branch heads, and only then continue local work.
9. Never call `gh stack init/add/checkout/rebase/sync/push/submit/modify` from the jj mode.
10. End-to-end test at least: new stack; existing PR chain link; draft/ready; append; structural recreate; PR-base correction; partial merge and jj reconciliation; full merge; closed middle; failed CI; merge queue when enabled; multi-remote; two jj workspaces; failed link/partial-state detection; missing expected Actions run.

This gives jj users GitHub's native review/CI/merge semantics without surrendering the local change graph to a Git-first tool.
