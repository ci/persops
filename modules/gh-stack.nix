{ config, pkgs, ... }:
let
  extensionDir = "${config.xdg.dataHome}/gh/extensions/gh-stack";
in
{
  home.packages = [ pkgs.gh-stack ];

  xdg.dataFile = {
    "gh/extensions/gh-stack/gh-stack" = {
      source = "${pkgs.gh-stack}/bin/gh-stack";
      force = true;
    };
    "gh/extensions/gh-stack/manifest.yml" = {
      text = ''
        owner: github
        name: gh-stack
        host: github.com
        tag: v${pkgs.gh-stack.version}
        ispinned: true
        path: ${extensionDir}/gh-stack
      '';
      force = true;
    };
  };
}
