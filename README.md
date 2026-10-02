# persops - Personal OPS

dotfiles + nix setup + packages + configs

distro: OSX

## Deployment

`make deploy` snapshots and checks the current flake before switching any target.
Aglaea can deploy itself locally and Amalthea remotely; Amalthea can deploy only
itself until remote SSH deployment is enabled on Aglaea. Ergane deploys only
itself, and no other host can deploy it.

```sh
make deploy                                  # host defaults
make deploy TARGETS=amalthea
make deploy TARGETS=aglaea                   # run on aglaea
make deploy TARGETS="aglaea amalthea"        # run on aglaea
make deploy TARGETS=ergane                   # run on ergane
```

`make switch` picks the Darwin config named after `hostname -s` and refuses
unknown hosts.

Amalthea is always deployed and verified before a selected Aglaea switch so a
controller restart cannot interrupt remaining remote work. From an Amp orb,
delegate to the Aglaea runner for both targets or the Amalthea runner for
Amalthea only. Aglaea health warnings (exit 1) are reported without failing a
successful activation; health failures (exit 2 or unexpected errors) still fail
the deployment.

## Ergane (work Mac)

Ergane uses the `work` profile (`lib/mksystem.nix`): core CLI and language
toolchains, coding agents, Slack, and work-safe casks. Personal apps, CTF/media tooling, and the extra language stacks stay on
the `personal` profile. It is isolated from personal infrastructure: no persops
vault token or home secrets (enforced by an assertion), restic, Tailscale,
`amalthea` SSH entry, Atuin sync, `share-page` skill, or remote targets.
Neovim skips Supermaven cloud completion there (`vim.g.persops_profile`).

Homebrew on ergane is fully declarative: a switch uninstalls any formula or cask
not declared in `darwin.nix` or `machines/ergane.nix`. Commits are signed with
the Secretive key `ergane-sign`; pushes authenticate through the 1Password SSH
agent.

First switch on a fresh Mac:

1. Install upstream Nix (multi-user). nix-darwin manages Nix here, as on
   aglaea, so don't install Determinate Nix.
2. Hand apps that were installed outside Homebrew over to their casks, e.g.
   `brew install --cask --adopt claude`, or move the app to the Trash first.
3. Run the first switch with nix-darwin pinned by this flake. It also sets the
   hostname, so later runs are plain `make switch` or `make deploy`:

   ```sh
   sudo nix --extra-experimental-features 'nix-command flakes' \
     run --inputs-from ~/p/persops nix-darwin#darwin-rebuild -- \
     switch --flake ~/p/persops#ergane
   ```

   If activation stops on unrecognized files in `/etc`, rename them with the
   `.before-nix-darwin` suffix it suggests and rerun.

Never copy the `persops-opnix` token to ergane.

AeroSpace is installed through Homebrew only. Nix manages its configuration and
zen-toggle script, which calls the Homebrew CLI. After a Homebrew AeroSpace
upgrade, restart `/Applications/AeroSpace.app` to keep the server and CLI matched.

## Updating AI Packages

Codex, Claude Code, and Pi-related agent packages are pinned through flake inputs.

To pull the latest AI versions and deploy them:

```sh
nix flake update codex-cli-nix claude-code-nix llm-agents
make local
```

## Host secrets

Host secrets come from the shared `persops` 1Password vault through opnix; see
[docs/secrets.md](docs/secrets.md).

## Ops status

`ops-status` prints a local health summary for the current machine: Nix, `persops`
VCS state, Restic, Time Machine, Tailscale, desktop services, and Linux systemd
services where available. Use `ops-status --remote` for a small read-only
`amalthea` SSH probe. On Aglaea, Storage Box client readiness is separate from
the S3 home-backup jobs. Appended Restic stderr is diagnostic history; launchd
exit codes and log freshness determine the reported job health. Missing or failed
Aglaea backup jobs, an unavailable Nix daemon, and broken Tailscale are failures
(exit 2). Stale diagnostics, desktop issues, and checks without a completed run
are warnings (exit 1). Restic jobs wait up to two hours for a repository lock
when another backup or maintenance operation is active.

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

- default `all`: Claude + Codex + Pi
- `--profile coding`: Claude + Codex + Pi only
- `--profile codex`: Codex only

Example:

```sh
modules/ai/scripts/add-skill.sh --profile coding vercel-labs/agent-skills
modules/ai/scripts/add-skill.sh --profile codex owner/repo
modules/ai/scripts/add-skill.sh https://github.com/shadcn/ui --skill shadcn
modules/ai/scripts/add-skill.sh https://github.com/openclaw/agent-skills/tree/main/skills/session-viewer
```

Direct GitHub `tree`/`blob` links must select a skill directory or its `SKILL.md`.
The importer uses `gh` to resolve the branch, tag, or commit (including refs with
slashes), pins installation to that commit, and records the revision and path in
`UPSTREAM.txt`. Existing skill names are rejected across the entire batch before
any copying or profile changes; updating existing skills remains a separate edit.

Removed shared skills are unlinked by Home Manager on the next deployment. The
retired Pi Compound Engineering bundle (`ce-*`, its `lfg` launcher, and companion
agents) is moved out of active discovery into `~/.pi/agent/backups/` during
activation, preserving mutable local copies.
