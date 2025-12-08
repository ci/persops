{ pkgs, user, ... }:

{
  homebrew = {
    enable = true;
    # in the future: manage only through nix.. still have a few to 'port' over
    # onActivation.cleanup = "uninstall";

    taps = [ ];
    brews = [
      "cowsay"
      "libpq" # for ruby `pg` gems through mise
      "sshpass" # ansible ssh automation
      "qemu" # virtualization goodies
      "tmuxinator" # instead of tmux.tmuxinator.enable
    ];
    casks = [
      "claude" # claudedesktop goes brrr
      "claude-code" # codesonnet ftw
      "codex"
      "font-jetbrains-mono-nerd-font"
      "ghostty" # best terminal atm
      "homerow" # everywhere-navigation
      "keybase" # keybase-gui doesn't work on OSX yet
      "kindavim" # vim-ify everything
      "linear-linear" # linear app
      "orbstack" # container goodies on OSX
      "ollama-app" # through brew since nixos is just client for darwin
      "readdle-spark" # trialing out email client
      "responsively" # browser for dev
      "sensiblesidebuttons" # handle mouse prev/next buttons in Safari
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
    #   "claude"
    #   "cleanshot"
    #   "discord"
    #   "fantastical"
    #   "google-chrome"
    #   "hammerspoon"
    #   "imageoptim"
    #   "istat-menus"
    #   "monodraw"
    #   "raycast"
    #   "rectangle"
    #   "screenflow"
    #   "slack"
    #   "spotify"
    # ];
    #
    # brews = [
    #   "gnupg"
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
}
