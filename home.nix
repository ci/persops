{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/tmux.nix)
    (import ./modules/ghostty.nix)
  ];

  home.stateVersion = "23.05"; # don't really update - read release notes, figure out process

  home.packages = [
    pkgs.hello

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
