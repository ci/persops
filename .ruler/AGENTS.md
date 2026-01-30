# persops - Nix-Based Dotfiles & System Configuration

Personal configuration managing macOS (darwin) and NixOS systems via Nix flakes.

## Commands

| Command | Purpose |
|---------|---------|
| `make switch` | Apply configuration (auto-detects darwin/nixos) |
| `make test` | Test build without applying |
| `nix flake check` | Validate flake syntax |
| `nix flake update` | Update all flake inputs |

## Ops Notes

- After changes to clawdbot config or skills synced to clawdbot, restart the gateway on amalthea: `systemctl --user restart clawdbot-gateway`
- After adding new files (before nix), run `jj status` to ensure files tracked
- VCS check: run `jj status` first (works from subdirs with .jj above) before assuming git

## Repository Structure

```
flake.nix           # Flake entry, inputs, system definitions
darwin.nix          # macOS-specific config
nixos.nix           # Linux-specific config
home.nix            # Home-manager entry (shared)
lib/mksystem.nix    # System builder helper
machines/           # Per-machine configs (aglaea=mac, amalthea=linux)
modules/            # Modular configurations
├── fish.nix, tmux.nix, nvim.nix, ...
├── nvim/lua/plugins/*.lua  # Neovim LazyVim plugins
├── git/, ai/, aerospace/, ...
```

## Nix Code Style

### Module Signature

```nix
{ pkgs, lib, config, ... }:   # Standard - destructure what you need
{ pkgs, user, self, ... }:    # With specialArgs
```

### Formatting

- 2-space indentation
- One attribute per line in sets
- One item per line in package lists

### Key Patterns

```nix
# Conditional packages by platform
{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin isLinux;
in {
  home.packages = with pkgs; [
    ripgrep
  ] ++ lib.optionals isDarwin [ mos ];
}

# Conditional config blocks
xdg.configFile."aerospace/aerospace.toml" = lib.mkIf isDarwin {
  source = ./aerospace.toml;
};

# External file references
extraConfig = builtins.readFile ./tmux/tmux.conf;
settings = pkgs.lib.importTOML ./starship.toml;

# JSON config generation
xdg.configFile."app/config.json".text = builtins.toJSON { key = "value"; };

# Package customization
(python314.withPackages (ps: with ps; [ requests pandas ]))
```

### Module Organization

- One tool/concern per module
- Use `imports = [ ]` to compose
- Store external configs (toml, conf) alongside .nix files
- Use `xdg.configFile` for dotfiles, `home.file` for home directory

### Comments

```nix
brews = [
  "libpq" # for ruby `pg` gems through mise
];
# TODO: pull this out into a shared file
# signal-desktop # broken in current version? mismatching sha
```

## Lua Code Style (Neovim)

LazyVim-based config in `modules/nvim/`. Formatter: stylua.

### Plugin Files

```lua
-- modules/nvim/lua/plugins/example.lua
return {
  "author/plugin-name",
  opts = {
    setting = value,
  },
}
```

### Patterns

```lua
-- Conditional logic
if vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
end

-- Type annotations for LSP
---@type snacks.dashboard.Item[]
keys = { ... }

-- Disable stylua for block
-- stylua: ignore
keys = { { icon = " ", key = "f" } }
```

## Common Tasks

### Add a Package

```nix
# In home.nix or module
home.packages = with pkgs; [ new-package ];
```

### Add npm CLI (no nodePackages)

- Use `buildNpmPackage` + npm tarball (`fetchurl`), vendor a `package-lock.json` next to the .nix, set `npmDepsHash`.
- Wrap entrypoint with `makeWrapper` to `dist/index.js` if needed (avoid `npm -g` installs).

### Add Homebrew Cask (macOS)

```nix
# In darwin.nix
homebrew.casks = [ "app-name" ];
```

### Add Fish Alias

```nix
# In modules/fish.nix
shellAliases = { myalias = "command --flags"; };
shellAbbrs = { abbr = "expanded"; };  # expands as typed
```

### Add New Machine

1. Create `machines/<name>.nix`
2. Add to `flake.nix`:

```nix
darwinConfigurations."<name>" = mkSystem "<name>" {
  system = "aarch64-darwin";
  user = "cat";
  darwin = true;
};
```

## Gotchas

- **Backups (restic/S3)**: `modules/backup/restic-darwin.nix` + `modules/backup/restic-nixos.nix` wired into aglaea/amalthea. Secrets live outside Nix store. Repo file + env + password:
  - macOS: `~/.config/restic/{repository,s3.env,password}`
  - NixOS: `/etc/secrets/restic/{repository,s3.env,password}`
  Schedules: hourly backup, daily prune, weekly check.
- **stateVersion**: Never change without reading release notes
- **Homebrew**: Some packages still via homebrew (see darwin.nix)
- **allowUnfree**: Enabled globally
- **tmuxinator**: Via homebrew, not nix (version compat)
- **Fish themes**: Catppuccin fetched from GitHub, pinned by sha256
