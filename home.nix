{ pkgs, ... }: {
  imports = [
    (import ./modules/fish.nix)
    (import ./modules/tmux.nix)
    (import ./modules/git/home.nix)
    (import ./modules/aerospace/aerospace.nix)
    (import ./modules/emacs/home.nix)
    (import ./modules/ghostty.nix)
    (import ./modules/starship.nix)
    (import ./modules/mise.nix)
    (import ./modules/direnv.nix)
    (import ./modules/nvim.nix)
    (import ./modules/programming.nix)
    (import ./modules/yazi.nix)
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
      ctrl_n_shortcuts = true;
      filter_mode_shell_up_key_binding = "directory";  # up arrow = directory-scoped
      inline_height = 20;
      invert = true;
      keymap_mode = "vim-insert";
      show_preview = true;
      style = "compact";
    };
  };

  # nix-index - locate packages by file
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = with pkgs; [
    # nix tooling
    comma  # run programs without installing: , cowsay hello
    # misc
    spotify

    # dev
    # aider-chat
    ast-grep
    biome
    bun
    cloudflared
    curl
    dbeaver-bin
    duf
    dogdns
    eza
    fd
    fzf
    glow
    htop
    hyperfine
    jq
    jsonnet
    jsonnet-bundler
    llm
    nushell
    ouch
    overmind
    pnpm
    pscale
    ripgrep
    sad
    shellcheck
    statix
    tree-sitter
    wget

    # containers, k8s, helm stuff
    ansible
    docker
    docker-compose
    docker-credential-helpers
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

  # switching to nvim temporarily
  # home.sessionVariables = {
  #   EDITOR = "emacsclient";
  # };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
