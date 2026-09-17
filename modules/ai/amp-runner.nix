{
  config,
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
  amp = "${home}/.amp/bin/amp";
  discoveryRoot = "${home}/p";
  workingDirectory = "${discoveryRoot}/persops";
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
  runner = pkgs.writeShellScript "amp-runner" ''
    shopt -s nullglob
    args=(
      ${lib.escapeShellArg amp}
      --no-tui
      --runner-id ${lib.escapeShellArg currentSystemName}
      --remote-control-terminal
    )

    for repository in ${lib.escapeShellArg discoveryRoot}/* ${lib.escapeShellArg discoveryRoot}/*/*; do
      [[ -L "$repository" || ! -e "$repository/.git" ]] && continue
      [[ "$repository" == ${lib.escapeShellArg "${discoveryRoot}/foss"}/* ]] && continue
      [[ "$repository" == */node_modules/* ]] && continue
      [[ "$repository" == "$PWD" ]] || args+=(--dir "$repository")
    done

    exec "''${args[@]}"
  '';
  arguments = [ (toString runner) ];
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
