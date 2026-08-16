{
  config,
  inputs,
  lib,
  pkgs,
  currentSystemName,
  ...
}:
let
  home = config.home.homeDirectory;
  enabled = builtins.elem currentSystemName [
    "aglaea"
    "amalthea"
  ];
  amp = lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.amp;
  workingDirectory = "${home}/p";
  path = lib.concatStringsSep ":" (
    lib.optionals pkgs.stdenv.isDarwin [ "/bin" ]
    ++ lib.optionals pkgs.stdenv.isLinux [ "/run/wrappers/bin" ]
    ++ [
      "${home}/.local/bin"
      "${config.home.profileDirectory}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ]
  );
  arguments = [
    amp
    "--no-tui"
    "--runner-id"
    currentSystemName
    "--remote-control-terminal"
  ];
in
{
  launchd.agents.amp-runner = lib.mkIf (enabled && pkgs.stdenv.isDarwin) {
    enable = true;
    config = {
      ProgramArguments = arguments;
      EnvironmentVariables = {
        HOME = home;
        PATH = path;
      };
      WorkingDirectory = workingDirectory;
      KeepAlive = true;
      ProcessType = "Background";
      RunAtLoad = true;
      ThrottleInterval = 5;
      StandardOutPath = "${home}/Library/Logs/amp-runner.out.log";
      StandardErrorPath = "${home}/Library/Logs/amp-runner.err.log";
    };
  };

  systemd.user.services.amp-runner = lib.mkIf (enabled && pkgs.stdenv.isLinux) {
    Unit = {
      Description = "Amp remote thread runner";
      # A deployment may update this unit; keep its controller alive through activation.
      X-SwitchMethod = "keep-old";
    };
    Service = {
      ExecStart = lib.escapeShellArgs arguments;
      Environment = [ "PATH=${path}" ];
      WorkingDirectory = workingDirectory;
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
