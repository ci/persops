{...}: {
  # broken on OSX currently, maintained through brew cask in /flake.nix
  # programs.ghostty = {
  #   enable = true;
  # };
  xdg.configFile."ghostty/config".text = ''
    clipboard-read = allow
    clipboard-write = allow
    theme = "Catppuccin Mocha"
    font-size = 14
    font-family = "JetBrainsMono NFM"
    maximize = true
    fullscreen = true
    window-decoration = false
    macos-titlebar-style = "hidden"
    macos-non-native-fullscreen = "visible-menu"
    macos-option-as-alt = true
  '';
}
