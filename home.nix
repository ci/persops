{ lib, pkgs, ... }:
let
  resticWrapperSrc = ./modules/backup/restic-wrapper.c;
  resticWrapperBin = pkgs.runCommand "restic-wrapper" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
    ${pkgs.stdenv.cc}/bin/cc -std=c11 -O2 -Wall -Wextra ${resticWrapperSrc} -o $out
  '';
  blogwatcherPackage = pkgs.callPackage ./modules/blogwatcher.nix { };
  goplacesPackage = pkgs.callPackage ./modules/goplaces.nix { };
  gwsPackage = pkgs.callPackage ./modules/gws.nix { };
  skepsisPackage = pkgs.callPackage ./modules/skepsis { };
  resticWrapperInstall = ''
    /usr/bin/install -d -m 0755 "$HOME/.local/bin" "$HOME/.local/libexec"
    install_if_changed() {
      local src="$1"
      local dst="$2"
      if [ ! -x "$dst" ] || ! /usr/bin/cmp -s "$src" "$dst"; then
        /usr/bin/install -m 0755 "$src" "$dst"
      fi
    }
    install_if_changed "${pkgs.restic}/bin/restic" "$HOME/.local/libexec/restic"
    install_if_changed "${resticWrapperBin}" "$HOME/.local/bin/restic-backup"
    install_if_changed "${resticWrapperBin}" "$HOME/.local/bin/restic-prune"
    install_if_changed "${resticWrapperBin}" "$HOME/.local/bin/restic-check"
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
    ./modules/cmux.nix
    ./modules/starship.nix
    ./modules/mise.nix
    ./modules/direnv.nix
    ./modules/nvim.nix
    ./modules/programming.nix
    ./modules/yazi.nix
    ./modules/ai/home.nix
    ./modules/ops-status.nix
  ];

  programs = {
    # Zoxide - smarter cd command (replaces z plugin)
    zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = [
        "--cmd"
        "j"
      ]; # use 'j' as command to match previous z config
    };

    # Atuin - better shell history with sync
    atuin = {
      enable = true;
      enableFishIntegration = true; # takes Ctrl+R
      flags = [
        "--disable-up-arrow"
      ];
      settings = {
        # login & setup keys manually
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://api.atuin.sh";
        ctrl_n_shortcuts = true;
        search_mode = "fulltext";
        search_mode_shell_up_key_binding = "fulltext";
        filter_mode_shell_up_key_binding = "directory"; # up arrow = directory-scoped
        inline_height = 20;
        invert = true;
        keymap_mode = "vim-insert";
        show_preview = true;
        style = "compact";
      };
    };

    nh = {
      enable = true;
    };

    # nix-index - locate packages by file
    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;

    # Fish enables this by default for `man` completions; `mandb` slows builds.
    man.generateCaches = false;
  };

  home = {
    stateVersion = "23.05"; # don't really update - read release notes, figure out process

    packages =
      with pkgs;
      [
        # nix tooling
        comma # run programs without installing: , cowsay hello
        devenv
        nix-fast-build
        nix-output-monitor

        # dev
        # aider-chat
        ast-grep
        awscli2
        biome
        blogwatcherPackage
        btop
        bun
        cmake
        cloudflared
        curl
        dbeaver-bin
        difftastic
        doggo
        duf
        dust
        eza
        fd
        file
        freerdp
        fzf
        fx
        gh
        gwsPackage
        goplacesPackage
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
        pscale
        ripgrep
        sad
        actionlint
        shellcheck
        skepsisPackage
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
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        # osx specifics
        docker-credential-helpers
        mos # reverse mouse direction only for mouse not touchpad
        hexfiend
        numi
      ];

    # manage dotfiles directly
    file = {
      # # symlink
      # ".screenrc".source = dotfiles/screenrc;

      # # set content directly
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };

    activation = {
      resticWrappers = lib.optionalString pkgs.stdenv.isDarwin resticWrapperInstall;
      ensurePathDirs = ''
        mkdir -p "$HOME/.local/share/pnpm" "$HOME/.npm-global/bin" "$HOME/.npm-global/lib/node_modules"
      '';
      ensureNpmPrefix = lib.hm.dag.entryAfter [ "ensurePathDirs" ] ''
        npmrc="$HOME/.npmrc"
        if [ ! -e "$npmrc" ] || ! grep -qE '^[[:space:]]*prefix[[:space:]]*=' "$npmrc"; then
          umask 077
          if [ -e "$npmrc" ] && [ -s "$npmrc" ] && [ "$(tail -c 1 "$npmrc" 2>/dev/null || true)" != "" ]; then
            printf '\n' >> "$npmrc"
          fi
          printf 'prefix=%s/.npm-global\n' "$HOME" >> "$npmrc"
        fi
      '';
    };

    sessionVariables = {
      CODEX_HOME = "$HOME/.codex";
      PNPM_HOME = "$HOME/.local/share/pnpm";
      # EDITOR = "emacsclient"; # switching to nvim temporarily
    };

    sessionPath = [
      "$HOME/.local/share/pnpm"
      "$HOME/.npm-global/bin"
      "$HOME/go/bin"
      "$HOME/p/posthog/tools/infra-scripts/mcp"
    ];
  };
}
