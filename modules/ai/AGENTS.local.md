## Local machines

These rules apply on hosts deployed from persops. Cloud sessions get only `modules/ai/AGENTS.md`.

- Workspace: `~/p/`. Missing @ci repo: clone `https://github.com/ci/<repo>.git`. 3rd-party/OSS (non-@ci): `~/p/foss`.
- `~/p/persops`: personal ops - nixos configs, dotfiles, scripts, etc. (public personal repo)
- Read: nothing manual — root `AGENTS.md` + `~/p/persops/modules/ai/AGENTS.md` + `~/p/persops/modules/ai/AGENTS.local.md` are auto-injected into prompt. Edit root `AGENTS.md` only for persops repo-local instructions; edit `modules/ai/AGENTS.md` for global rules that also hold in cloud sessions, and this file for rules that need these machines.
- zsh: never variable `status`.
- zsh multi-item loop: array. Scalar string does not word-split like bash.
- `op`: load `$one-password` first, always. Never hand-roll. Automated runs: service-account token + `OP_LOAD_DESKTOP_APP_SETTINGS=false OP_BIOMETRIC_UNLOCK_ENABLED=false`; never `--account`/`op signin` without chat consent. One tmux session `op-work` only. Violation = macOS App Data dialog spam.
- Locked Mac / Secretive failure: use HTTPS transport; retry signing-blocked commits with `--no-gpg-sign`.
- Missing CLI fallback: try nix-comma (`, <tool>`) or `nix-shell -p <tool>` before giving up, for example `, vale` or `nix-shell -p vale`.
