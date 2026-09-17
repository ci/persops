## Core

- Workspace: `~/p/`. Missing @ci repo: clone `https://github.com/ci/<repo>.git`. 3rd-party/OSS (non-@ci): `~/p/foss`.
- `~/p/persops`: personal ops - nixos configs, dotfiles, scripts, etc. (public personal repo)
- "Make a note" here = terse `AGENTS.MD` edit. No separate `CLAUDE.md`.
- Read: nothing manual — root `AGENTS.md` + `~/p/persops/modules/ai/AGENTS.md` are auto-injected into prompt. Edit root `AGENTS.md` only for persops repo-local instructions; edit this file for global shipped agent instructions.
- Skills own tool workflows. This file: hard rules only.
- Secrets: never reveal values, even internal. Approved secret tools; redact output.
- Audience/destination unclear: ask before external send. Confidentiality alone no block on internal research/answers.
- Synthetic proof screenshots/recordings: pre-approved for the task's already-authorized PR/issue or explicitly requested destination, on any host. Inspect the full capture for incidental secrets, real/private data, internal identifiers, or unrelated desktop content. Verified synthetic-only captures need no device-classification or repeat upload-approval question. Real/mixed/uncertain content and unrelated destinations are not covered.
- Other image/screenshot uploads: first verify destination approval. Personal device: user-requested destination okay, external-disclosure rules still apply. Work device: external upload default deny; need explicit content + destination approval for device/data class. Never send possibly confidential/internal image to social media, public image host, or unapproved AI/vision service. Device/sensitivity/approval unclear: stop + ask. Local-only processing okay.

## Project defaults

- Bugs: add regression test when it fits.
- Opportunistic cleanup: include high-confidence flaky-test fixes and bounded nearby refactors/cleanup found during PR work; keep changes coherent and prove behavior.
- Fix/refactor: delete old path by default. Compat needs named contract: public API/CLI/config/data, tagged upgrade, security boundary, or observed prod state. Unsure: ask before alias/shim/fallback. Tests alone != contract.
- Use repo package manager/runtime. Swap needs approval.
- Docs: read repo docs before coding; update docs/changelog for user-visible behavior changes.
- Inline comment: brief; only tricky, bug-prone, or formerly buggy logic.
- New dependency: quick health check—recent release, commits, adoption.
- Before handoff: run full gate (lint/typecheck/format/tests/docs).

## PR/CI

- PR scope: one logical, independently landable addition per PR. Soft targets: <500 changed lines, split before ~1k — split by logical unit, never just to duck the number. Generated files (lockfiles, codegen types/snapshots) don't count toward the limit.
- UI change PR: include before/after pictures. Sanitize first; no secrets, personal/private data, internal-only identifiers, or other sensitive content. Unsafe capture: state blocker; never upload.
- PR/issue image upload: never computer use/browser. `curl -s "https://uploads.github.com/user-attachments/assets?name=<file>&content_type=<mime>&repository_id=$(gh api repos/<owner>/<repo> --jq .id)" -X POST -H "Authorization: Bearer $(gh auth token)" -H "Accept: application/json" --data-binary @<file>` → response `.url`: images embed as `![alt](url)`, video as a bare URL line so GitHub renders a player. Same CDN as drag-drop, inherits repo visibility, uploads are permanent. Images/video only (422 = bad type, 404 = bad repo id/no push); other artifacts or endpoint failure: prerelease asset or repo-approved artifact store.
- `gh --attach` (repeatable, on `gh issue|pr create|edit|comment`) supersedes that curl once shipped: unmerged as of gh 2.98.0 (`cli/cli#14186`), so feature-detect, never assume. `gh attach` is an unrelated extension (`enthus-appdev/gh-attach`): pushes repo blobs to `refs/uploads/`, 400s at ~60KB+. Never use it for proof media.
- gh reads: ALWAYS `--json <fields>`. Human-format `gh pr view/list/checks`, `run list`, bare `gh api graphql` delegate silently to real gh (GraphQL+core on personal token). Machine shapes ride the shared cache.
- `gh api --paginate` bypasses cache to real token; avoid unless full list truly needed.
- Multi-part work: stack small PRs instead of one big PR — `$jjpr` in jj repos, branch-per-phase in plain git; `$pr-closeout` has the mechanics.
- PR refs: use `gh pr view/diff`, not web search.
- CI logs: fetch once per failed run; reuse printed output. One `gh search`/`list --json` over per-item view loops; narrow fields, exact refs.
- `fix ci` = consent to pull, commit, push; use `gh run list/view`; fix/rerun until green with backoff polling.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- Pre-commit code changes: use `$autoreview` until no accepted/actionable findings remain, unless equivalent manual review already done, trivial/docs-only, or user opts out.
- Before every commit/land: `$autoreview` until no accepted/actionable finding, unless equivalent manual review already done, trivial/docs-only, or user opts out. Always prefer Codex for autoreview, independent of environment.
- Routine `$autoreview` is pre-approved, including sending task-scoped unpublished diffs to the configured authenticated Codex review service; never ask for autoreview approval. Preserve secret redaction, unrelated-data disclosure boundaries, and managed sandbox/reviewer enforcement.
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

- Starting work: begin in an isolated checkout by default — `$jj` workspace in jj repos, git worktree otherwise — unless the session is already isolated, the change is small/quick, or the user says work in place.

### Git

- Verify if jj exists before using git: `jj status` first (works from subdirs); use `jj` instead of `git` if it succeeds.
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
- No repo-wide search/replace scripts. Small reviewable edits.
- No amend unless asked.
- Unknown changes = other agent. Continue, touching own scope. Conflict/problem: stop + ask.

### JJ

- Always use jj if exists.
- Consult $jj skill once per session for context before usage if jj exists and using it.
- Use $jjpr for bookmark-per-PR stack submission, status, reconciliation, and landing.
- Finish changes with empty `@` unless user asks otherwise: use `jj commit -m ...` or `jj describe ... && jj new`; never only `jj describe` for handoff.

## Tools

- Missing CLI fallback: try nix-comma (`, <tool>`) or `nix-shell -p <tool>` before giving up, for example `, vale` or `nix-shell -p vale`.
