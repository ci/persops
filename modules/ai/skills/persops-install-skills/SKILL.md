---
name: persops-install-skills
description: "Add or update agent skills in ~/p/persops, including vendoring upstream skills into modules/ai/skills, choosing the right propagation profile (`all`, `coding`, `claw`, `codex`), updating metadata, and applying local+remote Nix switches. Use when the user asks to add a skill, install a skill, update a skill, make a coding skill, make a Codex-only skill, or make a claw/openclaw/clawdbot-only skill in persops."
---

# Persops Install Skills

Use this workflow for skills managed in `~/p/persops/modules/ai/skills`.

## Profile Mapping

- Default to `all`: publish to `.claude/skills`, `.agents/skills`, `.openclaw/skills`, and `.pi/agent/skills`.
- Use `coding`: publish to `.claude/skills`, `.agents/skills`, and `.pi/agent/skills` only.
- Use `claw`: publish to `.openclaw/skills` only.
- Use `codex`: publish to `.agents/skills` only.
- Interpret `claw skill`, `openclaw skill`, or `clawdbot skill` as `claw`.

## Workflow

1. Start with `jj status`, then inspect `modules/ai/home.nix`, `modules/ai/skill-overrides.json`, and any existing skill directory you might touch.
2. For new upstream skills, run `modules/ai/scripts/add-skill.sh [--profile <all|coding|claw|codex>] <source> [skills-add args...]`.
   - Example: `modules/ai/scripts/add-skill.sh https://github.com/vercel-labs/skills --skill find-skills`
   - Direct GitHub `blob` / `tree` skill URLs work too; the helper infers the single skill name and vendors only that skill.
3. Review the vendored files under `modules/ai/skills/<name>/`. Keep repo-owned truth there and verify `UPSTREAM.txt`.
4. If the profile is not default `all`, update `modules/ai/skill-overrides.json`. Use it for `coding`, `claw`, `codex`, or other per-skill exceptions like `recursive = true`.
5. If you create or update a repo-local skill, keep `SKILL.md` concise, keep `agents/openai.yaml` aligned, and validate the skill with `uv run --with pyyaml python3 /Users/cat/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>`.
6. Run the local and remote apply loop:
   - `make switch`
   - `make r/apply`
7. Verify the expected symlinks locally and on `amalthea`:
   - `~/.claude/skills/<name>` when profile includes Claude
   - `~/.agents/skills/<name>` when profile includes Codex/Agents
   - `~/.openclaw/skills/<name>` when profile includes Claw
   - `~/.pi/agent/skills/<name>` when profile includes Pi
8. Commit changes at the end after verification. Use a Conventional Commit. Do not push unless the user asks.

## Notes

- `Makefile` uses `path:` flake refs so freshly added uncommitted skill files are visible to local rebuilds.
- Do a quick upstream health check before vendoring external skills, for example `gh repo view <owner/repo> --json pushedAt,stargazerCount,url`.
- If the user asks for claw-only propagation, do not also wire Claude or Codex.
