{...}: {
  # broken on OSX currently, maintained through brew cask in /flake.nix
  # programs.ghostty = {
  #   enable = true;
  # };
  xdg.configFile."ghostty/config".text = ''
    clipboard-read = allow
    clipboard-write = allow
    theme = catppuccin-mocha
    font-size = 14
    font-family = "JetBrainsMono NFM"
  '';
}
