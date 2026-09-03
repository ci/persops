---
name: pipeline
description: "Run a task through plan, implement, and review stages on headless agent CLIs; the main agent drives and reads artifacts."
---

# Pipeline

Deterministic driver for plan -> implement -> review. Each stage is one fresh
headless engine process (codex, claude, or grok) with a JSON schema; the review
stage wraps `$autoreview` panels and fix rounds. Control flow lives in the
script. Judgment lives in the stage agents and in you, the main agent.

Use when the user asks to run the pipeline, "pipeline this", or wants a task
planned, implemented, and reviewed with different models per stage.

## Contract

- You drive. Advance one stage at a time by default, read the artifacts, and
  decide: continue, edit `plan.md` and rerun, or stop and report.
- Exit codes: `0` stage done, `1` error, `3` needs you. On `3` read the printed
  `HALT` reason and the run's artifacts, then either resolve it yourself (edit
  the plan, adjust scope, pass answers into `task.md`) or surface the exact
  questions to the user. Never guess an owner decision.
- The driver never pushes, opens PRs, or touches remotes. Closeout and PRs go
  through `$pr-closeout` on the workspace afterwards.
- Stage engines start with zero context. The task file and `plan.md` are the
  only handoff. Write the task file as a real work order: goal, constraints,
  non-goals, proof expected.
- Do not run stages yourself in parallel with the driver in the same workspace.

## Commands

The helper is not on PATH. Bind it once per session (also installed under
`~/.claude/skills/pipeline/scripts/pipeline`; repo copy
`modules/ai/skills/pipeline/scripts/pipeline`):

```bash
P=~/.agents/skills/pipeline/scripts/pipeline
```

Create a run. Write the task through a file, never inline quoting:

```bash
T=$(mktemp); cat >"$T" <<'EOF'
<goal, constraints, non-goals, proof expected>
EOF
"$P" new --task-file "$T"
```

`new` creates an isolated checkout (jj workspace or git worktree as a sibling
of the primary checkout under `../worktrees/<repo>-<slug>-<stamp>`) unless
`--workspace` points at an existing checkout of the same repository. It prints the run directory; every other command takes that path.

```bash
"$P" plan <run>          # read-only engine writes plan.md + plan.json
"$P" implement <run>     # write engine implements plan.md and commits
"$P" review <run>        # autoreview panel -> fix -> re-review; --max-rounds caps fix rounds
"$P" run <run> [--until plan|implement|review]   # remaining stages; stops on halt
"$P" status <run>
"$P" summary <run>       # summary.md from artifacts, no LLM
"$P" reject <run> <file> <title> <reason>   # record your rejection of a finding
```

Stages are ordered: `implement` needs a completed plan and `review` needs a
completed implementation.

`run` resumes from the last completed stage, so after resolving a halt just
run it again; it retries the halted stage. A halted plan still counts as
completed (its `plan.md` exists), so edit `plan.md`/`task.md` and `run`, or
call `pipeline plan` to re-plan from scratch.

Engine specs are `engine[:model[:effort]]`. Defaults: `--plan claude:fable:high`
(`fable` is the claude CLI alias for the latest Fable), `--implement
codex:gpt-5.6-sol:high`, `--review codex:gpt-5.6-sol:xhigh,grok:grok-4.6:xhigh`
(any `autoreview --reviewers` spec). Inside an Amp orb (`AMP_ORB=1`) the review
default becomes `amp:openai/gpt-5.6-sol:xhigh,amp:xai/grok-4.6:xhigh`, the same
panel through amp's model providers.
Env defaults: `PIPELINE_PLAN`, `PIPELINE_IMPLEMENT`, `PIPELINE_REVIEW`,
`PIPELINE_RUNS_DIR` (default `~/.local/state/pipeline`), `AUTOREVIEW_BIN`.

## Artifacts

Under the run directory: `task.md`, `plan.md`, `plan.json`, `implement.json`,
`review-N.json`, `fix-N.json`, `summary.md`, `state.json`, and
`logs/<stage>.log` with the full engine transcript. `*.prompt.md` holds the
exact prompt each stage received.

## Halts

The driver stops with exit `3` when:

- the plan lists `open_questions`;
- the workspace is dirty after implement or fix (the stage agent must commit; you decide whether leftovers are work or junk);
- implement or fix reports `question`, `blocked`, or `scope_change`;
- implement or fix reports a failing test, or reports done without a new commit
  (after a failing-test halt, get the tests green yourself before rerunning;
  reviewers do not run tests);
- a review finding survives two fix rounds (not converging): fix it yourself,
  or `pipeline reject` it with a reason, then rerun `review`;
- the fix-round cap is hit with findings still open. Reviews themselves are
  not capped: after fixing things yourself, rerun `review` to confirm clean.

Rejected findings carry the implementer's reason into the next review round so
reviewers do not re-raise them. Read `fix-N.json` and judge the rejections
yourself before accepting a clean result.

## Permissions

Plan runs read-only (codex `read-only` sandbox; claude plan mode with read
tools plus its own read-only Bash classifier; grok `--tools` allowlist with MCP
meta-tools denied, since grok's plan mode does not block writes). A dirty
workspace after plan halts, and every write stage refuses to start on a dirty
workspace. Implement and fix run with permission bypass inside the
isolated workspace, the same house default as `$codex-first`. That isolation
is at the VCS level only, not a sandbox: the stage agent has the same host
access you do, so keep task text and repository instructions trustworthy. Review runs
through the autoreview helper's read-only engine paths.
