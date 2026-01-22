{ lib, pkgs, config, ... }:
let
  resticWrapperSrc = ./modules/backup/restic-wrapper.c;
  resticWrapperBin = pkgs.runCommand "restic-wrapper" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
    ${pkgs.stdenv.cc}/bin/cc -std=c11 -O2 -Wall -Wextra ${resticWrapperSrc} -o $out
  '';
  resticWrapperInstall = ''
    /usr/bin/install -d -m 0755 "$HOME/.local/bin" "$HOME/.local/libexec"
    /usr/bin/install -m 0755 "${pkgs.restic}/bin/restic" "$HOME/.local/libexec/restic"
    /usr/bin/install -m 0755 "${resticWrapperBin}" "$HOME/.local/bin/restic-backup"
    /usr/bin/install -m 0755 "${resticWrapperBin}" "$HOME/.local/bin/restic-prune"
    /usr/bin/install -m 0755 "${resticWrapperBin}" "$HOME/.local/bin/restic-check"
  '';
in
{
  imports = [
    ./modules/fish.nix
    ./modules/tmux.nix
    ./modules/jjui.nix
    ./modules/git/home.nix
    ./modules/ssh.nix
    ./modules/aerospace/aerospace.nix
    # ./modules/emacs/home.nix # unused for now
    ./modules/ghostty.nix
    ./modules/starship.nix
    ./modules/mise.nix
    ./modules/direnv.nix
    ./modules/nvim.nix
    ./modules/programming.nix
    ./modules/yazi.nix
    ./modules/ai/home.nix
  ];

  home.stateVersion = "23.05"; # don't really update - read release notes, figure out process

  # Zoxide - smarter cd command (replaces z plugin)
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd" "j" ];  # use 'j' as command to match previous z config
  };

  # Atuin - better shell history with sync
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;  # takes Ctrl+R
    flags = [
      "--disable-up-arrow"
    ];
    settings = {
      # login & setup keys manually
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      ctrl_n_shortcuts = true;
      filter_mode_shell_up_key_binding = "directory";  # up arrow = directory-scoped
      inline_height = 20;
      invert = true;
      keymap_mode = "vim-insert";
      show_preview = true;
      style = "compact";
    };
  };

  programs.nh = {
    enable = true;
  };

  # nix-index - locate packages by file
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = with pkgs; [
    # nix tooling
    comma  # run programs without installing: , cowsay hello

    # dev
    # aider-chat
    ast-grep
    biome
    btop
    bun
    cloudflared
    curl
    dbeaver-bin
    difftastic
    doggo
    duf
    eza
    fd
    file
    freerdp
    fzf
    fx
    glow
    htop
    hyperfine
    jq
    jsonnet
    jsonnet-bundler
    kaggle
    jujutsu
    jjui
    mosh
    navi
    nushell
    openhue-cli
    ouch
    outfieldr
    overmind
    pgcli
    pnpm
    posting
    pscale
    ripgrep
    sad
    actionlint
    shellcheck
    statix
    tree-sitter
    wakeonlan
    wget

    # containers, k8s, helm stuff
    ansible
    docker
    docker-compose
    kubernetes-helm
    terraform
    kubectl
    kubectx
    k9s
    opentofu
    tanka

    # chat
    element-desktop
    discord
    # signal-desktop # broken in current version? mismatching sha
    slack
    zoom-us

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
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    # osx specifics
    docker-credential-helpers
    mos # reverse mouse direction only for mouse not touchpad
    hexfiend
    numi
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

  home.activation.resticWrappers = lib.optionalString pkgs.stdenv.isDarwin resticWrapperInstall;

  # switching to nvim temporarily
  # home.sessionVariables = {
  #   EDITOR = "emacsclient";
  # };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
