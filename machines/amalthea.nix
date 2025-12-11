{ pkgs, ... }:

{
  imports = [
    ./hardware/amalthea.nix
    ../modules/specialization/i3.nix
  ];

  nix = {
    package = pkgs.nixVersions.latest;

    settings = {
      # We need to enable flakes
      experimental-features = "nix-command flakes";
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnsupportedSystem = true;

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;
    # Ensure stage1 brings up networking even though NetworkManager
    # disables networking.useDHCP in stage2.
    kernelParams = [
      "ip=dhcp"
      # Work around nouveau GSP shutdown hangs on recent kernels.
      "nouveau.config=NvGspRm=0"
    ];

    extraModprobeConfig = ''
      options nouveau config=NvGspRm=0
    '';

    # Remote unlock over SSH in initrd. Keep this out of the generated
    # hardware file so it doesn't get clobbered.
    initrd = {
      verbose = true;
      # Realtek RTL8125 (enp2s0) needs r8169 in stage1 for networking/SSH.
      availableKernelModules = [ "r8169" ];
      kernelModules = [ "r8169" ];

      network = {
        enable = true;

        ssh = {
          enable = true;
          port = 2222; # separate from normal sshd

          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP05x9Bg50efrFPX0NXfV45RwcsYmgpKUKTnR2Ee7LA cat"
          ];

          hostKeys = [
            "/etc/secrets/initrd/ssh_host_ed25519_key"
          ];
        };

        flushBeforeStage2 = true;

        postCommands = ''
      cat > /root/.profile <<'EOF'
      echo
      echo "To unlock root, run:"
      echo "  cryptsetup luksOpen /dev/disk/by-uuid/e12696b1-da5d-4aa3-8cda-ac2f90745068 luks-e12696b1-da5d-4aa3-8cda-ac2f90745068"
      echo
      exec /bin/sh
      EOF
      '';
      };
    };
  };

  networking.hostName = "amalthea";
  networking.networkmanager.enable = true;

  # Enable Wake-on-LAN on the wired NIC so the machine can be woken
  # from sleep/soft-off (S3/S5) via a magic packet.
  networking.interfaces.enp2s0.wakeOnLan = {
    enable = true;
    policy = [ "magic" ];
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
