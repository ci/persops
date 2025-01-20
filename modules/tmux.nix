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
          set -g @catppuccin_window_tabs_enabled on
          set -g @catppuccin_date_time "%H:%M"
          set -g @catppuccin_window_status_style "rounded"
        '';
      }
      tmuxPlugins.battery
      tmuxPlugins.cpu
      # tmuxPlugins.better-mouse-mode
    ];
    extraConfig = builtins.readFile ./tmux.conf;
  };
}
