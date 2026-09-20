---
name: snag
description: "Capture an actionable issue discovered outside the current task, save evidence, and continue without fixing it. Use for unrelated bugs, recurring tooling friction, and skill failures; also for snag triage. Exclude current-task blockers and requested review findings."
---

# Snag

Keep a durable inbox of observed problems without expanding the current task.
Capture issues outside the task's affected behavior or architectural owner;
continue authorized, bounded cleanup within that boundary normally. Severity
is independent of scope: flag serious unrelated findings prominently.

Use for an unrelated broken script, repeatable tooling friction, or a skill
failure that required a workaround. Skip ordinary transient failures, problems
already fixed in this session, current-task blockers, and requested review
findings. Generic notes, preferences, and reminders do not belong here.

## Capture

Run `scripts/snag` relative to **this skill's directory**, using its full resolved
path from any working directory. It requires Python 3.10+ (standard library only).
There is no assumed `snag` command on PATH. `$snag triage` invokes this skill;
the script's `triage` command provides the ranked inbox for that workflow.

```sh
<skill-dir>/scripts/snag add --key missing-json-output --impact medium \
  --source '<task URL or session ID>' -s example-skill \
  -e 'command, file:line, or concise observed error' 'Example skill emits prose instead of JSON'
```

- Record observed evidence, not a speculative improvement. Redact secrets from
  evidence and details; store a pointer rather than unrelated private content.
- Ownership defaults to `skill:NAME` with `-s`, otherwise `repo:REPO` detected
  from JJ/Git. Use `--owner` for a shared tool or another explicit owner;
  `--repo` overrides detection. Shared skill observations across repos belong
  together, while unrelated repo issues stay separate.
- Reuse a stable `--key` within that owner. Without one, the normalized title
  is the key. Match an existing open record when known; do not spend time
  investigating just to log. Open issues never age out of deduplication.
- Each add preserves evidence, details, suggested fix, repository, harness,
  source, and time. Reobserving a closed issue reopens the same ID with its
  history intact. Impact can increase on recurrence; it never silently drops.
- `--impact`: `high` for substantial breakage/risk, `medium` for repeatable
  friction or incorrect behavior, `low` for a minor nuisance. `-k` optionally
  categorizes as `bug`, `tooling`, `skill`, `docs`, `process`, or `env`.
- `--source` defaults to `SNAG_SOURCE` or `CODEX_THREAD_ID`. Supply the task/session
  reference when available; leave it unknown rather than inventing one.
  `SNAG_HARNESS` overrides session-marker detection (set it for Pi or unknown
  hosts); `SNAG_CONTEXT` adds optional run context.
- `-d -` reads longer details from stdin; `-f` records an obvious suggested fix.

After successful capture, tell the user briefly what was snagged and continue.
If storage, permissions, or tooling fail, mention that it was **not saved** and
continue; do not start a repair/approval detour just to maintain the inbox.
Logging is not authorization to fix the issue.

## Triage

Use the resolved script path for each command:

1. `triage` lists open issues by impact, distinct known source references, then
   last observation. `--owner OWNER` or `--repo REPO` filters the inbox;
   `show ID` displays all evidence. `SEEN` is raw observations, not independent
   occurrences: retries in one task count as one source; unknown sources add none.
2. Group related issues by owner. Assess impact and evidence as well as recurrence;
   suggest a bounded fix, a separate task/handoff, or dismissal, explaining why.
3. Apply `done ID`, `wontfix ID`, or `reopen ID` when authorized by the user.
   A triage request alone is read-only; an existing instruction to fix/close an
   issue is sufficient authorization. Do not request that permission twice.

Storage is **per machine**, at `path` (normally
`~/.local/state/snag/snags.sqlite3`; override with `SNAG_HOME` or `XDG_STATE_HOME`).
State which machine was reviewed; do not imply Aglaea's inbox includes Amalthea.
`ls --all --json` exports full records with observations; no synchronization or
external issue creation happens automatically. Nonempty legacy `snags.jsonl`
files cause a clear error until reviewed/migrated, rather than hiding old data.
