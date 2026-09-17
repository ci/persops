## Pi-only configuration

- Pi global config is managed from `~/p/persops` via Nix.
- Source of truth: `~/p/persops/modules/ai/pi/` plus wiring in `~/p/persops/modules/ai/home.nix`.
- Change Pi settings, extensions, prompts, themes, and this Pi-only note there; then run `cd ~/p/persops && make local`.
- Runtime files under `~/.pi/agent/` are generated mutable copies, not source of truth; differing generated files are backed up under `~/.pi/agent/backups/<timestamp>/` before overwrite.
- Keep secrets out of Nix/repo: use `~/.pi/agent/auth.json`, environment variables, or `op` commands.
