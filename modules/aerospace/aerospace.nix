{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin;
in {
  home.packages = lib.mkIf isDarwin [
    pkgs.aerospace
    pkgs.jankyborders # nice active borders around windows
  ];

  xdg.configFile."aerospace/aerospace.toml" = lib.mkIf isDarwin {
    source = ./aerospace.toml;
  };
}

