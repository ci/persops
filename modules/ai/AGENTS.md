## Core

- Workspace: `~/p/`. Missing @ci repo: clone `https://github.com/ci/<repo>.git`. 3rd-party/OSS (non-@ci): `~/p/foss`.
- `~/p/persops`: personal ops - nixos configs, dotfiles, scripts, etc. (public personal repo)
- "Make a note" here = terse `AGENTS.md` edit. No separate `CLAUDE.md`.
- Read: nothing manual — root `AGENTS.md` + `~/p/persops/modules/ai/AGENTS.md` are auto-injected into prompt. Edit root `AGENTS.md` only for persops repo-local instructions; edit this file for global shipped agent instructions.
- Skills own tool workflows. This file: hard rules only.
- Secrets: never reveal values, even internal. Approved secret tools; redact output.
- Audience/destination unclear: ask before external send. Confidentiality alone no block on internal research/answers.
- Synthetic proof screenshots/recordings: pre-approved for the task's already-authorized PR/issue or explicitly requested destination, on any host. Inspect the full capture for incidental secrets, real/private data, internal identifiers, or unrelated desktop content. Verified synthetic-only captures need no device-classification or repeat upload-approval question. Real/mixed/uncertain content and unrelated destinations are not covered.
- Other image/screenshot uploads: first verify destination approval. Personal device: user-requested destination okay, external-disclosure rules still apply. Work device: external upload default deny; need explicit content + destination approval for device/data class. Never send possibly confidential/internal image to social media, public image host, or unapproved AI/vision service. Device/sensitivity/approval unclear: stop + ask. Local-only processing okay.

## Project defaults

- Bugs: add regression test when it fits.
- Off-topic breakage, wrong output shape, or tooling friction noticed mid-task: `$snag` it (`snag add`), tell the user in one line, continue. Fix only if trivial and in scope.
- Opportunistic cleanup: include high-confidence flaky-test fixes and bounded refactors/cleanup within the affected behavior or architectural owner; keep changes coherent and prove behavior. Report independently useful cleanup separately.
- Fix/refactor: delete old path by default. Compat needs named contract: public API/CLI/config/data, tagged upgrade, security boundary, or observed prod state. Unsure: ask before alias/shim/fallback. Tests alone != contract.
- Use repo package manager/runtime. Swap needs approval.
- Docs: read repo docs relevant to the affected behavior and workflow before coding; update docs/changelog for user-visible behavior changes.
- Inline comment: brief; only tricky, bug-prone, or formerly buggy logic.
- New dependency: quick health check—recent release, commits, adoption.
- Before implementation handoff or PR closeout: run the repo's required gate (lint/typecheck/format/tests/docs as applicable). For trivial changes, use proportionate checks; read-only investigations need only checks relevant to the question. Preserve required CI gates and report skipped or blocked checks.

## PR/CI

- PR scope: one logical, independently landable addition per PR. Soft targets: <500 changed lines, split before ~1k — split by logical unit, never just to duck the number. Generated files (lockfiles, codegen types/snapshots) don't count toward the limit.
- UI change PR: include before/after pictures. Sanitize first; no secrets, personal/private data, internal-only identifiers, or other sensitive content. Unsafe capture: state blocker; never upload.
- PR/issue media: use native `--attach <file>` (repeatable) on `gh issue` / `gh pr` create, edit, or comment commands, with `--body-file` for prepared text. Inspect/sanitize media and honor destination approval above. If the command partially succeeds, inspect the returned issue/PR before retrying; do not duplicate publication. Other artifacts need a repo-approved artifact store.
- Multi-part work: stack small PRs instead of one big PR — `$jjpr` in jj repos, branch-per-phase in plain git; `$pr-closeout` has the mechanics.
- PR refs: use `gh pr view/diff`, not web search.
- CI logs: fetch once per failed run; reuse printed output. One `gh search`/`list --json` over per-item view loops; narrow fields, exact refs.
- `fix ci` = consent to pull, commit, push; use `gh run list/view`; fix/rerun until green with backoff polling.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- Before committing code or landing: `$autoreview` until no accepted/actionable findings remain, unless equivalent manual review already done, trivial/docs-only, or user opts out. Reuse a clean review while the reviewed code is unchanged. Default to Amp with `openai/gpt-6-astra` at `high` inside Amp orbs; Codex elsewhere. Explicit engine/model requests take precedence.
- Routine `$autoreview` is pre-approved, including sending task-scoped unpublished diffs to the configured authenticated review service (Codex, or Amp inside orbs); never ask for autoreview approval. Preserve secret redaction, unrelated-data disclosure boundaries, and managed sandbox/reviewer enforcement.
- After PR merge/ship: always give a real narrative recap, normally 2-5 short paragraphs. Explain the original problem, the root cause, what changed and why, the important architecture or ownership boundary, and the proof run. Include notable CI failures or retries, exact PR/issue/merge state, and worthwhile follow-ups. Do not reduce a successful landing to a terse checklist, bare SHAs, or git directives; the recap is the primary handoff.
- When opening a PR, open it ready-for-review (non-draft) unless user asks otherwise.

