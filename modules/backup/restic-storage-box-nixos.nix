{
  currentSystemName,
  currentSystemUser,
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
  storageBoxBackupCommon = {
    user = currentSystemUser;
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
    archive-daily = storageBoxBackupCommon // {
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

    archive-prune-monthly = storageBoxBackupCommon // {
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

    archive-check-weekly = storageBoxBackupCommon // {
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

  systemd.services."restic-backups-archive-daily" = {
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
}
