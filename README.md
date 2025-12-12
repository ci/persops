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
