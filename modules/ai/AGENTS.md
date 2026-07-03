Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Core

- Workspace: `~/p/`. Missing @ci repo: clone `https://github.com/ci/<repo>.git` (use ssh). 3rd-party/OSS (non-ci): `~/p/foss`.
- `~/p/persops`: private ops - nixos configs, dotfiles, scripts, etc.
- “Make a note” => edit AGENTS.md (shortcut; not a blocker). Ignore `CLAUDE.md` (imports AGENTS.md; Claude-only extras live in `~/p/persops/modules/ai/CLAUDE.extra.md`).
- Read: nothing manual — root `AGENTS.md` + `~/p/persops/modules/ai/AGENTS.md` are auto-injected into prompt. Edit root `AGENTS.md` only for persops repo-local instructions; edit this file for global shipped agent instructions.
- Skills are canonical for tool-specific workflows. Keep this file to hard rules only.
- Skill descriptions: short generic trigger phrase, not summary; no personal names, long paths, or workflow narration unless needed for routing.
- Skill frontmatter: quote `description`; after SKILL.md edits, YAML-parse frontmatter before commit.

## Project defaults

- Bugs: add regression test when it fits.
- Fixes: prefer clean bounded refactor over tiny shim. Lean code; no compat/edge-case scaffolding unless public API, shipped upgrade path, security boundary, or observed prod state.
- Use repo package manager/runtime; no swaps without approval.
- Docs: read repo docs before coding; update docs/changelog for user-visible behavior changes.
- Inline code comments: brief notes for tricky, bug-prone, or previously buggy logic.
- New deps: quick health check (recent releases/commits, adoption).
- Before handoff: run full gate (lint/typecheck/format/tests/docs).

## PR/CI

- PR refs: use `gh pr view/diff`, not web search.
- CI: `gh run list/view`; rerun/fix until green when asked.
- `fix ci`: consent to pull, commit, push; fix/rerun/watch until CI green.
- Replies: cite fix + file/line; resolve threads only after fix lands.
- Pre-commit code changes: use `$autoreview` until no accepted/actionable findings remain, unless equivalent manual review already done, trivial/docs-only, or user opts out.
- When opening a PR, prefer draft unless user asks otherwise.

## Runtime safety

- Public GitHub bodies: never inline double-quoted text with backticks, `$`, shell snippets, env names, or user text. Use temp file + `cat <<'EOF'` + inspect + `--body-file`.
- PR/issue body edits: fetch via REST + `jq -r`, never `gh pr/issue view --json body --jq .body`. Example: `gh api repos/OWNER/REPO/pulls/NUM | jq -r '.body // ""' > /tmp/body.md`; inspect before `--body-file`; stop if it starts with `"` or shows literal `\n`.
- Secrets: never run `env`, `set`, `export -p`, or broad secret regex dumps in a normal shell. Query exact names only; redact values.

## VCS

### Git

- Verify if jj exists before using git: `jj status` first (works from subdirs); use `jj` instead of `git` if it succeeds.
- Branch switch/checkout ok when task needs it and repo rules allow.
- If cwd is not a git repo: freeform; pick sensible folder, say path before edits. Worktrees ok if useful.
- Safe by default: `git status/diff/log`.
- Push only when user asks.
- Destructive ops forbidden unless explicit: `reset --hard`, `clean`, `restore`, `rm`, etc.
- Prefer HTTPS for pull/fetch when public.
- Commits: Conventional Commits (`feat|fix|refactor|build|ci|chore|docs|style|perf|test`).
- No repo-wide S/R scripts; keep edits small/reviewable.
- If user types a command ("pull and push"), that's consent for that command.
- No amend unless asked.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.

### JJ

- Always use jj if exists.
- Consult $jj skill once per session for context before usage if using jj.
- Finish changes with empty `@` unless user asks otherwise: use `jj commit -m ...` or `jj describe ... && jj new`; never only `jj describe` for handoff.

## Tools

- Missing CLI fallback: try nix-comma (`, <tool>`) or `nix-shell -p <tool>` before giving up, for example `, vale` or `nix-shell -p vale`.

### agent-browser

- Use `agent-browser` for browser-specific tasks: navigate sites, click/fill forms, screenshots, scrape page data, test web apps, logins, browser automation.
- Start with `agent-browser skills get core` (or `--full`) for version-matched workflow docs.

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
