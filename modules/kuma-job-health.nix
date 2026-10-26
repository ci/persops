{ pkgs, lib, ... }:
let
  kumaJobs = lib.mapAttrs (_: job: job // { kuma = true; }) (
    builtins.fromJSON (builtins.readFile ../infra/uptime-kuma/jobs.json)
  );
  additionalJobs = {
    home-backup = {
      unit = "restic-backups-home-hourly";
      max_age = 7200;
    };
    home-prune = {
      unit = "restic-backups-home-prune-daily";
      max_age = 93600;
    };
    home-check = {
      unit = "restic-backups-home-check-weekly";
      max_age = 691200;
    };
    archive-check = {
      unit = "restic-backups-archive-check-weekly";
      max_age = 691200;
    };
    archive-prune = {
      unit = "restic-backups-archive-prune-monthly";
      max_age = 2764800;
    };
    monitoring-backup = {
      unit = "restic-backups-monitoring-daily";
      max_age = 93600;
    };
    pheme-archive = {
      unit = "pheme-matrix-archive";
      max_age = 93600;
    };
  };
  jobs = pkgs.writeText "observed-jobs.json" (
    builtins.toJSON (kumaJobs // lib.mapAttrs (_: job: job // { kuma = false; }) additionalJobs)
  );
  tokens = "/etc/secrets/kuma-job-health/tokens.json";
  metricsDirectory = "/var/lib/kuma-job-health-metrics";
in
{
  # The system D-Bus rejects transient DynamicUser identities on this host.
  users.groups.kuma-job-health = { };
  users.users.kuma-job-health = {
    isSystemUser = true;
    group = "kuma-job-health";
  };

  # Published from OpenTofu state by scripts/kuma-job-secrets-install.
  services.onepassword-secrets.secrets.kumaJobTokens = {
    reference = "op://persops/kuma-job-tokens/tokens.json";
    kind = "file";
    path = tokens;
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /etc/secrets/kuma-job-health 0700 root root -"
    "d ${metricsDirectory} 0750 kuma-job-health kuma-job-health -"
  ];
  users.users.node-exporter.extraGroups = [ "kuma-job-health" ];
  services.prometheus.exporters.node.extraFlags = [
    "--collector.textfile.directory=${metricsDirectory}"
  ];

  systemd.services.kuma-job-health = {
    description = "Export read-only scheduled-job health to metrics and Uptime Kuma";
    after = [ "uptime-kuma.service" ];
    path = [
      pkgs.systemd
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./kuma-job-health.py} ${jobs} %d/tokens.json /var/lib/kuma-job-health/state.json ${metricsDirectory}/jobs.prom";
      LoadCredential = [ "tokens.json:${tokens}" ];
      StateDirectory = "kuma-job-health";
      StateDirectoryMode = "0700";
      User = "kuma-job-health";
      Group = "kuma-job-health";
      UMask = "0077";
      TimeoutStartSec = "2m";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ metricsDirectory ];
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
