{
  lib,
  pkgs,
  user,
  ...
}:

let
  renderConfig = pkgs.callPackage ./cliproxyapi/render-config.nix { };
  brewConfigPath = "/opt/homebrew/etc/cliproxyapi.conf";
  authDir = "/Users/${user}/.cli-proxy-api";
  runtimeConfigPath = "${authDir}/config.yaml";
in
{
  homebrew.brews = [
    {
      name = "cliproxyapi";
      restart_service = "always";
    }
  ];

  # Homebrew starts the service during activation, so seed its config first.
  system.activationScripts.preActivation.text = lib.mkAfter ''
    /usr/bin/sudo --user=${user} --set-home "${lib.getExe renderConfig}"
    /usr/bin/install -d -m 0755 /opt/homebrew/etc

    if [ -e "${brewConfigPath}" ] && [ ! -L "${brewConfigPath}" ]; then
      echo "error: refusing to replace existing ${brewConfigPath}" >&2
      exit 1
    fi

    /bin/ln -sfn "${runtimeConfigPath}" "${brewConfigPath}"
  '';
}
