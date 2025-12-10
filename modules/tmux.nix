{ config, pkgs, ... }: {
  programs.tmux = {
    enable = true;
    shell = "${pkgs.fish}/bin/fish";
    terminal = "tmux-256color";
    sensibleOnTop = false;
    historyLimit = 100000;
    # maintained through brew so far until 3.3.4 makes it into nix-unstable
    # tmuxinator.enable = true;
    plugins = with pkgs;
    [
      tmuxPlugins.tmux-thumbs
      tmuxPlugins.sensible
      tmuxPlugins.pain-control
      tmuxPlugins.yank
      tmuxPlugins.tmux-fzf
      {
        plugin = tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour 'mocha'
          set -g @catppuccin_date_time_text "%H:%M"
          set -g @catppuccin_status_modules_right "date_time application uptime cpu battery"
          set -g @catppuccin_window_default_text "#W"
          set -g @catppuccin_window_text "#W"
          set -g @catppuccin_window_current_text "#W"

          set -g @catppuccin_window_status_style "rounded"

          set -g status-justify "centre"
          set -g status-right-length 100
          set -g status-left-length 100
          set -g status-left "#(tms sessions) "
          set -ag status-right "#{E:@catppuccin_status_date_time}"
          set -g status-right "#{E:@catppuccin_status_application}"
          set -ag status-right "#{E:@catppuccin_status_uptime}"
          set -agF status-right "#{E:@catppuccin_status_cpu}"
          set -agF status-right "#{E:@catppuccin_status_battery}"
        '';
      }
      tmuxPlugins.battery
      tmuxPlugins.cpu
      # disable for the time being, not acting nicely with tmuxinator
      # tmuxPlugins.better-mouse-mode
      # {
      #     plugin = tmuxPlugins.resurrect;
      #     extraConfig = ''
      #     set -g @resurrect-strategy-vim 'session'
      #     set -g @resurrect-strategy-nvim 'session'
      #     set -g @resurrect-capture-pane-contents 'on'
      #     '';
      # }
      # {
      #     plugin = tmuxPlugins.continuum;
      #     extraConfig = ''
      #     set -g @continuum-restore 'on'
      #     set -g @continuum-boot 'on'
      #     set -g @continuum-save-interval '10'
      #     '';
      # }
    ];
    extraConfig = builtins.readFile ./tmux/tmux.conf;
  };

  home.packages = with pkgs; [
    tmux-sessionizer
  ];

  # gotta exclude a bunch of unnecessary stuff to
  # prevent from trying to crawl them in the first place
  xdg.configFile."tms/config.toml".text = ''
    default_session = "default"
    display_full_path = true
    excluded_dirs = [
      "ds",
      "ai3-react-native",
      "TNI",
      "node_modules",
      ".venv",
      "target",
      ".elixir_ls",
      "_build",
      "deps",
      ".git",
      "dist",
      "assets",
      "public",
      "vendor",
      ".sass-cache",
      "wp-content",
      "tmp",
      "cache",
      ".next",
      ".vinxi",
      ".output",
      ".react-router",
      ".expo"
    ]

    [[search_dirs]]
    path = "${config.home.homeDirectory}/p"
    depth = 10

    [[search_dirs]]
    path = "${config.home.homeDirectory}/ctf"
    depth = 1
  '';
}
