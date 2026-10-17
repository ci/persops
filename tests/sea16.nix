{ pkgs }:
let
  luksUuid = "c6ef6695-37d1-4edf-9f8c-8e08cbff15e6";
  filesystemUuid = "2fdec40d-417b-4859-876f-587632239597";
in
pkgs.testers.runNixOSTest {
  name = "sea16-hotplug";
  nodes.machine = {
    imports = [ (import ../modules/backup/sea16-lifecycle.nix { inherit luksUuid filesystemUuid; }) ];
    virtualisation.qemu.diskInterface = "scsi";
    virtualisation.emptyDiskImages = [
      {
        size = 1024;
        driveConfig.deviceExtraOpts = {
          id = "sea16";
          bus = "scsi.0";
          "scsi-id" = "1";
          lun = "0";
        };
      }
    ];
    environment.systemPackages = [
      pkgs.cryptsetup
      pkgs.xfsprogs
    ];
    environment.etc."sea16.key".text = "disposable VM test key";
    environment.etc."crypttab".text = ''
      sea16 UUID=${luksUuid} /etc/sea16.key luks,nofail,noauto,headless,tries=1
    '';
    virtualisation.fileSystems = {
      "/srv/sea16" = {
        device = "/dev/mapper/sea16";
        fsType = "xfs";
        options = [
          "nofail"
          "noauto"
        ];
      };
      "/archive" = {
        device = "/srv/sea16/archive";
        fsType = "none";
        options = [
          "bind"
          "nofail"
          "noauto"
        ];
      };
    };
    # Consumers hold working directories open, reproducing the original busy
    # mount failure unless disappearance stops them before unmount/close.
    systemd.services = {
      sea16-online.unitConfig.ConditionPathExists = "/run/sea16-ready";
      sea16-quota-init = {
        requires = [ "srv-sea16.mount" ];
        after = [ "srv-sea16.mount" ];
        serviceConfig.Type = "oneshot";
        script = "mkdir -p /srv/sea16/archive /srv/sea16/tm/aglaea";
      };
      samba-smbd.serviceConfig = {
        ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
        WorkingDirectory = "/srv/sea16/tm/aglaea";
      };
      restic-backups-archive-daily = {
        after = [ "archive.mount" ];
        serviceConfig.WorkingDirectory = "/archive";
        script = ''
          echo started >> /run/archive-backups
          exec ${pkgs.coreutils}/bin/sleep infinity
        '';
      };
      pheme-matrix-archive = {
        after = [ "archive.mount" ];
        serviceConfig = {
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          WorkingDirectory = "/archive";
        };
      };
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.fail("systemctl start sea16-health.service")

    # Provision only the disposable secondary disk. Keep arrival recovery off
    # until it contains a usable filesystem, then generate a real hotplug event.
    machine.succeed("cryptsetup luksFormat --batch-mode --pbkdf pbkdf2 --uuid ${luksUuid} /dev/sdb /etc/sea16.key")
    machine.succeed("cryptsetup open /dev/sdb sea16 --key-file /etc/sea16.key")
    machine.succeed("mkfs.xfs -m uuid=${filesystemUuid} /dev/mapper/sea16")
    machine.succeed("mkdir -p /mnt; mount /dev/mapper/sea16 /mnt; mkdir -p /mnt/archive /mnt/tm/aglaea; umount /mnt")
    machine.succeed("cryptsetup close sea16; udevadm settle")
    machine.succeed("touch /run/sea16-ready")

    def unplug():
        machine.send_monitor_command("device_del sea16")
        # The emulated LSI controller has no hotplug notification. Remove its
        # now-absent target from the guest too, just as USB disconnect does.
        machine.succeed("echo 1 > /sys/block/sdb/device/delete")
        machine.wait_until_fails("test -b /dev/disk/by-uuid/${luksUuid}", timeout=30)

    def attach():
        # device_del also drops the auto-created -drive backend, not its image.
        result = machine.send_monitor_command("drive_add 0 id=drive2,if=none,file=empty0.qcow2,format=qcow2")
        assert "Error" not in result, repr(result)
        result = machine.send_monitor_command("device_add scsi-hd,id=sea16,drive=drive2,bus=scsi.0,scsi-id=1,lun=0")
        assert "Error" not in result, repr(result)
        machine.succeed("echo '- - -' > /sys/class/scsi_host/host0/scan; udevadm settle")

    def plug():
        attach()
        machine.wait_for_unit("sea16-online.service")
        machine.wait_for_unit("samba-smbd.service")
        machine.wait_for_unit("restic-backups-archive-daily.service")
        machine.succeed("systemctl start sea16-health.service")

    unplug()
    plug()
    machine.succeed("echo preserved > /archive/sentinel; sync -f /archive/sentinel")
    machine.succeed("systemctl start pheme-matrix-archive.service")
    unplug()
    for unit in ["samba-smbd.service", "pheme-matrix-archive.service",
                 "restic-backups-archive-daily.service", "archive.mount",
                 "srv-sea16.mount", "systemd-cryptsetup@sea16.service"]:
        machine.wait_until_succeeds(f"test $(systemctl show {unit} -p ActiveState --value) = inactive")
    machine.succeed("test ! -e /dev/mapper/sea16")
    machine.fail("systemctl start sea16-health.service")
    plug()
    machine.succeed("grep -x preserved /archive/sentinel; test $(wc -l < /run/archive-backups) = 2")

    # A listed mount is insufficient: a shut-down XFS must fail the health check.
    machine.succeed("xfs_io -x -c 'shutdown -f' /srv/sea16")
    machine.succeed("findmnt --mountpoint /archive")
    machine.fail("systemctl start sea16-health.service")
    machine.succeed("systemctl stop sea16-online.service archive.mount srv-sea16.mount")
    machine.succeed("systemctl start sea16-online.service; systemctl start sea16-health.service")

    # Same filesystem, wrong bind root must also fail (no false green).
    machine.succeed("systemctl stop archive.mount; mount --bind /srv/sea16/tm /archive")
    machine.fail("systemctl start sea16-health.service")
    machine.succeed("umount /archive")

    # Fail closed and stop retrying when the existing key is unusable.
    machine.succeed("systemctl stop sea16-online.service srv-sea16.mount systemd-cryptsetup@sea16.service")
    machine.succeed("mv /etc/sea16.key /etc/sea16.key.saved; echo wrong-key > /etc/sea16.key")
    unplug()
    attach()
    machine.wait_until_succeeds("test $(systemctl show sea16-online.service -p Result --value) = start-limit-hit", timeout=240)
    machine.fail("systemctl is-active samba-smbd.service")
    machine.fail("systemctl start sea16-health.service")
    machine.succeed("test ! -e /dev/mapper/sea16")
  '';
}
