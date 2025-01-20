{
  description = "persops";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
        url = "github:LnL7/nix-darwin";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = {pkgs, ... }: {

        services.nix-daemon.enable = true;
        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility. please read the changelog
        # before changing: `darwin-rebuild changelog`.
        system.stateVersion = 4;

        # The platform the configuration will be used on.
        # If you're on an Intel system, replace with "x86_64-darwin"
        nixpkgs.hostPlatform = "aarch64-darwin";

        # Declare the user that will be running `nix-darwin`.
        users.knownUsers = [ "cat" ];
        users.users.cat = {
            uid = 501;
            name = "cat";
            home = "/Users/cat";
            shell = pkgs.fish;
        };

        # Create fish setup that loads the nix-darwin environment.
        programs.zsh.enable = true;
        programs.fish.enable = true;

        # Use TouchID for sudo
        security.pam.enableSudoTouchIdAuth = true;

        environment = {
            systemPackages = [
              pkgs.neofetch
              pkgs.pam-reattach
            ];
            # https://write.rog.gr/writing/using-touchid-with-tmux/
            # https://github.com/LnL7/nix-darwin/pull/787
            etc."pam.d/sudo_local".text = ''
              # Managed by Nix Darwin
              auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
              auth       sufficient     pam_tid.so
            '';
        };

        homebrew = {
          enable = true;
          # onActivation.cleanup = "uninstall";

          taps = [ ];
          brews = [ "cowsay" ];
          casks = [ "ghostty" ];
        };
    };
  in
  {
    darwinConfigurations."aglaea" = nix-darwin.lib.darwinSystem {
      modules = [
          configuration
          home-manager.darwinModules.home-manager  {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.verbose = true;
              home-manager.users.cat = import ./home.nix;
          }
      ];
    };
  };
}
