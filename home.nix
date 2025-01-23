{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/fish.nix)
    (import ./modules/tmux.nix)
    (import ./modules/ghostty.nix)
    (import ./modules/starship.nix)
  ];

  home.stateVersion = "23.05"; # don't really update - read release notes, figure out process

  home.packages = [
    # misc
    pkgs.spotify

    # dev
    pkgs.overmind
    pkgs.dbeaver-bin

    # chat
    pkgs.discord
    # pkgs.signal-desktop # broken in current version? mismatching sha
    pkgs.slack
    pkgs.zoom-us

    # osx specifics
    pkgs.mos # reverse mouse direction only for mouse not touchpad
    pkgs.hexfiend
    pkgs.numi

    # sec stuff
    pkgs.audacity
    pkgs.avalonia-ilspy

    # # example 'fine-tuning' package
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # example shell-script wrapper
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # manage dotfiles directly
  home.file = {
    # # symlink
    # ".screenrc".source = dotfiles/screenrc;

    # # set content directly
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "emacsclient";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
