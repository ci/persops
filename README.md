# persops - Personal OPS

dotfiles + nix setup + packages + configs

distro: OSX

## Updating AI Packages

Codex, Claude Code, and Pi-related agent packages are pinned through flake inputs.

To pull the latest AI versions and deploy them:

```sh
nix flake update codex-cli-nix claude-code-nix llm-agents
make local
```

Can also run `nix flake update` to refresh everything, then switch.

When Pi changes version, update `modules/ai/pi/settings.json` `lastChangelogVersion` to the new `pi --version 2>&1`, read Pi's installed `CHANGELOG.md`, and summarize the skipped Pi changelog entries in the handoff. This keeps Pi from showing the same changelog on every startup while still surfacing the news once during the update.

## Devbox AI sync

Personal Coder devboxes can be bootstrapped with local AI/editor config without changing the shared Coder template. This ensures `gh`, syncs Pi settings/extensions/skills/agents, Codex and Claude global instructions/skills, Agent Skills, and nvim. The nvim sync installs/uses snap nvim, maps `vi`/`vim` to nvim, disables SuperMaven only on the devbox, and warms Lazy/Mason/Tree-sitter:

```sh
scripts/devbox-sync-ai --start              # default devbox
scripts/devbox-sync-ai api                  # labeled devbox
scripts/devbox-sync-ai coder.devbox-catalini # explicit SSH host
scripts/devbox-sync-ai --dry-run            # print actions only
scripts/devbox-sync-ai --with-auth          # opt-in Pi auth.json copy
```

The script intentionally skips auth, sessions, history, caches, logs, and machine-local state. Pi auth is copied only with `--with-auth`.

## Adding AI Skills

Repo-owned skills live in `modules/ai/skills/*` and propagate from Nix into local agent dirs.

Default flow:

```sh
modules/ai/scripts/add-skill.sh shadcn/ui
make switch
make r/copy
make r/switch
```

Profiles:

- default `all`: Claude + Codex + OpenClaw + Pi
- `--profile coding`: Claude + Codex + Pi only
- `--profile claw`: OpenClaw only

Example:

```sh
modules/ai/scripts/add-skill.sh --profile coding vercel-labs/agent-skills
modules/ai/scripts/add-skill.sh --profile claw owner/repo
modules/ai/scripts/add-skill.sh https://github.com/vercel-labs/skills --skill find-skills
modules/ai/scripts/add-skill.sh https://github.com/openai/skills/blob/main/skills/.curated/playwright-interactive
```
