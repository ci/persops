{ pkgs, currentSystemName, currentSystemUser, ... }:

let
  host = currentSystemName;
  user = currentSystemUser;

  nixEnvFile = "/etc/secrets/restic/s3.env";
  nixPasswordFile = "/etc/secrets/restic/password";
  nixRepositoryFile = "/etc/secrets/restic/repository";
in
{
  environment.systemPackages = [ pkgs.restic ];

  services.restic.backups = {
    home-hourly = {
      user = user;
      repositoryFile = nixRepositoryFile;
      initialize = true;

      passwordFile = nixPasswordFile;
      environmentFile = nixEnvFile;

      paths = [ "/home/${user}" ];

      exclude = [
        "/home/${user}/**/node_modules"
        "/home/${user}/.cache"
        "/home/${user}/.bun"
        "/home/${user}/.local/share/uv"
        "/home/${user}/.local/share/nvim"
        "/home/${user}/.local/share/Trash"
        "/home/${user}/.local/share/containers"
        "/home/${user}/.npm/_cacache"
        "/home/${user}/go/pkg/mod"
        "/home/${user}/**/.direnv"
      ];

      extraBackupArgs = [
        "--host" host
        "--tag" host
        "--exclude-caches"
        "--exclude-if-present" ".nobackup"
        "--compression" "auto"
      ];

      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };

      pruneOpts = [ ];
      runCheck = false;
    };

    home-prune-daily = {
      user = user;
      repositoryFile = nixRepositoryFile;

      passwordFile = nixPasswordFile;
      environmentFile = nixEnvFile;

      paths = [ ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

      pruneOpts = [
        "--host" host
        "--keep-hourly" "24"
        "--keep-daily" "30"
        "--keep-weekly" "8"
        "--keep-monthly" "12"
      ];
    };

    home-check-weekly = {
      user = user;
      repositoryFile = nixRepositoryFile;

      passwordFile = nixPasswordFile;
      environmentFile = nixEnvFile;

      paths = [ ];

      timerConfig = {
        OnCalendar = "Sun *-*-* 04:00:00";
        Persistent = true;
      };

      runCheck = true;
      checkOpts = [
        "--read-data-subset=5%"
      ];
    };
  };
}
