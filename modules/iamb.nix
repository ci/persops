{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
in
{
  home.packages = [
    inputs.iamb.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # iamb uses the platform config directory, which isn't XDG on macOS.
  home.file."Library/Application Support/iamb/config.toml" = lib.mkIf isDarwin {
    source = ./iamb.toml;
  };
  xdg.configFile."iamb/config.toml" = lib.mkIf isLinux {
    source = ./iamb.toml;
  };
}
