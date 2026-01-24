{ pkgs, ... }: {
  home.packages = [
    pkgs.jj-starship
  ];
  programs.starship = {
    enable = true;
    settings = pkgs.lib.importTOML ./starship.toml;
  };
}
