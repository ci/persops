{ pkgs, currentSystemName, currentSystemUser, ... }:

let
  host = currentSystemName;
  user = currentSystemUser;
  darwinHome = "/Users/${user}";
  resticBackupWrapperPath = "${darwinHome}/.local/bin/restic-backup";
  resticPruneWrapperPath = "${darwinHome}/.local/bin/restic-prune";
  resticCheckWrapperPath = "${darwinHome}/.local/bin/restic-check";
in
{
  environment.systemPackages = [ pkgs.restic ];

  launchd.user.agents = {
    restic-backup = {
      serviceConfig = {
        ProgramArguments = [ resticBackupWrapperPath ];
        EnvironmentVariables = {
          RESTIC_HOST = host;
          RESTIC_TAG = host;
        };
        RunAtLoad = true;
        StartInterval = 3600;
        StandardOutPath = "/tmp/restic-backup.out.log";
        StandardErrorPath = "/tmp/restic-backup.err.log";
      };
    };

    restic-prune = {
      serviceConfig = {
        ProgramArguments = [ resticPruneWrapperPath ];
        EnvironmentVariables = {
          RESTIC_HOST = host;
        };
        RunAtLoad = true;
        StartCalendarInterval = {
          Hour = 3;
          Minute = 15;
        };
        StandardOutPath = "/tmp/restic-prune.out.log";
        StandardErrorPath = "/tmp/restic-prune.err.log";
      };
    };

    restic-check = {
      serviceConfig = {
        ProgramArguments = [ resticCheckWrapperPath ];
        EnvironmentVariables = {
          RESTIC_HOST = host;
        };
        RunAtLoad = true;
        StartCalendarInterval = {
          Weekday = 0;
          Hour = 4;
          Minute = 0;
        };
        StandardOutPath = "/tmp/restic-check.out.log";
        StandardErrorPath = "/tmp/restic-check.err.log";
      };
    };
  };
}
