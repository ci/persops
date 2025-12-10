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
    nix-yazi-plugins = {
      url = "github:lordkekz/nix-yazi-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jujutsu.url = "github:martinvonz/jj";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nix-darwin, nixpkgs, home-manager, ... }@inputs:
    let
      overlays = [
        inputs.jujutsu.overlays.default
        inputs.zig.overlays.default
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
