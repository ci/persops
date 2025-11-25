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
    configuration = {pkgs, lib, ... }: {
        imports = [
          ./modules/postgres.nix
          ./modules/emacs/system.nix
        ];

        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility. please read the changelog
        # before changing: `darwin-rebuild changelog`.
        system.stateVersion = 4;

        # The platform the configuration will be used on.
        # If you're on an Intel system, replace with "x86_64-darwin"
        nixpkgs.hostPlatform = "aarch64-darwin";
        nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
          "discord"
          "mos"
          "numi"
          "slack"
          "spotify"
          "terraform"
          "zoom"
        ];

        # Declare the user that will be running `nix-darwin`.
        system.primaryUser = "cat";
        users.knownUsers = [ "cat" ];
        users.users.cat = {
            uid = 501;
            name = "cat";
            home = "/Users/cat";
            shell = pkgs.fish;
        };

        ids.gids.nixbld = 350;

        # Create fish setup that loads the nix-darwin environment.
        programs.zsh.enable = true;
        programs.fish.enable = true;

        # Use TouchID for sudo
        security.pam.services.sudo_local.touchIdAuth = true;

        environment = {
            systemPackages = [
              # pkgs.neofetch # recent issues building python ueberzug
              pkgs.pam-reattach
              pkgs.pam-watchid
            ];
            # https://write.rog.gr/writing/using-touchid-with-tmux/
            # https://github.com/LnL7/nix-darwin/pull/787
            etc."pam.d/sudo_local".text = ''
              # Managed by Nix Darwin
              auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
              auth       sufficient     ${pkgs.pam-watchid}/lib/pam_watchid.so
              auth       sufficient     pam_tid.so
            '';
        };

        homebrew = {
          enable = true;
          # onActivation.cleanup = "uninstall";

          taps = [ ];
          brews = [
            "cowsay"
            "libpq" # for ruby `pg` gems through mise
            "sshpass" # ansible ssh automation
            "qemu" # virtualization goodies
            "tmuxinator" # instead of tmux.tmuxinator.enable
          ];
          casks = [
            "claude" # claudedesktop goes brrr
            "claude-code" # codesonnet ftw
            "codex"
            "font-jetbrains-mono-nerd-font"
            "ghostty" # best terminal atm
            "homerow" # everywhere-navigation
            "keybase" # keybase-gui doesn't work on OSX yet
            "kindavim" # vim-ify everything
            "linear-linear" # linear app
            "orbstack" # container goodies on OSX
            "ollama-app" # through brew since nixos is just client for darwin
            "readdle-spark" # trialing out email client
            "responsively" # browser for dev
            "sensiblesidebuttons" # handle mouse prev/next buttons in Safari
            "sonic-visualiser" # audio stegano
            "tailscale-app" # wireguard mesh goodies
            "vagrant" # + qemu = nice
            "vivaldi" # tryna migrate from arc
            "windsurf" # codeium successor
            "yaak@beta" # postman much
            "zen" # tired of switching browsers
            "zed" # one-letter away ^ - NewEditorAgain?
          ];
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
