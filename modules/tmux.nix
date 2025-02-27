{ pkgs, ... }: {
  programs.tmux = {
    enable = true;
    shell = "${pkgs.fish}/bin/fish";
    terminal = "tmux-256color";
    sensibleOnTop = false;
    historyLimit = 100000;
    tmuxinator.enable = true;
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
          set -g @catppuccin_status_justify "centre"
          set -g @catppuccin_status_modules_right "date_time application uptime cpu battery"
          set -g @catppuccin_window_default_text "#W"
          set -g @catppuccin_window_text "#W"
          set -g @catppuccin_window_current_text "#W"
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
    extraConfig = builtins.readFile ./tmux.conf;
  };
}
