{
  lib,
  pkgs,
  currentSystemName,
  currentSystemUser,
  ...
}:

let
  user = currentSystemUser;
  dest = "/archive/pheme/matrix";
  identity = "/home/${user}/.ssh/id_ed25519_pheme";
  knownHosts = pkgs.writeText "pheme_known_hosts" ''
    pheme.reverse-justitia.ts.net ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACwGKJaULUfyiClHyFF64EHWtP5yIEqcUvzSXnxrUYt
  '';
  pull = pkgs.writeShellScript "pheme-matrix-archive" (builtins.readFile ./pheme-matrix-archive.sh);
in
{
  assertions = [
    {
      assertion = currentSystemName == "amalthea";
      message = "Pheme Matrix archive pull is only intended for amalthea.";
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${dest} 0750 ${user} users -"
    "d ${dest}/dumps 0750 ${user} users -"
    "d ${dest}/config 0750 ${user} users -"
    "d ${dest}/media 0750 ${user} users -"
  ];

  systemd.services.pheme-matrix-archive = {
    description = "Pull Matrix backups from pheme into /archive";
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    after = [
      "network-online.target"
      "tailscaled.service"
      "archive.mount"
    ];
    requires = [ "archive.mount" ];
    path = with pkgs; [
      coreutils
      findutils
      openssh
      rsync
    ];
    unitConfig = {
      ConditionPathIsMountPoint = "/archive";
      ConditionPathExists = identity;
      StartLimitIntervalSec = "6h";
      StartLimitBurst = 3;
    };
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      UMask = "0077";
      ExecStart = pull;
      TimeoutStartSec = "30m";
      ReadWritePaths = [ "/archive" ];
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
    environment = {
      PHEME_SSH_IDENTITY = identity;
      PHEME_KNOWN_HOSTS = "${knownHosts}";
      PHEME_SSH_HOST = "pheme.reverse-justitia.ts.net";
      PHEME_SSH_USER = "cat";
      PHEME_MATRIX_DIR = "/home/cat/matrix";
      PHEME_ARCHIVE_DIR = dest;
      PHEME_KEEP_DUMPS = "7";
      PHEME_SSH_BIN = lib.getExe pkgs.openssh;
      PHEME_RSYNC_BIN = lib.getExe pkgs.rsync;
      PHEME_DATE_BIN = "${pkgs.coreutils}/bin/date";
      PHEME_INSTALL_BIN = "${pkgs.coreutils}/bin/install";
      PHEME_FIND_BIN = "${pkgs.findutils}/bin/find";
      PHEME_LN_BIN = "${pkgs.coreutils}/bin/ln";
      PHEME_CHMOD_BIN = "${pkgs.coreutils}/bin/chmod";
      PHEME_MV_BIN = "${pkgs.coreutils}/bin/mv";
      PHEME_RM_BIN = "${pkgs.coreutils}/bin/rm";
      PHEME_MKTEMP_BIN = "${pkgs.coreutils}/bin/mktemp";
      PHEME_WC_BIN = "${pkgs.coreutils}/bin/wc";
    };
  };

  # Wants, not Requires: a down pheme must not skip the rest of /archive restic.
  systemd.services."restic-backups-archive-daily" = {
    wants = [ "pheme-matrix-archive.service" ];
    after = lib.mkAfter [ "pheme-matrix-archive.service" ];
  };

  systemd.timers.pheme-matrix-archive = {
    description = "Pull Matrix backups from pheme before archive restic";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00:20:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
      Unit = "pheme-matrix-archive.service";
    };
  };
}
