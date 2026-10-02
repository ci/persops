# Work Mac. Uses the "work" profile (see lib/mksystem.nix): no persops vault,
# backups, tailnet, or remote targets. Only ergane itself deploys ergane.
{
  pkgs,
  self,
  currentSystem,
  currentSystemName,
  ...
}:
{
  # Fresh upstream Nix install; nixbld ids use the stateVersion >= 5 defaults.
  system.stateVersion = 7;
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # We use proprietary software on this machine
  nixpkgs.config.allowUnfree = true;

  nixpkgs.hostPlatform = currentSystem;

  networking = {
    hostName = currentSystemName;
    computerName = currentSystemName;
  };

  # TODO: pull this out into a shared file
  nix = {
    # Automatic garbage collection
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      }; # Sunday 2am
      options = "--delete-older-than 30d";
    };

    settings = {
      # We need to enable flakes
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # devenv's mprocs process manager symlinks the system pbcopy via an impure
      # derivation; allow that host path so the build is permitted. Nix 2.34 has
      # no working `extra-` form here, so restate the darwin defaults + pbcopy.
      allowed-impure-host-deps = [
        "/System/Library"
        "/bin/sh"
        "/dev"
        "/usr/lib"
        "/usr/bin/pbcopy"
      ];
    };
  };

  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;
  programs.fish.enable = true;

  homebrew = {
    # Homebrew is fully declarative here: undeclared formulae and casks are
    # uninstalled on switch, so add them here or in darwin.nix.
    onActivation.cleanup = "uninstall";
    casks = [
      # 1Password beta was installed before nix-darwin; the stable cask conflicts.
      "1password@beta"
      "tunnelblick" # VPN client
    ];
  };

  environment = {
    shells = with pkgs; [
      bashInteractive
      zsh
      fish
    ];
    systemPackages = with pkgs; [
      pam_u2f
      pam-reattach
      pam-watchid
    ];
    # https://write.rog.gr/writing/using-touchid-with-tmux/
    # https://github.com/LnL7/nix-darwin/pull/787
    # Manage sudo_local directly instead of touchIdAuth so Watch/Touch ID
    # prompts before FIDO fallback.
    etc."pam.d/sudo_local".text = ''
      # Managed by Nix Darwin
      auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
      auth       sufficient     ${pkgs.pam-watchid}/lib/pam_watchid.so
      auth       sufficient     pam_tid.so
      auth       sufficient     ${pkgs.pam_u2f}/lib/security/pam_u2f.so cue userverification=0 pinverification=0
    '';
  };
}
