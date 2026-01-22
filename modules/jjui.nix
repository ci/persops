{ pkgs, ... }:
{
  xdg.configFile."jjui/config.toml".source = ./jjui.toml;

  xdg.configFile."jjui/themes/base24-catppuccin-mocha.toml".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/vic/tinted-jjui/refs/heads/main/themes/base24-catppuccin-mocha.toml";
    hash = "sha256-MhUxsNsNlGpkLIfWCD/rV35O1J0HorzH9uLFLkILMGE=";
  };
}
