{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    mise
  ];

  xdg.configFile."mise/config.toml".source = ./mise.toml;

  programs = {
    bash.initExtra = ''
      eval "$(${lib.getExe pkgs.mise} activate bash)"
    '';

    fish.interactiveShellInit = lib.mkAfter ''
      ${lib.getExe pkgs.mise} activate fish | source
    '';

    fish.shellInit = lib.mkAfter ''
      ${lib.getExe pkgs.mise} activate fish --shims | source
    '';
  };
}

