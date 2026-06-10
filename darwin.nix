{
  pkgs,
  user,
  lib,
  ...
}:

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

  system = {
    defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;

    # Declare the user that will be running `nix-darwin`.
    primaryUser = user;

    # Avoid /nix/store symlink here; sharingd sandbox blocks reads.
    activationScripts.postActivation.text = lib.mkAfter ''
      rm -f /etc/nsmb.conf
      cat > /etc/nsmb.conf <<'EOF'
      [default]
      mc_on=no
      protocol_vers_map=6
      port445=no_netbios
      signing_required=yes
      EOF
      chown root:wheel /etc/nsmb.conf
      chmod 0644 /etc/nsmb.conf
    '';
  };

  homebrew = {
    enable = true;
    # in the future: manage only through nix.. still have a few to 'port' over
    # onActivation.cleanup = "uninstall";

    taps = [
      "posthog/tap"
      "steipete/tap"
      "darrylmorley/whatcable"
    ];
    brews = [
      "cowsay"
      "posthog/tap/phrocs"
      "gemini-cli"
      "libpq" # for ruby `pg` gems through mise
      "sshpass" # ansible ssh automation
      "qemu" # virtualization goodies
      "tmuxinator" # instead of tmux.tmuxinator.enable
    ];
    casks = [
      "1password"
      "1password-cli"
      "steipete/tap/codexbar"
      "steipete/tap/repobar"
      "nikitabobko/tap/aerospace"
      "conductor" # agent session manager of choice
      "claude" # claudedesktop goes brrr
      "cleanshot"
      "font-jetbrains-mono-nerd-font"
      "ghostty" # best terminal atm
      "helium-browser" # browser that finally stuck
      "homerow" # everywhere-navigation
      "thaw"
      "karabiner-elements"
      "keybase" # keybase-gui doesn't work on OSX yet
      "kindavim" # vim-ify everything
      "linear" # linear app
      "obsidian"
      "orbstack" # container goodies on OSX
      "osaurus" # local LLM server
      "raycast" # spotlight go away
      "responsively" # browser for dev
      "sensiblesidebuttons" # handle mouse prev/next buttons in Safari
      "secretive"
      "spotify" # muuuusic
      "sonic-visualiser" # audio stegano
      "superhuman"
      "tailscale-app" # wireguard mesh goodies
      "vagrant" # + qemu = nice
      "whatcable" # usb-c/thunderbolt cable info menu bar app
    ];
  };
  # casks  = [
  #   "1password"
  #   "cleanshot"
  #   "raycast"
  # ];

  users.knownUsers = [ user ];
  users.users.${user} = {
    uid = 501;
    name = user;
    home = "/Users/${user}";
    shell = pkgs.fish;
  };
}
