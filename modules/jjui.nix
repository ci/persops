{ pkgs, ... }:
{
  xdg.configFile."jjui/config.toml".source = ./jjui.toml;

  xdg.configFile."jjui/themes/base16-catppuccin-mocha.toml".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/vic/tinted-jjui/refs/heads/main/themes/base16-catppuccin-mocha.toml";
    hash = "sha256-WbrSKI2tiNljVH2/Wb68GVsT5PhBWz9vG5gAFPmPbPw=";
  };
}
