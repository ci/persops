{ config, pkgs, ... }:

{
  imports = [
    (import ./modules/fish.nix)
    (import ./modules/tmux.nix)
    (import ./modules/ghostty.nix)
    (import ./modules/starship.nix)
    (import ./modules/mise.nix)
  ];

  home.stateVersion = "23.05"; # don't really update - read release notes, figure out process

  home.packages = [
    # misc
    pkgs.spotify

    # dev
    pkgs.aider-chat
    pkgs.dbeaver-bin
    pkgs.llm
    pkgs.overmind
    pkgs.shellcheck

    # dev - languages
    pkgs.elixir_1_18
    pkgs.go

    (pkgs.python312.withPackages (ps: with ps; [
      aiohttp
      beautifulsoup4
      ipython
      jupyter
      matplotlib
      numpy
      pandas
      pwntools
      requests
      ropgadget
      setuptools
      z3
    ]))

    (pkgs.ruby_3_4.withPackages (ps: with ps; [
      htmlbeautifier
      irb
      pry
      pwntools
      rails
      rake
      rspec
      rubocop
      solargraph
    ]))

    # k8s stuff
    pkgs.kubernetes-helm
    pkgs.terraform
    pkgs.kubectl
    pkgs.kubectx
    pkgs.k9s

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
    pkgs.ghidra-bin

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
