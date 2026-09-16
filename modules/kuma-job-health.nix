{ pkgs, ... }:
let
  jobs = ../infra/uptime-kuma/jobs.json;
in
{
  systemd.tmpfiles.rules = [
    "d /etc/secrets/kuma-job-health 0700 root root -"
    "z /etc/secrets/kuma-job-health/tokens.json 0400 root root -"
  ];

  systemd.services.kuma-job-health = {
    description = "Report read-only scheduled-job health to Uptime Kuma";
    after = [ "uptime-kuma.service" ];
    path = [
      pkgs.systemd
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./kuma-job-health.py} ${jobs} %d/tokens.json /var/lib/kuma-job-health/state.json";
      LoadCredential = [ "tokens.json:/etc/secrets/kuma-job-health/tokens.json" ];
      StateDirectory = "kuma-job-health";
      StateDirectoryMode = "0700";
      DynamicUser = true;
      UMask = "0077";
      TimeoutStartSec = "2m";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  systemd.timers.kuma-job-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
    };
  };
}
