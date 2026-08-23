{
  config,
  lib,
  pkgs,
  ...
}:

let
  source = ../packages/actual-bank-sync;
  manifest = builtins.fromJSON (builtins.readFile (source + "/package.json"));
  actualApiVersion = manifest.dependencies."@actual-app/api";
  package = pkgs.callPackage source { };
  backupGateDir = "/var/lib/private/actual-backup-gate";
  backupStamp = "${backupGateDir}/last-success";
  # Daily backups can be 25 hours apart across DST, plus 15 minutes of jitter.
  backupMaxAgeHours = 26;
  backupMaxAgeSeconds = backupMaxAgeHours * 60 * 60;
  # Enabled only after the supervised backup, live-ID resolution, plan, apply,
  # and post-apply invariant verification completed successfully.
  setupComplete = true;
  backupStampWriter = pkgs.writeShellScript "actual-backup-stamp" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/date +%s > ${backupStamp}.tmp
    ${pkgs.coreutils}/bin/chmod 0400 ${backupStamp}.tmp
    ${pkgs.coreutils}/bin/mv ${backupStamp}.tmp ${backupStamp}
  '';
  runtimeConfig = pkgs.writeText "actual-bank-sync.json" (
    builtins.toJSON {
      actualVersion = actualApiVersion;
      adjustmentPayee = {
        id = "8ad5a0d0-7da1-4beb-931a-dc27f3a0f3ff";
        name = "FX Adjustment";
      };
      baseCurrency = "RON";
      clearMatchedTransfersTo = {
        id = "bd2b0a5f-fb54-4816-8e06-5bb1e8013dfc";
        name = "RevolutSavings";
      };
      dataDir = "/var/lib/actual-bank-sync";
      foreignAccounts = [
        {
          bridgeRate = "5.2525";
          currency = "EUR";
          id = "053fe6ff-8107-43ae-b9a9-dfdb5a3245b6";
          name = "RevPersEUR";
        }
        {
          bridgeRate = "6.124293";
          currency = "GBP";
          id = "23c72f1a-999d-457d-ab3d-2731403546a8";
          name = "RevPersGBP";
        }
      ];
      fxCategory = {
        id = "3b9719e9-bc25-4e6b-b8e8-54716a7b5c5d";
        name = "FX adjustments";
      };
      recoveryDir = "/var/lib/actual-bank-sync/recovery";
      serverURL = "http://127.0.0.1:5006";
      timeZone = "Europe/Bucharest";
    }
  );
  runner = pkgs.writeShellScript "actual-bank-sync-run" ''
    set -euo pipefail
    backup_epoch="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/backup-stamp")"
    case "$backup_epoch" in
      ""|*[!0-9]*)
        echo "actual-bank-sync: invalid successful-backup timestamp" >&2
        exit 1
        ;;
    esac
    current_epoch="$(${pkgs.coreutils}/bin/date +%s)"
    backup_age=$((current_epoch - backup_epoch))
    if [ "$backup_age" -lt 0 ] || [ "$backup_age" -gt ${toString backupMaxAgeSeconds} ]; then
      echo "actual-bank-sync: no successful Actual restic backup in the last ${toString backupMaxAgeHours} hours" >&2
      exit 1
    fi
    export ACTUAL_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/actual-password"
    export ACTUAL_SYNC_ID_FILE="$CREDENTIALS_DIRECTORY/actual-sync-id"
    exec ${package}/bin/actual-bank-sync --mode run --config ${runtimeConfig}
  '';
in
{
  assertions = [
    {
      assertion = config.services.actual.package.version == actualApiVersion;
      message = "actual-bank-sync API ${actualApiVersion} must match the Actual server package";
    }
  ];

  systemd.tmpfiles.rules = [
    "d /etc/secrets/actual-automation 0700 root root -"
    "z /etc/secrets/actual-automation/password 0400 root root -"
    "z /etc/secrets/actual-automation/sync-id 0400 root root -"
    "d ${backupGateDir} 0700 root root -"
    "z ${backupStamp} 0400 root root -"
  ];

  systemd.services."restic-backups-actual-daily".serviceConfig.ExecStartPost = lib.mkAfter [
    "+${backupStampWriter}"
  ];

  systemd.services.actual-bank-sync = {
    description = "Sync Actual banks and reconcile foreign-currency transactions";
    requires = [ "actual.service" ];
    wants = [ "network-online.target" ];
    after = [
      "actual.service"
      "network-online.target"
      "restic-backups-actual-daily.service"
    ];
    unitConfig = {
      ConditionPathExists = [
        "/etc/secrets/actual-automation/enabled"
        "/etc/secrets/actual-automation/password"
        "/etc/secrets/actual-automation/sync-id"
      ];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = runner;
      TimeoutStartSec = "15m";
      DynamicUser = true;
      StateDirectory = "actual-bank-sync";
      StateDirectoryMode = "0700";
      LoadCredential = [
        "actual-password:/etc/secrets/actual-automation/password"
        "actual-sync-id:/etc/secrets/actual-automation/sync-id"
        "backup-stamp:${backupStamp}"
      ];
      UMask = "0077";

      AmbientCapabilities = "";
      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };
  };

  systemd.timers.actual-bank-sync = {
    description = "Daily Actual bank sync and currency reconciliation";
    wantedBy = lib.optionals setupComplete [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00 Europe/Bucharest";
      Persistent = true;
      RandomizedDelaySec = "15m";
      Unit = "actual-bank-sync.service";
    };
  };
}
