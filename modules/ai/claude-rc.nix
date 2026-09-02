{
  config,
  lib,
  pkgs,
  currentSystemName,
  ...
}:
let
  home = config.home.homeDirectory;
  enabled = currentSystemName == "aglaea";
  claude = lib.getExe pkgs.claude-code;
  path = lib.concatStringsSep ":" [
    "${home}/.local/bin"
    "${config.home.profileDirectory}/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "${home}/.local/share/pnpm"
    "${home}/.npm-global/bin"
    "${home}/go/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
in
{
  launchd.agents.claude-remote-control = lib.mkIf (enabled && pkgs.stdenv.isDarwin) {
    enable = true;
    config = {
      ProgramArguments = [
        claude
        "rc"
      ];
      EnvironmentVariables = {
        HOME = home;
        PATH = path;
      };
      WorkingDirectory = home;
      KeepAlive = true;
      RunAtLoad = true;
      ThrottleInterval = 5;
      StandardOutPath = "${home}/Library/Logs/claude-remote-control.out.log";
      StandardErrorPath = "${home}/Library/Logs/claude-remote-control.err.log";
    };
  };
}
