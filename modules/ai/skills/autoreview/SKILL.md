---
name: autoreview
description: "Auto Review closeout for Git and Jujutsu changes. Uses Amp by default in Amp orbs and Codex elsewhere."
---

# Auto Review

Run the bundled structured review helper as a closeout check. This is code review, not Guardian `auto_review` approval routing.

Amp is the default inside an Amp orb, detected by the documented `AMP_ORB=1` environment variable. Codex is the default elsewhere and usually delivers the best local review results. An explicit `--engine` always wins; `AUTOREVIEW_ENGINE` overrides the environment-based default. Codex defaults to `gpt-5.6-sol` and retries once with `gpt-5.6-terra` only when the account cannot access Sol; thinking follows the Codex CLI config. Claude defaults to `claude-fable-5`. Amp defaults to `openai/gpt-5.6-sol` at `high` reasoning through a generated adapter plugin that reuses the existing `amp login`. Grok defaults to `grok-4.6`. Pi and opencode use the model their own CLI is configured for.

Use when:

- user asks for Codex review / Claude review / Amp review / Grok review / Pi review / autoreview / second-model review
- after non-trivial code edits, before final/commit/ship
- reviewing a local branch or PR branch after fixes

Do not require autoreview for a change whose entire diff is prose-only internal notes or `SKILL.md` documentation. Still inspect the diff directly. This exception does not cover user-facing documentation, executable examples, configuration, scripts, generated files, or behavior changes.

## Contract

- Default output is P0-P2: blocking defects plus meaningful but non-critical issues; style-tier P3 observations are omitted. Narrow with `--max-priority P0`/`P1` for a blockers-only pass, widen with `--max-priority P3` only when the caller explicitly asks for a full-depth review.
- Treat review output as advisory. Never blindly apply it.
- Verify every finding by reading the real code path and adjacent files.
- Read dependency docs/source/types when the finding depends on external behavior.
- Reject unrealistic edge cases, speculative risks, unrelated rewrites, and fixes that over-complicate the codebase.
- Prefer root-cause fixes at the right ownership boundary. A coherent refactor is appropriate when it removes the bug class, duplicate policy, stale paths, or ownership confusion; do not default to a symptom patch.
- When an accepted finding exposes a bug class or repeated pattern, inspect its owner and relevant sibling implementations before fixing. Fix the same bug class across its owner-boundary neighborhood when practical; stop at unrelated invariants, different owners, and unapproved contract changes.
- Keep going until structured review returns no accepted/actionable findings, only while the work remains inside the authorized task scope, capped at 5 rounds per closeout. If the cap hits, stop, tell the user the cap was reached, and list what was still open.
- Nitpick escape hatch: if the remaining findings are style-only, taste-level, or speculative edge-casing with no real bug, reject them and stop early — but say so explicitly: report that you stopped early and summarize what the rejected findings said.
- If a review-triggered fix changes code, rerun focused tests and rerun the structured review helper.
- For security-audit suppression changes, verify accepted findings remain auditable: suppressed findings stay in structured output, active output keeps an unsuppressible suppression notice, and aggregate findings cannot hide unrelated active risk.
- Never switch or override the requested review engine/model except for the documented Codex Sol-to-Terra account-access fallback. Capacity, rate-limit, and unrelated failures keep the same engine/model: retry the same command a few times.
- Be patient with large bundles. Structured review can take up to 30 minutes while the model call is active, especially with Codex tools or web search.
- Treat heartbeat lines like `review still running: ... elapsed=... pid=...` as healthy progress, not a hang. Let the helper continue while heartbeats are advancing. Pass `--stream-engine-output` when live engine text is useful; Codex and Claude filter tool/status chatter, other engines pass raw output through.
- Do not kill a review just because it has been quiet for 2-5 minutes, or because it is still running under the 30-minute window. Inspect the process only after missing multiple expected heartbeats, after 30 minutes, or after an obviously failed subprocess; prefer letting the same helper command finish.
- Tools are useful in review mode. The helper allows read-only inspection tools and web search by default so reviewers can check dependency contracts, upstream docs, and current behavior.
- Security perspective is always included, but it should not cripple legitimate functionality. Report security findings only when the change creates a concrete, actionable risk or removes an important safety check.
- For regression provenance, if no blamed PR is traceable, use the blamed commit as the provenance: commit SHA, date, and author username. Do not guess a merger or frame missing PR metadata as a separate finding.
- Do not invoke built-in `codex review`, nested reviewers, or reviewer panels from inside the review. The helper builds one bundle, calls one selected engine, validates one structured result, and stops.
- Stop as soon as the helper exits 0 with no accepted/actionable findings. Do not run an extra review just to get a nicer "clean" line, a second opinion, or clearer closeout wording.
- Treat the helper's successful exit plus absence of actionable findings as the clean review result, even if the underlying Codex CLI output is terse.
- Multi-reviewer panels are opt-in only. Use them when explicitly requested or when risk justifies the extra spend; the main agent still verifies every accepted finding before fixing.
- If rejecting a finding as intentional/not worth fixing, add a brief inline code comment only when it explains a real invariant or ownership decision that future reviewers should know.
- Do not push just to review. Push only when the user requested push/ship/PR update.

