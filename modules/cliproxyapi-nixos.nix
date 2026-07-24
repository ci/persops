{
  lib,
  pkgs,
  user,
  ...
}:

let
  version = "7.2.98";
  home = "/home/${user}";
  configTemplate = ./cliproxyapi/config.yaml;
  renderConfig = pkgs.callPackage ./cliproxyapi/render-config.nix { };
  cliproxyapi = pkgs.stdenvNoCC.mkDerivation {
    pname = "cliproxyapi";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_amd64.tar.gz";
      hash = "sha256-tz4kD45LtaU0FHgMo9HeOvlvFmmoJKiBZnnRqytdDeA=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];
    sourceRoot = ".";
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 cli-proxy-api "$out/libexec/cliproxyapi"
      makeWrapper "$out/libexec/cliproxyapi" "$out/bin/cliproxyapi" \
        --add-flags "--config ${home}/.cli-proxy-api/config.yaml"
      runHook postInstall
    '';

    meta = {
      description = "Wrap AI coding-agent subscriptions as an API service";
      homepage = "https://github.com/router-for-me/CLIProxyAPI";
      license = lib.licenses.mit;
      mainProgram = "cliproxyapi";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  environment.systemPackages = [ cliproxyapi ];

  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment.HOME = home;
    restartTriggers = [
      cliproxyapi
      configTemplate
      renderConfig
    ];

    serviceConfig = {
      Type = "simple";
      User = user;
      WorkingDirectory = home;
      ExecStartPre = lib.getExe renderConfig;
      ExecStart = lib.getExe cliproxyapi;
      Restart = "on-failure";
      RestartSec = 5;
      UMask = "0077";
    };
  };
}
