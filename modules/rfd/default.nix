{
  pkgs,
  lib,
  currentSystemProfile,
  ...
}:
let
  rfd = pkgs.writeScriptBin "rfd" (
    builtins.replaceStrings
      [
        "@python3@"
        "@git@"
        "@fzf@"
      ]
      [
        "${pkgs.python3}/bin/python3"
        "${pkgs.git}/bin/git"
        "${pkgs.fzf}/bin/fzf"
      ]
      (builtins.readFile ./rfd.py)
  );
in
{
  # Oxide RFDs; work Mac only.
  home.packages = lib.optionals (currentSystemProfile == "work" && pkgs.stdenv.hostPlatform.isDarwin) [
    rfd
  ];
}
