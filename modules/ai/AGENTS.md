# AGENTS.MD

Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Agent Protocol

- Contact: Catalin Irimie (@ci on GitHub, @ca7ir on X, <catalin.irimie@gmail.com>).
- Workspace: `~/p/`. Missing @ci repo: clone `https://github.com/ci/<repo>.git` (use ssh).
- 3rd-party/OSS (non-ci): clone under `~/p/foss`.
- `~/p/persops`: private ops - nixos configs, dotfiles, scripts, etc.
- PRs: use `gh pr view/diff` (no URLs).
- “Make a note” => edit AGENTS.md (shortcut; not a blocker). Ignore `CLAUDE.md`.
- Read: nothing manual — generated `AGENTS.md` (root) + `~/p/persops/modules/ai/AGENTS.md` are auto-injected into prompt. Edit: touch `.ruler/*.md` only when updating/regenerating AGENTS; then run `bunx @intellectronica/ruler apply`.
- Bugs: add regression test when it fits.
- Keep files <~500 LOC; split/refactor as needed.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- Editor: `vi <path>`.
- CI: `gh run list/view` (rerun/fix til green).
- Prefer end-to-end verify; if blocked, say what’s missing.
- New deps: quick health check (recent releases/commits, adoption).
- Style: telegraph. Drop filler/grammar. Min tokens (global AGENTS + replies).

## Docs

- Start: look through existing docs/*; open docs before coding when name matches what you're working on.
- Follow links until domain makes sense; honor `Read when` hints.
- Keep notes short; update docs when behavior/API changes (no ship w/o docs).
- Add `read_when` hints on cross-cutting docs.

## PR Feedback

- Replies: cite fix + file/line; resolve threads only after fix lands.

## Flow & Runtime

- Use repo’s package manager/runtime; no swaps w/o approval.
- Use Codex background for long jobs; tmux only for interactive/persistent (debugger/server).
- Passwords/secrets: `op`/1Password CLI must always run inside `tmux`, never directly.
- `op` recipe: run the whole secret-using command in `tmux`; avoid temp files unless needed, delete after.

## Build / Test

- Before handoff: run full gate (lint/typecheck/format/tests/docs).
- CI red: `gh run list/view`, rerun, fix, push, repeat til green.
- Release: read `docs/RELEASING.md` (or find best checklist if missing).

## VCS

### Git

- IMPORTANT: run `jj status` first (works from subdirs); use `jj` instead of `git` if it succeeds.
- Safe by default: `git status/diff/log`. Push only when user asks.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, …).
- Don’t delete/rename unexpected stuff; stop + ask.
- No repo-wide S/R scripts; keep edits small/reviewable.
- Avoid manual `git stash`; if Git auto-stashes during pull/rebase, that’s fine (hint, not hard guardrail).
- If user types a command (“pull and push”), that’s consent for that command.
- No amend unless asked.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.

### JJ

- IMPORTANT: run `jj status` first (works from subdirs); use `jj` if it succeeds.
- consult jj skill once per session for context before usage.

## Tools

### agent-browser

- Use `agent-browser` for browser-specific tasks: navigate sites, click/fill forms, screenshots, scrape page data, test web apps, logins, browser automation.
- Start with `agent-browser skills get core` (or `--full`) for version-matched workflow docs.

### gh

- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.
- Examples: `gh issue view <url> --comments -R owner/repo`, `gh pr view <url> --comments --files -R owner/repo`.

### tmux

- Use only when you need persistence/interaction (debugger/server).
- Quick refs: `tmux new -d -s codex-shell`, `tmux attach -t codex-shell`, `tmux list-sessions`, `tmux kill-session -t codex-shell`.

## Behavioral guidelines

### Think before coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Simplicity first

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### Goal-driven execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
