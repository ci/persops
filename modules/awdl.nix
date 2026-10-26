{ pkgs, ... }:

let
  awdl = pkgs.writeShellApplication {
    name = "awdl";
    text = builtins.readFile ./awdl/toggle.sh;
  };
in
{
  environment.systemPackages = [ awdl ];

  launchd.daemons.awdl-default-off = {
    script = builtins.readFile ./awdl/default-off.sh;
    serviceConfig = {
      RunAtLoad = true;
      # Boot default only: never fight a later `awdl on` for AirDrop.
      KeepAlive = false;
      ProcessType = "Background";
    };
  };
}
