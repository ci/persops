---
name: nix-flake-update
description: Update Nix flake inputs in persops. Use when asked to update flake.lock/inputs, update AI inputs (codex-cli-nix, claude-code-nix, llm-agents), or run full `nix flake update`, then verify with `nix flake check` and commit the update-only changes.
---

# Nix Flake Update

## Workflow

1. Decide scope
   - AI update: run `nix flake update codex-cli-nix claude-code-nix llm-agents`
   - Full update: run `nix flake update` (default when user does not mention AI)
2. Verify
   - Run `nix flake check`
   - If failure, quote exact error, fix only update-related fallout, rerun `nix flake check`
3. Commit
   - Stage only update-related files (typically `flake.lock`, maybe `flake.nix` or other necessary fixes)
   - Use Conventional Commit, keep commit isolated to the update
   - Examples: `chore(nix): update flake inputs` or `chore(nix): update ai inputs`

## Notes

- Work from repo root.
- Keep changes minimal; no unrelated refactors.
