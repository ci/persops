{ luksUuid, filesystemUuid }:
{ pkgs, ... }:
let
  device = "dev-disk-by\\x2duuid-${builtins.replaceStrings [ "-" ] [ "\\x2d" ] luksUuid}.device";
  crypt = "systemd-cryptsetup@sea16.service";
in
{
  # Only this LUKS volume can request recovery. Do not run mount commands in udev.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="${luksUuid}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="sea16-online.service"
  '';

  # BindsTo + After propagates disappearance even if the stale dm device remains.
  # Reverse shutdown ordering releases open SMB/backup handles before cryptsetup.
  systemd.units."srv-sea16.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      BindsTo=${crypt}
      After=${crypt}
    '';
  };
  systemd.units."archive.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      BindsTo=srv-sea16.mount
      After=srv-sea16.mount
    '';
  };

  systemd.services = {
    samba-smbd = {
      bindsTo = [ "archive.mount" ];
      after = [
        "archive.mount"
        "sea16-quota-init.service"
      ];
      requires = [ "sea16-quota-init.service" ];
    };
    pheme-matrix-archive.bindsTo = [ "archive.mount" ];
    restic-backups-archive-daily.bindsTo = [ "archive.mount" ];

    sea16-online = {
      description = "Recover sea16 mounts and consumers after disk arrival";
      bindsTo = [ device ];
      after = [ device ];
      unitConfig = {
        StartLimitIntervalSec = "5m";
        StartLimitBurst = 4;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "15s";
        TimeoutStartSec = "45s";
      };
      # Keep dependencies out of this unit: a failed mount/cryptsetup job must
      # fail ExecStart so Restart can retry, not skip this service altogether.
      script = ''
        ${pkgs.systemd}/bin/systemctl start ${crypt} srv-sea16.mount archive.mount sea16-quota-init.service samba-smbd.service
        ${pkgs.systemd}/bin/systemctl --no-block start restic-backups-archive-daily.service
      '';
    };

    sea16-health = {
      description = "Check sea16 filesystem identity and directory accessibility";
      # No mount dependencies: the check must fail rather than mount/recover it.
      path = [
        pkgs.util-linux
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${./sea16-health.sh} ${filesystemUuid}";
        TimeoutStartSec = "20s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };

  systemd.timers.sea16-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "2m";
      AccuracySec = "10s";
    };
  };
}
