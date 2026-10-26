{
  pkgs,
  currentSystemName,
  currentSystemUser,
  ...
}:
let
  home = "/Users/${currentSystemUser}";
  state = "${home}/Library/Application Support/persops-alloy";
in
{
  assertions = [
    {
      assertion = currentSystemName == "aglaea";
      message = "Personal push monitoring is only configured for Aglaea.";
    }
  ];
  home-manager.users.${currentSystemUser} = { lib, ... }: {
    home.activation.monitoringDirectories =
      lib.hm.dag.entryBetween [ "persopsSecrets" ] [ "writeBoundary" ]
        ''
          run install -d -m 0700 ${lib.escapeShellArg "${home}/.config/monitoring"} ${lib.escapeShellArg state}
        '';
    persops.homeSecrets.files.monitoringPushToken = {
      reference = "op://persops/monitoring-amalthea/aglaea_push_token";
      path = "${home}/.config/monitoring/push-token";
    };
  };
  launchd.user.agents.persops-alloy.serviceConfig = {
    ProgramArguments = [
      "${pkgs.grafana-alloy}/bin/alloy"
      "run"
      "${./aglaea.alloy}"
      "--storage.path=${state}"
      "--server.http.listen-addr=127.0.0.1:12345"
      "--disable-reporting"
    ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    Umask = 63;
    StandardOutPath = "${home}/Library/Logs/persops-alloy.log";
    StandardErrorPath = "${home}/Library/Logs/persops-alloy.err.log";
  };
}
