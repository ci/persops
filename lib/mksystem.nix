# based on https://github.com/mitchellh/nixos-config/blob/main/lib/mksystem.nix
#
# This function creates a NixOS system based on our VM setup for a
# particular architecture.
{ self, nixpkgs, overlays, inputs }:

name:
{
  system,
  user,
  darwin ? false,
}:

let
  # True if Linux, which is a heuristic for not being Darwin.
  isLinux = !darwin;

  # The config files for this system.
  machineConfig = ../machines/${name}.nix;
  userOSConfig = ../${if darwin then "darwin" else "nixos" }.nix;
  userHMConfig = ../home.nix;

  # NixOS vs nix-darwin functions
  systemFunc = if darwin then inputs.nix-darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  home-manager = if darwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
in systemFunc rec {
  inherit system;

  specialArgs = {
    inherit self inputs;
    user = user;
  };

  modules = [
    # Apply our overlays. Overlays are keyed by system type so we have
    # to go through and apply our system type. We do this first so
    # the overlays are available globally.
    { nixpkgs.overlays = overlays; }

    # Allow unfree packages.
    { nixpkgs.config.allowUnfree = true; }

    # Snapd on Linux
    (if isLinux then inputs.nix-snapd.nixosModules.default else {})

    machineConfig
    userOSConfig
    home-manager.home-manager {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit inputs system;
      };
      home-manager.users.${user} = import userHMConfig;
    }

    # We expose some extra arguments so that our modules can parameterize
    # better based on these values.
    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
      };
    }
  ];
}
