---
name: delegate-herdr
description: "Delegate tasks through Herdr with explicit agent, model, reasoning, permissions, status tracking, output capture, and cleanup. Use when asked to run work via Herdr or spawn a named CLI agent in a Herdr session."
---

# Delegate with Herdr

Use Herdr as the lifecycle and terminal control plane for an interactive CLI
agent. Resolve model and reasoning flags from the installed agent CLI; Herdr
does not normalize those flags.

## Contract

- Honor the requested agent, model, reasoning effort, working directory,
  permissions, persistence, and output shape literally.
- Use a unique named session and workspace for delegation unless the user names
  an existing session.
- Never inspect, stop, or delete `default` or another pre-existing session just
  because it exists.
- Keep the controller pane separate from the delegated agent pane.
- Treat Herdr status as lifecycle evidence and terminal output as result
  evidence. Verify both before reporting success.
- Do not push, release, mutate external services, bypass permissions, or perform
  destructive work unless the user separately authorized it.

## Resolve the launch contract

Check the installed surfaces instead of relying on remembered flags:

```bash
herdr --version
herdr agent start --help
<agent-cli> --version
<agent-cli> --help
```

`herdr agent start --help` lists current `--kind` values. Common kinds include
`codex`, `claude`, `pi`, `gemini`, `cursor`, `opencode`, and `copilot`.

Map the user's requested model and reasoning words to exact installed CLI
values. Do not silently substitute a nearby model. If the requested value is
ambiguous or unavailable, show the live candidates and ask.

For Claude Code, inspect the installed CLI and auto-mode configuration:

```bash
claude --help
claude auto-mode --help
claude auto-mode config
```

Claude model and reasoning arguments:

```bash
--model MODEL_ID --effort EFFORT
```

Default to Claude's auto mode for delegated work:

```bash
--permission-mode auto
```

Auto mode uses Claude's permission classifier. Do not substitute
`bypassPermissions`. For Sonnet 5 at medium effort, use
`--model claude-sonnet-5 --effort medium --permission-mode auto`, after
re-checking the installed CLI because model IDs and modes can change.

For Codex, inspect the live model catalog and filter it before printing; the
raw catalog is large:

```bash
codex debug models | jq -r '.models[] | [.slug, .display_name, .default_reasoning_level] | @tsv'
codex debug models | jq '.models[] | select(.slug == "MODEL_SLUG") | {slug, display_name, default_reasoning_level, supported_reasoning_levels, service_tiers}'
```

Codex model and reasoning arguments:

```bash
--model MODEL_SLUG -c model_reasoning_effort=EFFORT
```

Example: resolve “Luna Light” live, then normally launch it as
`--model gpt-5.6-luna -c model_reasoning_effort=low`. Re-check the catalog in
every new session because slugs and availability can change.

Default to the current Codex CLI equivalent of “Approve for me”:

```bash
--sandbox workspace-write --ask-for-approval on-request
```

Resolve permissions separately from model choice and honor an explicit user
override. Do not substitute deprecated `--full-auto`. Never add
`--dangerously-bypass-approvals-and-sandbox` by default.

## Select or start the Herdr session

If `HERDR_ENV=1`, use the current session and omit `--session NAME` from Herdr
commands. List current objects before creating anything:

```bash
herdr workspace list
herdr pane list
```

If outside Herdr, proceed only because the user explicitly requested Herdr
delegation. List sessions, choose a unique task-specific name, and launch it in
a dedicated PTY:

```bash
herdr session list
herdr --session "$HERDR_SESSION_NAME"
```

Keep that PTY alive while controlling the session from another shell. Address
every control command explicitly:

```bash
herdr --session "$HERDR_SESSION_NAME" status --json
```

The exact named `status --json` result is authoritative. A sandboxed controller
may need approval to reach Herdr's local Unix socket; request access only for
the exact named session command. An unprivileged `session list` can incorrectly
look stopped when socket access is blocked.

## Create an isolated agent pane

Create a workspace without stealing focus and parse the returned pane ID:

```bash
WORKSPACE_JSON=$(herdr --session "$HERDR_SESSION_NAME" workspace create \
  --cwd "$TARGET_DIR" \
  --label "$WORKSPACE_LABEL" \
  --no-focus)
PANE_ID=$(printf '%s' "$WORKSPACE_JSON" | jq -r '.result.root_pane.pane_id')
```

Inside Herdr, use the same command without `--session "$HERDR_SESSION_NAME"`.

Always parse IDs from the current response. IDs such as `w2:p1` are live
session identifiers and can change after objects close; never guess or retain
them across topology changes.

`agent start` requires an existing pane sitting at an interactive shell prompt.
Launch the canonical agent kind and pass all agent-specific arguments after
`--`:

```bash
herdr --session "$HERDR_SESSION_NAME" agent start "$AGENT_NAME" \
  --kind "$AGENT_KIND" \
  --pane "$PANE_ID" \
  --timeout 30000 \
  -- <verified-agent-arguments>
```

Require the response to show:

- `interactive_ready: true`
- the requested `agent` kind and `name`
- an initial settled `agent_status`, normally `idle`
- the exact forwarded `argv`

For Codex Luna at low reasoning:

