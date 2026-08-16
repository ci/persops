# persops - Personal OPS

dotfiles + nix setup + packages + configs

distro: OSX

## Deployment

`make deploy` snapshots and checks the current flake before switching any target.
Aglaea can deploy itself locally and Amalthea remotely; Amalthea can deploy only
itself until remote SSH deployment is enabled on Aglaea.

```sh
make deploy                                  # host defaults
make deploy TARGETS=amalthea
make deploy TARGETS=aglaea                   # run on aglaea
make deploy TARGETS="aglaea amalthea"        # run on aglaea
```

Amalthea is always deployed and verified before a selected Aglaea switch so a
controller restart cannot interrupt remaining remote work. From an Amp orb,
delegate to the Aglaea runner for both targets or the Amalthea runner for
Amalthea only.

## Updating AI Packages

Codex, Claude Code, and Pi-related agent packages are pinned through flake inputs.

To pull the latest AI versions and deploy them:

```sh
nix flake update codex-cli-nix claude-code-nix llm-agents
make local
```

## Ops status

`ops-status` prints a local health summary for the current machine: Nix, `persops`
VCS state, Restic, Time Machine, Tailscale, desktop services, and Linux systemd
services where available. Use `ops-status --remote` for a small read-only
`amalthea` SSH probe.

Can also run `nix flake update` to refresh everything, then switch.

When Pi changes version, update `modules/ai/pi/settings.json` `lastChangelogVersion` to the new `pi --version 2>&1`, read Pi's installed `CHANGELOG.md`, and summarize the skipped Pi changelog entries in the handoff. This keeps Pi from showing the same changelog on every startup while still surfacing the news once during the update.

## Adding AI Skills

Repo-owned skills live in `modules/ai/skills/*` and propagate from Nix into local agent dirs.

Default flow:

```sh
modules/ai/scripts/add-skill.sh shadcn/ui
make deploy
```

Profiles:

- default `all`: Claude + Codex + OpenClaw + Pi
- `--profile coding`: Claude + Codex + Pi only
- `--profile claw`: OpenClaw only
- `--profile codex`: Codex only

Example:

```sh
modules/ai/scripts/add-skill.sh --profile coding vercel-labs/agent-skills
modules/ai/scripts/add-skill.sh --profile claw owner/repo
modules/ai/scripts/add-skill.sh --profile codex owner/repo
modules/ai/scripts/add-skill.sh https://github.com/vercel-labs/skills --skill find-skills
modules/ai/scripts/add-skill.sh https://github.com/openai/skills/blob/main/skills/.curated/playwright-interactive
```