## Scope Governor

Autoreview is a closeout gate, not permission to change the task's product contract. Define scope by the authorized invariant and its architectural owner, not by the first patch.

Before patching a finding, classify it:

- **In-scope blocker**: affects the same violated invariant or owner-boundary neighborhood and can be fixed without changing the task's contract.
- **Follow-up**: real but belongs to an unrelated bug class, different owner, independent cleanup, or broader hardening track.
- **Stop-and-escalate**: requires a new protocol/config/storage/public API contract, a different owner boundary, or a design choice outside the original request.

Stop patching and report the scope break instead of continuing when:

- a task turns into an unauthorized product, protocol, migration, storage, or security-model change;
- two review-triggered patch cycles have not converged; pause and reclassify every remaining finding before another edit;
- the best fix is "define the canonical contract first" rather than another local inference layer;
- fixing the accepted finding would make the change no longer describe the same behavior, issue, or owner boundary.

After the two-cycle pause, continue only when every remaining accepted finding is still an in-scope blocker. Otherwise preserve the useful analysis and open or request a follow-up for unrelated work. Do not land a symptom patch or keep committing speculative fixes just to satisfy the reviewer.

Critical exceptions must be explicit: active data loss, crash, broken install/upgrade, release blocker, or concrete security exposure. If the exception is not one of those, it is not critical enough to blow up scope.

## Pick Target

Dirty local work:

```bash
<autoreview-helper> --mode local
```

Use this only when the patch is actually unstaged/staged/untracked in the
current checkout. For committed, pushed, or PR work, point the helper at the commit
or branch diff instead; do not force `--mode local` / `--uncommitted` just
because the helper docs mention dirty work first. A clean local review
only proves there is no local patch.

In a jj repo, the helper uses native `jj diff`/`jj show`, including in
non-colocated repos and additional workspaces. Run `jj status` first. Local mode
reviews the current workspace's `@` diff.

Branch/PR work:

```bash
<autoreview-helper> --mode branch --base origin/main
```

For jj, use revsets/bookmarks and select the head explicitly when needed:

```bash
<autoreview-helper> --mode branch --base 'main@origin' --head '<bookmark>'
```

The jj defaults are `trunk()` for the base and `@-` for the head. Those are
appropriate for a normal empty `@` above one finished change, but not enough to
identify an arbitrary stack. Use `$jjpr` to inspect the stack, then review each
PR-sized bookmark against its immediate lower bookmark, or review the whole
stack by passing its bottom base and explicit top bookmark. Branch mode diffs
from the base/head fork point, matching Git's three-dot review shape.

Optional review context is first-class:

```bash
<autoreview-helper> --mode branch --base origin/main --prompt-file /tmp/review-notes.md --dataset /tmp/evidence.json
```

If an open PR exists, use its actual base:

```bash
base=$(gh pr view --json baseRefName --jq .baseRefName)
<autoreview-helper> --mode branch --base "origin/$base"
```

Committed single change:

```bash
<autoreview-helper> --mode commit --commit HEAD
```

or with the helper:

```bash
~/.agents/skills/autoreview/scripts/autoreview --mode commit --commit HEAD
```

In jj mode, `--head` and `--commit` accept a jj change ID, bookmark, or revset;
prefer a concrete change ID when passing a revision through helper scripts.
Revsets are passed without a shell hop, but `description("...")` matches the
complete description and can miss because of description formatting. Use a
change ID, or deliberately use `description(substring:"...")`. When omitted,
`--commit` defaults to `@-`; Git defaults to `HEAD`.

Use commit review for already-landed or already-pushed work on `main`. Reviewing
clean `main` against `origin/main` is usually an empty diff after push. For a
small stack, review each commit explicitly or review the branch before merging
with `--base`.

## Parallel Closeout

Format first if formatting can change line locations. Then it is OK to run tests and review in parallel:

```bash
scripts/autoreview --parallel-tests "<focused test command>"
```

Tradeoff: tests may force code changes that stale the review. If tests or review lead to code edits, rerun the affected tests and rerun review until no accepted/actionable findings remain. Once that rerun exits cleanly, stop; do not spend another long review cycle on redundant confirmation.

## Review Panels

Run multiple reviewers against one frozen bundle:

```bash
<autoreview-helper> --reviewers codex,claude
```

`--panel` is shorthand for Codex plus Claude unless `--engine` changes the first reviewer:

