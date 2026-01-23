{ pkgs, user, lib, ... }:

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

  homebrew = {
    enable = true;
    # in the future: manage only through nix.. still have a few to 'port' over
    # onActivation.cleanup = "uninstall";

    taps = [
      "steipete/tap"
    ];
    brews = [
      "cowsay"
      "libpq" # for ruby `pg` gems through mise
      "sshpass" # ansible ssh automation
      "qemu" # virtualization goodies
      "tmuxinator" # instead of tmux.tmuxinator.enable
    ];
    casks = [
      "steipete/tap/codexbar"
      "steipete/tap/repobar"
      "conductor" # trialing these out
      "claude" # claudedesktop goes brrr
      "cleanshot"
      "font-jetbrains-mono-nerd-font"
      "ghostty" # best terminal atm
      "homerow" # everywhere-navigation
      "jordanbaird-ice"
      "keybase" # keybase-gui doesn't work on OSX yet
      "kindavim" # vim-ify everything
      "linear-linear" # linear app
      "opencode-desktop" # let's compare to conductor
      "orbstack" # container goodies on OSX
      "ollama-app" # through brew since nixos is just client for darwin
      "readdle-spark" # trialing out email client
      "responsively" # browser for dev
      "sensiblesidebuttons" # handle mouse prev/next buttons in Safari
      "spotify" # muuuusic
      "sonic-visualiser" # audio stegano
      "tailscale-app" # wireguard mesh goodies
      "vagrant" # + qemu = nice
      "vivaldi" # tryna migrate from arc
      "windsurf" # codeium successor
      "yaak@beta" # postman much
      "zen" # tired of switching browsers
      "zed" # one-letter away ^ - NewEditorAgain?
    ];
  };
    # casks  = [
    #   "1password"
    #   "cleanshot"
    #   "raycast"
    # ];

  # Declare the user that will be running `nix-darwin`.
  system.primaryUser = user;
  users.knownUsers = [ user ];
  users.users.${user} = {
    uid = 501;
    name = user;
    home = "/Users/${user}";
    shell = pkgs.fish;
  };

  # Avoid /nix/store symlink here; sharingd sandbox blocks reads.
  system.activationScripts.postActivation.text = lib.mkAfter ''
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
}