```bash
herdr --session "$HERDR_SESSION_NAME" agent start "$AGENT_NAME" \
  --kind codex \
  --pane "$PANE_ID" \
  --timeout 30000 \
  -- --model gpt-5.6-luna \
     -c model_reasoning_effort=low \
     --sandbox workspace-write \
     --ask-for-approval on-request
```

For Claude Sonnet 5 at medium effort:

```bash
herdr --session "$HERDR_SESSION_NAME" agent start "$AGENT_NAME" \
  --kind claude \
  --pane "$PANE_ID" \
  --timeout 30000 \
  -- --model claude-sonnet-5 \
     --effort medium \
     --permission-mode auto
```

## Prompt and wait

Check the agent before submitting. If it is already `working`, wait for that
turn or stop and clarify; `agent prompt --wait` does not isolate turns that were
already active.

```bash
herdr --session "$HERDR_SESSION_NAME" agent get "$AGENT_NAME"
herdr --session "$HERDR_SESSION_NAME" agent prompt "$AGENT_NAME" "$TASK_TEXT" \
  --wait \
  --timeout 30000
```

Pass task text as one safely quoted argument. Do not interpolate untrusted text
or secrets into a shell command. Use the harness's argument-safe execution
surface or a quoted variable for multiline prompts.

Without `--until`, `agent prompt --wait` settles on `idle`, `done`, or
`blocked`. This is usually safer across different agent UIs than requiring only
`done`. Herdr requires a state change within the first 5000 ms when submission
starts from a non-working state.

Timeout values are integer milliseconds, not durations such as `45s`. A timeout
does not cancel the agent. Continue with bounded waits:

```bash
herdr --session "$HERDR_SESSION_NAME" agent wait "$AGENT_NAME" \
  --timeout 30000
```

For a specific state, repeat `--until` as needed:

```bash
herdr --session "$HERDR_SESSION_NAME" agent wait "$AGENT_NAME" \
  --until done \
  --until blocked \
  --timeout 30000
```

Do not kill a quiet long-running agent merely because one bounded wait expired.

## Verify status and response

Cross-check the individual record, session inventory, and terminal transcript:

```bash
herdr --session "$HERDR_SESSION_NAME" agent get "$AGENT_NAME"
herdr --session "$HERDR_SESSION_NAME" agent list
herdr --session "$HERDR_SESSION_NAME" agent read "$AGENT_NAME" \
  --source recent-unwrapped \
  --lines 160 \
  --format text
```

Report:

- agent name, kind, pane, and `agent_session.value`
- exact model and reasoning shown in launch `argv` and the agent banner
- requested permission mode shown in launch `argv`; for Claude auto mode,
  cross-check the terminal indicator when visible
- observed settled state and, when useful, `state_change_seq`
- the requested result from the transcript

Do not report success from `done` alone. The agent can finish with an error,
refusal, or incomplete answer. Read the transcript.

Use detection diagnostics when state and visible output disagree:

```bash
herdr --session "$HERDR_SESSION_NAME" agent read "$AGENT_NAME" \
  --source detection \
  --lines 120 \
  --format text
herdr --session "$HERDR_SESSION_NAME" agent explain "$AGENT_NAME" \
  --json \
  --verbose
herdr --session "$HERDR_SESSION_NAME" pane read "$PANE_ID" \
  --source recent-unwrapped \
  --lines 160
```

`agent list` contains detected agents, not every shell pane.

## Follow up and handle blocking

Send follow-up work to the same named agent to retain its interactive context:

```bash
herdr --session "$HERDR_SESSION_NAME" agent prompt "$AGENT_NAME" "$FOLLOW_UP" \
  --wait \
  --timeout 30000
```

If status is `blocked`, read the transcript and surface the exact approval or
question to the user. Do not guess an answer, type arbitrary keys, or weaken
permissions. Resume only after the needed authority or input arrives.

For independent tasks, create separate workspaces or panes and unique agent
names. Start them independently, then wait/read each by name. Do not focus agent
panes merely to observe them.

## Clean up

Capture final status and output before cleanup.

If this workflow created a disposable named session, stop and delete only that
exact session unless the user asked to keep it:

```bash
herdr session stop "$HERDR_SESSION_NAME" --json
herdr session delete "$HERDR_SESSION_NAME" --json
herdr session list
```

`session stop` terminates every process in that session. `session delete`
removes the stopped Herdr session directory and terminal history. State this in
the handoff. It does not intentionally delete the delegated agent's own saved
conversation store.

If using a pre-existing session, do not stop it. Re-list current IDs, then close
only the workspace or pane created for this task when cleanup was authorized.

## Failure guide

- `Operation not permitted`: the controller cannot access the named Unix
  socket. Re-run the exact session-scoped command with narrow approval.
- `agent_prompt_stalled`: no detectable state change occurred within 5000 ms.
  Inspect `agent get`, `agent read`, and `agent explain`; the prompt may still
  be visible.
- `agent start` readiness failure: read the pane. The CLI may have rejected a
  model/flag or the pane may not have been at a shell prompt.
- Wrong model or reasoning in the banner: stop the task and correct the launch;
  do not accept `argv` alone as proof.
- `blocked`: preserve the pane and ask the user for the exact missing input or
  approval.
- Wait timeout while status remains `working`: keep the session, report
  progress, and continue bounded monitoring.
