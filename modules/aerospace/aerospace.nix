{ pkgs, ... }: {
  home.packages = [
    pkgs.aerospace
    pkgs.jankyborders # nice active borders around windows
  ];

  xdg.configFile."aerospace/aerospace.toml".source = ./aerospace.toml;
}

