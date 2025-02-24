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

  home.packages = with pkgs; [
    # misc
    spotify

    # dev
    aider-chat
    bun
    curl
    dbeaver-bin
    eza
    fd
    fzf
    git
    htop
    jq
    jsonnet
    jsonnet-bundler
    llm
    overmind
    ripgrep
    shellcheck
    wget

    # dev - languages
    beam.packages.erlang_27.elixir_1_18
    go

    flutter

    (python312.withPackages (ps: with ps; [
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

    (ruby_3_4.withPackages (ps: with ps; [
      cocoapods
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

    nodejs
    nodePackages.npm
    nodePackages.yarn

    # containers, k8s, helm stuff
    colima # container runtime goodies on OSX, enabling docker client
    docker
    docker-compose
    docker-credential-helpers
    kubernetes-helm
    terraform
    kubectl
    kubectx
    k9s
    tanka

    # chat
    discord
    # signal-desktop # broken in current version? mismatching sha
    slack
    zoom-us

    # osx specifics
    mos # reverse mouse direction only for mouse not touchpad
    hexfiend
    numi

    # sec stuff
    audacity
    avalonia-ilspy
    ghidra-bin

    # # example 'fine-tuning' package
    # (nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # example shell-script wrapper
    # (writeShellScriptBin "my-hello" ''
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
