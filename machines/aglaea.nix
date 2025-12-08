{ pkgs, self, currentSystem, ... }: {
  system.stateVersion = 4;
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # for the determinate nix installer
  ids.gids.nixbld = 350;

  # We use proprietary software on this machine
  nixpkgs.config.allowUnfree = true;

  nixpkgs.hostPlatform = currentSystem;

  # TODO: pull this out into a shared file
  nix = {
    # Automatic garbage collection
    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };  # Sunday 2am
      options = "--delete-older-than 30d";
    };

    settings = {
      # We need to enable flakes
      experimental-features = "nix-command flakes";
    };
  };

  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Use TouchID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  environment = {
    shells = with pkgs; [ bashInteractive zsh fish ];
    systemPackages = with pkgs; [
      pam-reattach
      pam-watchid
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

  imports = [
    ../modules/postgres.nix
    ../modules/emacs/system.nix
  ];
}
