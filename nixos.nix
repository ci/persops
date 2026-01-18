{ pkgs, user, ... }:

{
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://codex-cli.cachix.org"
      "https://claude-code.cachix.org"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "codex-cli.cachix.org-1:1Br3H1hHoRYG22n//cGKJOk3cQXgYobUel6O8DgSing="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  # We need an XDG portal for various applications to work properly,
  # such as Flatpak applications.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  environment = {
    # https://github.com/nix-community/home-manager/pull/2408
    pathsToLink = [ "/share/fish" "/bin" ];

    # Add ~/.local/bin to PATH
    localBinInPath = true;

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    systemPackages = with pkgs; [
      gnumake
      killall
      xclip
      chromium

      # Webcam tooling/viewer (works over XRDP/X11).
      cheese
      v4l-utils

      # For hypervisors that support auto-resizing, this script forces it.
      # I've noticed not everyone listens to the udev events so this is a hack.
      (writeShellScriptBin "xrandr-auto" ''
      xrandr --output Virtual-1 --auto
      '')
    ];
  };

  system.activationScripts.linkCoreutilsBin = ''
    mkdir -p /bin
    for exe in ${pkgs.coreutils}/bin/*; do
      name="$(basename "$exe")"
      ln -sf "$exe" "/bin/$name"
    done
  '';

  programs = {
    # support for dynamically linked executables, i.e. ones through uvx / bunx etc
    nix-ld.enable = true;
    nix-ld.libraries = with pkgs; [
      # additional libraries to be linked, not through environment.systemPackages
      stdenv.cc.cc.lib
    ];

    # Since we're using fish as our shell
    fish.enable = true;

    mosh.enable = true;

    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ user ];
    };
  };

  users.mutableUsers = false;
  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    extraGroups = [ "networkmanager" "docker" "wheel" "video" ];
    shell = pkgs.fish;
    hashedPassword = "$6$PMNZvv84d34ZY2BK$CEhbBGRm79WxIxFE5j4aY6l1/2HPqSjvFEXEhbgYJHaMoR9.A2/HHq2ninahWRVMaPQKQc8xfE7AZkf4Bm3CD/";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP05x9Bg50efrFPX0NXfV45RwcsYmgpKUKTnR2Ee7LA cat"
    ];
  };

  time.timeZone = "Europe/Bucharest";

  i18n = {
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Keep the virtual console (TTY) keymap in sync with X11.
  console.useXkbConfig = true;

  # Virtualization settings
  virtualisation.docker.enable = true;

  security.sudo.wheelNeedsPassword = false;

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
      settings.PermitRootLogin = "no";
    };

    xrdp = {
      enable = true;
      defaultWindowManager = "startxfce4";
      openFirewall = true;
    };

    # Shared X11 configuration for specialisations
    xserver = {
      enable = true;
      xkb.layout = "us";
      dpi = 220;

      desktopManager = {
        xterm.enable = false;
        wallpaper.mode = "fill";
        xfce.enable = true;
      };

      displayManager.lightdm.enable = true;
    };

    displayManager.defaultSession = "xfce";

    # Enable tailscale. We manually authenticate when we want with
    # "sudo tailscale up". If you don't use tailscale, you should comment
    # out or delete all of this.
    tailscale.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "ignore";
    };
  };

  # Manage fonts. We pull these from a secret directory since most of these
  # fonts require a purchase.
  fonts = {
    fontDir.enable = true;

    packages = [
      pkgs.fira-code
      pkgs.jetbrains-mono
    ];
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';
}
