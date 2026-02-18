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
        (final: prev:
          if prev.stdenv.isLinux then
            let
              bumpSamba = pkg: pkg.overrideAttrs (old:
                let
                  version = "4.22.7";
                in
                {
                  inherit version;
                  src = prev.fetchurl {
                    url = "https://download.samba.org/pub/samba/stable/samba-${version}.tar.gz";
                    hash = "sha256-EhlYEdRUL2YVNukFW0TVjFMCBBK+r6riBeInv3L2pJc=";
                  };
                });
            in
            {
              samba = bumpSamba prev.samba;
              samba4Full = bumpSamba prev.samba4Full;
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

      nixosConfigurations."amalthea" = mkSystem "amalthea" {
        system = "x86_64-linux";
        user   = "cat";
      };
    };
}
