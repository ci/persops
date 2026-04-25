---
name: nix-flake-update
description: Update Nix flake inputs in persops. Use when asked to update flake.lock/inputs, update AI inputs (codex-cli-nix, claude-code-nix, llm-agents), or run full `nix flake update`, then verify with `nix flake check` and commit the update-only changes.
---

# Nix Flake Update

## Workflow

1. Decide scope
   - AI update: run `nix flake update codex-cli-nix claude-code-nix llm-agents`
   - Full update: run `nix flake update` (default when user does not mention AI)
2. Switch
   - Run `make local` after any update
3. Handle Pi changelog once
   - Run `pi --version 2>&1` once after switching.
   - Compare it with `modules/ai/pi/settings.json` `lastChangelogVersion`.
   - If different, bump `lastChangelogVersion` to the current Pi version, read installed Pi `CHANGELOG.md`, and summarize entries between the old and new versions in the handoff.
   - If already equal, say no Pi changelog news.
4. Verify (full updates only)
   - Run `nix flake check`
   - If failure, quote exact error, fix only update-related fallout, rerun `nix flake check`
5. Commit
   - Stage only update-related files (typically `flake.lock`, `modules/ai/pi/settings.json` when Pi changed, maybe `flake.nix` or other necessary fixes)
   - Use Conventional Commit, keep commit isolated to the update
   - Examples: `chore(nix): update flake inputs` or `chore(nix): update ai inputs`

## Notes

- Skip `nix flake check` when updating **AI** inputs (unless explicitly requested).
- Bumping Pi `lastChangelogVersion` is intentional when Pi updates; do not leave repeated startup changelog prompts for the user.
- Work from repo root.
- Keep changes minimal; no unrelated refactors.
