# Pi config

Source of truth for global Pi agent config.

- `settings.json` -> `~/.pi/agent/settings.json`
- `AGENTS.extra.md` -> appended only to Pi's `~/.pi/agent/AGENTS.md`
- `extensions/` -> copied to `~/.pi/agent/extensions/`
- `prompts/` -> copied to `~/.pi/agent/prompts/`
- `themes/` -> copied to `~/.pi/agent/themes/`

Files are copied during `make local` so Pi can mutate them at runtime. Persist intended changes here, then rerun `make local`.

On `make local`, generated files overwrite runtime copies. If a runtime file with the same path differs, the activation script first backs it up under `~/.pi/agent/backups/<timestamp>/`. Extra runtime files not present here are left alone.

Keep secrets out of this tree; use `~/.pi/agent/auth.json`, env vars, or `op` commands.
