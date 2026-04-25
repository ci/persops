# persops - Personal OPS

dotfiles + nix setup + packages + configs

distro: OSX

## Updating Codex / Claude Code

Codex and Claude Code are provided via the `sadjow/codex-cli-nix` and `sadjow/claude-code-nix` overlays, which publish new versions hourly. Version is pinned to whatever commit is in `flake.lock`.

To pull the latest versions and deploy them:

```sh
nix flake update codex-cli-nix claude-code-nix
make switch
```

Can also just run `nix flake update` to refresh everything, then switch.

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
