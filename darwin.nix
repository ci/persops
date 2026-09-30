{
  pkgs,
  user,
  lib,
  currentSystemProfile,
  ...
}:

let
  isPersonal = currentSystemProfile == "personal";
in
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

  launchd.user.envVariables = {
    PATH = [
      "/Users/${user}/.local/bin"
      "/Users/${user}/.nix-profile/bin"
      "/etc/profiles/per-user/${user}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/opt/homebrew/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ];
    CLAUDE_CLI_PATH = "/etc/profiles/per-user/${user}/bin/claude";
    CODEX_CLI_PATH = "/etc/profiles/per-user/${user}/bin/codex";
    AMP_CLI_PATH = "/Users/${user}/.local/bin/amp";
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
      "steipete/tap"
    ]
    ++ lib.optionals isPersonal [
      "darrylmorley/whatcable"
    ];
    brews = lib.optionals isPersonal [
      "cowsay"
      "gemini-cli"
      "libpq" # for ruby `pg` gems through mise
      "sshpass" # ansible ssh automation
      "qemu" # virtualization goodies
    ];
    # The 1Password app cask is per machine (stable and beta conflict).
    casks = [
      "1password-cli"
      "steipete/tap/codexbar"
      "nikitabobko/tap/aerospace"
      "claude" # claudedesktop goes brrr
      "cleanshot"
      "font-jetbrains-mono-nerd-font"
      "ghostty" # best terminal atm
      "homerow" # everywhere-navigation
      "thaw"
      "karabiner-elements"
      "raycast" # spotlight go away
      "sensiblesidebuttons" # handle mouse prev/next buttons in Safari
      "secretive"
      "spotify" # muuuusic
    ]
    ++ lib.optionals isPersonal [
      "steipete/tap/repobar"
      "keybase" # keybase-gui doesn't work on OSX yet
      "linear" # linear app
      "obsidian"
      "orbstack" # container goodies on OSX; commercial use needs a paid license
      "osaurus" # local LLM server
      "sonic-visualiser" # audio stegano
      "superhuman"
      "tailscale-app" # personal tailnet; work hosts must stay off it
      "vagrant" # + qemu = nice
      "whatcable" # usb-c/thunderbolt cable info menu bar app
    ];
  };

  users.knownUsers = [ user ];
  users.users.${user} = {
    uid = 501;
    name = user;
    home = "/Users/${user}";
    shell = pkgs.fish;
  };
}