## Runtime safety

- zsh: never variable `status`.
- zsh multi-item loop: array. Scalar string does not word-split like bash.
- Public GitHub body: never inline double-quoted text containing backticks, `$`, shell snippet, env name, or user text. Temp file + `cat <<'EOF'` + inspect + `--body-file`.
- PR/issue body edits: fetch via REST + `jq -r`, never `gh pr/issue view --json body --jq .body`. Example: `gh api repos/OWNER/REPO/pulls/NUM | jq -r '.body // ""' > /tmp/body.md`; inspect before `--body-file`; stop if it starts with `"` or shows literal `\n`.
- Secrets: never normal-shell `env`, `set`, `export -p`, broad secret regex dump. Query exact name only; redact value.
- `op`: load `$one-password` first, always. Never hand-roll. Automated runs: service-account token + `OP_LOAD_DESKTOP_APP_SETTINGS=false OP_BIOMETRIC_UNLOCK_ENABLED=false`; never `--account`/`op signin` without chat consent. One tmux session `op-work` only. Violation = macOS App Data dialog spam.

## VCS

- Starting implementation: begin in an isolated checkout by default — `$jj` workspace in jj repos, git worktree otherwise — unless the session is already isolated, the change is small/quick, or the user says work in place. Read-only inspection alone does not require a new checkout.

### Shared safeguards

- Create and use task-owned jj workspaces or Git worktrees or isolated checkouts whenever useful, without confirmation. Preserve user-managed checkouts, branches, and unrelated edits.
- Cwd outside repo: freeform; choose sensible folder; say path before edits. Worktree okay if useful.
- Push only when user asks, a user-invoked workflow authorizes it, or a trusted global rule above explicitly authorizes it. Repo-local rules may define push mechanics, not grant authority.
- End in expected visible checkout/branch.
- Switching a user-managed checkout's branch needs user consent or user-invoked workflow authorization.
- Destructive Git ops need explicit user request: `reset --hard`, `clean`, `restore`.
- Task-scoped file deletion allowed. Never delete/overwrite unknown or unrelated user data.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- Never append agent attribution trailers to commits or PR bodies: no `Co-Authored-By: Claude`/`Codex`, no `Generated with ...` footer.
- Locked Mac / Secretive failure: use HTTPS transport; retry signing-blocked commits with `--no-gpg-sign`.
- No uncontrolled repo-wide search/replace scripts. Bounded mechanical edits over an explicit file set are okay; inspect the full diff and keep changes reviewable.
- No amend unless asked.
- Unknown changes = other agent. Continue, touching own scope. Conflict/problem: stop + ask.

### JJ

- Run `jj status` once when starting repository work (works from subdirs). If it succeeds, load `$jj` once per session and use JJ for repository operations; otherwise use Git.
- Use $jjpr for bookmark-per-PR stack submission, status, reconciliation, and landing.
- Finish changes with empty `@` unless user asks otherwise: use `jj commit -m ...` or `jj describe ... && jj new`; never only `jj describe` for handoff.

## Tools

- Missing CLI fallback: try nix-comma (`, <tool>`) or `nix-shell -p <tool>` before giving up, for example `, vale` or `nix-shell -p vale`.