```bash
<autoreview-helper> --panel
```

Set reviewer models and thinking/effort explicitly:

```bash
<autoreview-helper> --reviewers codex,claude --model codex=gpt-5.6-sol --thinking codex=high --model claude=sonnet --thinking claude=max
```

Inline syntax is also supported:

```bash
<autoreview-helper> --reviewers codex:gpt-5.6-sol:high,claude:sonnet:max
```

`AUTOREVIEW_MODEL` and `AUTOREVIEW_THINKING` env vars accept the same keyed
syntax (`codex=gpt-5.5,claude=sonnet` or a bare global value) and sit between
CLI flags and built-in defaults.

Thinking per engine: Codex maps to `model_reasoning_effort` (`low`-`max`).
Claude maps to `--effort` (`low`-`max`). Amp maps to the adapter plugin's
`reasoningEffort` (`none`-`max`, default `high`) and its model must be a
`provider/model` id (default `openai/gpt-5.6-sol`). Grok maps to `--effort`
(`low`-`xhigh`). Pi maps to `--thinking`
(`off`-`max`). OpenCode maps to `--variant` (`minimal`-`max`). Engines
without a real thinking knob reject `--thinking`.

## Context Efficiency

Run the helper directly so target selection, engine choice, structured validation, and exit status all stay in one path. If output is noisy, summarize the completed helper output after it returns; do not ask another agent or reviewer to rerun the review.

## Helper

Bundled helper:

```bash
~/.agents/skills/autoreview/scripts/autoreview --help
```

Repo vendored helper:

```bash
modules/ai/skills/autoreview/scripts/autoreview --help
```

The helper:

- detects jj before Git and uses native jj bundles; Git remains the fallback
- chooses dirty local changes first, scoped to the current jj workspace's `@`
- otherwise uses current PR base if `gh pr view` works
- otherwise uses `trunk()`/`@-` in jj or `origin/main`/`HEAD` in Git
- supports `--base`, `--head`, and `--remote` for explicit branch/stack targets
- refreshes the selected remote before a live branch review and fails closed on
  fetch errors; use `--no-fetch` only when intentionally reviewing local refs
- exits successfully without invoking any engine when the computed diff has no
  changed paths
- supports `--engine codex`, `claude`, `amp`, `grok`, `droid`, `copilot`, `pi`, and `opencode`; default precedence is explicit `--engine`, `AUTOREVIEW_ENGINE`, Amp when `AMP_ORB=1`, then Codex
- use `--mode commit --commit <ref>` for already-committed work, especially clean `main` after landing
- should be left in `--mode auto` or forced to `--mode branch` for PR/branch work; do not force `--mode local` after committing
- writes only to stdout unless `--output` or `--json-output` is set
- reports only findings at or above `--max-priority` / `AUTOREVIEW_MAX_PRIORITY` (default `P2`; upstream defaults to `P0`); lower priorities are omitted from output and exit status
- supports `--dry-run` as a real preflight: builds the bundle, applies the same input validation as a live run, resolves each reviewer binary, and exits nonzero on a broken setup without invoking any engine
- supports `--parallel-tests`, `--prompt`, `--prompt-file`, `--dataset`, `--no-tools`, `--no-web-search`, and commit refs
- supports opt-in review panels with `--panel` / `--reviewers`, plus per-engine `--model` and `--thinking` (also via `AUTOREVIEW_MODEL` / `AUTOREVIEW_THINKING`)
- allows read-only tools and web search by default where the selected CLI supports them; forbids nested review in the prompt; Codex is run through `codex exec` with read-only sandbox and structured output; amp reviews the bundle alone through a generated `amp.ai.generate` adapter plugin (temp config dir, so no personal plugins load; existing `amp login` credentials are reused); grok runs headless with only `read_file`/`grep`/`list_dir` (plus web tools), subagents and MCP meta-tools disabled, prompt via file, and rejects `--no-tools` (grok has no reliable tool-off switch); like claude and codex it runs inside the reviewed checkout under the local trust model, so project hooks/config there apply; pi gets only its read tool; opencode runs its read-only plan agent
- keeps droid and copilot adapters even though upstream disabled them; they review with the local trust model, not upstream's isolation contract
- prints `review still running: <engine> elapsed=<seconds>s pid=<pid>` to stderr at long-running intervals while waiting for the selected review engine; `--stream-engine-output` streams live engine text instead
- prints `autoreview clean: no accepted/actionable findings reported` when the selected review command exits 0
- exits nonzero when accepted/actionable findings are present

## Final Report

Include:

- review command used
- tests/proof run
- findings accepted/rejected, briefly why
- the clean review result from the final helper/review run, or why a remaining finding was consciously rejected

Do not run another review solely to improve the final report wording. If the final helper run exited 0 and produced no accepted/actionable findings, report that exact run as clean.
