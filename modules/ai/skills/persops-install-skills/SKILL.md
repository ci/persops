---
name: persops-install-skills
description: "Add, update, or remove agent skills in ~/p/persops: vendor upstream skills into modules/ai/skills, pick the propagation profile (`all` or `codex`), keep the plugin marketplace in sync, and deploy. Use when the user asks to add, install, update, drop, or rename a skill in persops."
---

# Persops Install Skills

Skills live in `~/p/persops/modules/ai/skills/<name>/`. Nix links each one into
the agent skill dirs; `.claude-plugin/marketplace.json` ships a subset to
claude.ai and cloud sessions as plugins.

## Where a skill goes

- Profile (`modules/ai/skill-overrides.json`, default `all`):
  - `all`: `~/.claude/skills`, `~/.agents/skills`, `~/.pi/agent/skills`.
  - `codex`: `~/.agents/skills` only. Use when the user asks for Codex-only.
  - Other per-skill keys: `recursive = true`.
- Host gating (`modules/ai/home.nix`): `personalOnlySkills` stay off ergane;
  `darwinOnlySkills` stay off amalthea.
- Marketplace plugin (`.claude-plugin/marketplace.json`):
  - `persops`: general thinking, review, writing, PR workflow.
  - `persops-web`: TypeScript, React, TUI frameworks.
  - `persops-jj`: jj workflows.
  - Leave out machine-only skills (they need local tools, secrets, or hosts:
    one-password, share-page, rex, session-viewer, persops-install-skills).
  - Every plugin entry keeps `"strict": false` (no plugin.json; claude.ai sync
    rejects entries without it).

## Add

1. `jj status`, then read `modules/ai/home.nix`, `skill-overrides.json`, the
   marketplace, and any skill dir you will touch.
2. Health-check upstream (`gh repo view <owner/repo> --json pushedAt,stargazerCount,url`).
3. `modules/ai/scripts/add-skill.sh [--profile all|codex] <source> [skills-add args...]`
   - Example: `modules/ai/scripts/add-skill.sh https://github.com/shadcn/ui --skill shadcn`
   - GitHub `blob`/`tree` URLs must point at a skill dir or its `SKILL.md`; the
     helper pins the commit and records it in `UPSTREAM.txt`.
   - It refuses the whole batch if any destination exists; update existing
     skills by hand.
4. Review the vendored files and `UPSTREAM.txt`. Record local edits there as
   `local_patch_<date> = ...`.
5. Add the skill to the right marketplace plugin, or note why it is
   machine-only.

## Update, remove, rename

- Edit in place and log the change in `UPSTREAM.txt`. Keep `agents/openai.yaml`
  in step with `SKILL.md`.
- Removing: delete the dir, its `skill-overrides.json` entry, its marketplace
  path, and any host-gating list entry. `rg '<name>'` across the repo for
  links from other skills (`../<name>/...`, `$<name>`) and fix them.
- Renaming: same as remove + add; update the `name:` frontmatter.

## Verify and deploy

1. `python3 -m json.tool .claude-plugin/marketplace.json >/dev/null` and check
   every marketplace path exists.
2. `make check`.
3. `make deploy TARGETS="aglaea amalthea"` (never ergane unless asked).
4. Check the links on each host: `~/.claude/skills/<name>`,
   `~/.agents/skills/<name>`, `~/.pi/agent/skills/<name>` (only the dirs its
   profile includes; a removed skill should be gone from all three).
5. Commit with a Conventional Commit. Push or PR only when asked.

`make deploy` snapshots a `path:` flake, so uncommitted new skill files deploy
consistently on every target.
