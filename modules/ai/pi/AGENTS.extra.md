## Pi-only configuration

- Pi global config is managed from `~/p/persops` via Nix.
- Source of truth: `~/p/persops/modules/ai/pi/` plus wiring in `~/p/persops/modules/ai/home.nix`.
- Change Pi settings, extensions, prompts, themes, and this Pi-only note there; then run `cd ~/p/persops && make local`.
- Runtime files under `~/.pi/agent/` are generated mutable copies, not source of truth; differing generated files are backed up under `~/.pi/agent/backups/<timestamp>/` before overwrite.
- Keep secrets out of Nix/repo: use `~/.pi/agent/auth.json`, environment variables, or `op` commands.

<!-- BEGIN COMPOUND PI TOOL MAP -->
## Compound Engineering (Pi compatibility)

This block is managed by persops Nix from `modules/ai/pi/`.

Pi extensions used by this plugin:
- Required: `pi-subagents` provides the `subagent` tool used by skills that dispatch parallel agents.
- Recommended: `pi-ask-user` provides the `ask_user` tool; skills fall back to numbered options in chat when it is missing.

Installed through Nix-managed Pi settings/files, not `bunx`, so update `modules/ai/pi/{skills,agents,compound-engineering}` when bumping Compound Engineering.
<!-- END COMPOUND PI TOOL MAP -->
