---
name: snag
description: "Log a minor off-topic issue noticed mid-task (broken thing, wrong output shape, tooling friction) and keep going; or triage the logged list."
---

# Snag

Log-and-continue for small problems you notice while doing something else. The
list is reviewed later; logging is not a request to fix now.

Use when:

- Working on X, notice Y is broken, flaky, misleading, or awkward, and Y is not
  the task.
- A skill, script, pipeline stage, or harness produced the wrong shape/format
  but you could still proceed.
- The user says `snag …`, "log that", "note that for later", or `snag triage`.

Do not use for: blockers on the current task (fix or ask), findings the user
asked you to review, or anything already fixed in the same session.

## Logging

```sh
~/.agents/skills/snag/scripts/snag add -k KIND [-s SKILL] [-e EVIDENCE] [-f FIX] [-d DETAIL] "TITLE"
```

- `KIND`: `bug` (default), `tooling`, `skill`, `docs`, `process`, `env`.
- `-s`: skill name when the issue is in a skill's instructions or script.
- `-e`: command, file path, error line, or URL that reproduces/shows it.
- `-f`: one-line suggested fix if obvious.
- `-d -`: read a longer detail from stdin.
- Title: one specific sentence, stable wording. Same open title within 30 days
  bumps `seen` instead of adding a row, so repeated wording is the dedup key.

Harness and repo are auto-detected. Override with `SNAG_HARNESS`; attach
pipeline context with `SNAG_CONTEXT=run=<id>,stage=<name>`.

After logging: one short line to the user ("snagged: <title>"), then continue
the original task. Do not detour into fixing unless the fix is trivial and
in-scope.

## Triage (`snag triage`)

1. `snag ls` (open only; `--all` for everything, `--json` for tooling).
2. Group by `kind`/`skill`/repo. `seen` count first: repeated snags are the
   real signal.
3. Per group, propose one of: fix now (small, in this session), spin off as a
   separate task/handoff, or `wontfix`. Say why.
4. Apply status changes only after the user picks: `snag done ID`,
   `snag wontfix ID`, `snag reopen ID`.

## Reference

- Storage: `snag path` (default `~/.local/state/snag/snags.jsonl`, per machine).
- `snag show ID` prints the full record.
- Help: `~/.agents/skills/snag/scripts/snag --help`.
