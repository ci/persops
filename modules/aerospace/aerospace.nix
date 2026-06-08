{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isDarwin;

  # AeroSpace has no runtime gaps command and no config includes, so the only way
  # to toggle gaps is to swap the whole config file and reload-config. We build two
  # variants from the single shared base: `normal` (no gaps) and `zen` (big centered
  # outer gaps on the Dell). The active file is a plain copy the toggle owns/rewrites
  # (NOT an xdg.configFile symlink into the read-only store, which couldn't be swapped
  # and would trip AeroSpace's "config found in more than one location" check).
  base = builtins.readFile ./aerospace.toml;

  normalToml = pkgs.writeText "aerospace-normal.toml" (base + ''

    # variant: normal
  '');

  zenToml = pkgs.writeText "aerospace-zen.toml" (base + ''

    # variant: zen
    [gaps]
        outer.left  = [{ monitor."DELL G3223Q" = 720 }, 0]
        outer.right = [{ monitor."DELL G3223Q" = 720 }, 0]
  '');

  # Bound to alt-z (via exec-and-forget aerospace-zen-toggle); on PATH through the
  # per-user profile, which AeroSpace's [exec] PATH already includes.
  toggleScript = pkgs.writeShellApplication {
    name = "aerospace-zen-toggle";
    runtimeInputs = [ pkgs.aerospace pkgs.coreutils ];
    text = ''
      active="''${XDG_CONFIG_HOME:-$HOME/.config}/aerospace/aerospace.toml"
      if grep -q '# variant: zen' "$active" 2>/dev/null; then
        install -m 0644 ${normalToml} "$active"
      else
        install -m 0644 ${zenToml} "$active"
      fi
      aerospace reload-config
    '';
  };
in
{
  home.packages = lib.mkIf isDarwin [
    pkgs.aerospace
    pkgs.jankyborders # nice active borders around windows
    toggleScript
  ];

  # Seed the active config as a real file (default: normal). Runs on every switch, so
  # rebuilds reapply config edits and reset to normal; the reload keeps the running
  # server in sync with the file so the next alt-z toggles from a known state.
  home.activation.aerospaceSeedConfig = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.config/aerospace"
      run ${pkgs.coreutils}/bin/install -m 0644 ${normalToml} "$HOME/.config/aerospace/aerospace.toml"
      run ${pkgs.aerospace}/bin/aerospace reload-config || true
    ''
  );
}
