{ device }:
{ pkgs, ... }:
{
  # Daily SMART snapshot of the root NVMe. Fails (and so alerts through
  # kuma-job-health) when spare drops or media errors rise since the last run.
  systemd.services.nvme-health = {
    description = "Record NVMe SMART health and flag regressions";
    path = [ pkgs.smartmontools ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./nvme-health.py} ${device} /var/lib/nvme-health";
      StateDirectory = "nvme-health";
      StateDirectoryMode = "0750";
      TimeoutStartSec = "2m";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  systemd.timers.nvme-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnCalendar = "daily";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };
}
