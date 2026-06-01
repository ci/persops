{
  description = "persops";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Master nixpkgs is used for really bleeding edge packages. Warning
    # that this is extremely unstable and shouldn't be relied on. Its
    # mostly for testing.
    nixpkgs-master.url = "github:nixos/nixpkgs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-snapd = {
      url = "github:nix-community/nix-snapd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jj-starship = {
      url = "github:dmmulroy/jj-starship";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux-sessionizer = {
      url = "github:jrmoulton/tmux-sessionizer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-steipete-tools = {
      url = "github:clawdbot/nix-steipete-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jujutsu.url = "github:jj-vcs/jj";
    zig.url = "github:mitchellh/zig-overlay";
    flox = {
      url = "github:flox/flox/latest";
    };
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, ... }@inputs:
    let
      overlays = [
        inputs.jujutsu.overlays.default
        inputs.zig.overlays.default
        inputs."codex-cli-nix".overlays.default
        inputs."claude-code-nix".overlays.default
        inputs.jj-starship.overlays.default
        inputs.tmux-sessionizer.overlays.default
        (_: prev: {
          # pipx 1.8.0 tests still expect old direct-URL specifier spacing.
          pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
            (_: pyPrev: {
              pipx = pyPrev.pipx.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [
                  "test_fix_package_name"
                  "test_parse_specifier_for_metadata"
                ];
              });
            })
          ];
        })
        (_: prev:
          if prev.stdenv.isDarwin then
            {
              # direnv 2.37.1 still forces Darwin external linking upstream.
              direnv = prev.direnv.overrideAttrs (old: {
                env = (old.env or { }) // { CGO_ENABLED = 1; };
              });
            }
          else
            { })
      ];

      mkSystem = import ./lib/mksystem.nix {
        inherit self overlays nixpkgs inputs;
      };
    in
      {
      darwinConfigurations."aglaea" = mkSystem "aglaea" {
        system = "aarch64-darwin";
        user = "cat";
        darwin = true;
      };

      darwinConfigurations."work" = mkSystem "work" {
        system = "aarch64-darwin";
        user = "cat";
        darwin = true;
      };

      nixosConfigurations."amalthea" = mkSystem "amalthea" {
        system = "x86_64-linux";
        user   = "cat";
      };
    };
}
