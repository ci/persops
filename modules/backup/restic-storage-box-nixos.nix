{
  currentSystemName,
  currentSystemUser,
  pkgs,
  ...
}:

let
  settings = import ./restic-storage-box-settings.nix;
  inherit (settings)
    host
    port
    repository
    user
    ;

  secretDir = "/etc/secrets/restic-storage-box";
  passwordFile = "${secretDir}/password";
  identityFile = "${secretDir}/id_ed25519";
  sftpCommand = "ssh -i ${identityFile} -p ${toString port} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/etc/ssh/ssh_known_hosts -s ${user}@${host} sftp";
  storageBoxBackupFor = backupUser: {
    user = backupUser;
    inherit repository passwordFile;
    initialize = false;
    createWrapper = false;
    extraOptions = [
      "sftp.command='${sftpCommand}'"
    ];
  };
in
{
  imports = [ ./restic-storage-box.nix ];

  systemd.tmpfiles.rules = [
    "d ${secretDir} 0750 root restic -"
    "z ${passwordFile} 0440 root restic -"
    "z ${identityFile} 0400 ${currentSystemUser} restic -"
  ];

  services.restic.backups = {
    actual-daily = storageBoxBackupFor "root" // {
      # DynamicUser StateDirectory path; /var/lib/actual is only a symlink.
      paths = [ "/var/lib/private/actual" ];
      backupPrepareCommand = ''
        #!${pkgs.runtimeShell}
        actualState="$(${pkgs.systemd}/bin/systemctl is-active actual.service || true)"
        case "$actualState" in
          active|activating)
            ${pkgs.coreutils}/bin/touch /run/restic-backups-actual-daily/actual-was-active
            ${pkgs.systemd}/bin/systemctl stop actual.service
            ;;
          deactivating)
            ${pkgs.systemd}/bin/systemctl stop actual.service
            ;;
        esac
      '';
      backupCleanupCommand = ''
        #!${pkgs.runtimeShell}
        if [ -e /run/restic-backups-actual-daily/actual-was-active ]; then
          ${pkgs.systemd}/bin/systemctl --no-block start actual.service
        fi
      '';
      extraBackupArgs = [
        "--host"
        currentSystemName
        "--tag"
        "actual"
        "--one-file-system"
        "--compression"
        "auto"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 01:30:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
      pruneOpts = [ ];
      runCheck = false;
    };

    golink-daily = storageBoxBackupFor "root" // {
      # DynamicUser StateDirectory path; /var/lib/golink is only a symlink.
      paths = [ "/var/lib/private/golink" ];
      backupPrepareCommand = ''
        #!${pkgs.runtimeShell}
        golinkState="$(${pkgs.systemd}/bin/systemctl is-active golink.service || true)"
        case "$golinkState" in
          active|activating)
            ${pkgs.coreutils}/bin/touch /run/restic-backups-golink-daily/golink-was-active
            ${pkgs.systemd}/bin/systemctl stop golink.service
            ;;
          deactivating)
            ${pkgs.systemd}/bin/systemctl stop golink.service
            ;;
        esac
      '';
      backupCleanupCommand = ''
        #!${pkgs.runtimeShell}
        if [ -e /run/restic-backups-golink-daily/golink-was-active ]; then
          ${pkgs.systemd}/bin/systemctl --no-block start golink.service
        fi
      '';
      extraBackupArgs = [
        "--host"
        currentSystemName
        "--tag"
        "golink"
        "--one-file-system"
        "--compression"
        "auto"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 01:45:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
      pruneOpts = [ ];
      runCheck = false;
    };

    archive-daily = storageBoxBackupFor currentSystemUser // {
      paths = [ "/archive" ];
      extraBackupArgs = [
        "--host"
        currentSystemName
        "--tag"
        "archive"
        "--exclude-caches"
        "--exclude-if-present"
        ".nobackup"
        "--one-file-system"
        "--compression"
        "auto"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 01:00:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
      pruneOpts = [ ];
      runCheck = false;
    };

    archive-prune-monthly = storageBoxBackupFor currentSystemUser // {
      paths = [ ];
      timerConfig = {
        OnCalendar = "*-*-01 10:00:00";
        Persistent = true;
      };
      pruneOpts = [
        "--host"
        currentSystemName
        "--keep-daily"
        "30"
        "--keep-weekly"
        "12"
        "--keep-monthly"
        "24"
      ];
      runCheck = false;
    };

    archive-check-weekly = storageBoxBackupFor currentSystemUser // {
      paths = [ ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 09:00:00";
        Persistent = true;
      };
      pruneOpts = [ ];
      runCheck = true;
      checkOpts = [
        "--read-data-subset=5%"
      ];
    };
  };

  systemd.services = {
    "restic-backups-actual-daily".after = [ "actual.service" ];
    "restic-backups-golink-daily".after = [ "golink.service" ];

    "restic-backups-archive-daily" = {
      requires = [ "archive.mount" ];
      after = [ "archive.mount" ];
      unitConfig = {
        ConditionPathIsMountPoint = "/archive";
        StartLimitIntervalSec = "6h";
        StartLimitBurst = 4;
      };
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5m";
      };
    };
  };
}
