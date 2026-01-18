{ pkgs, currentSystemName, currentSystemUser, ... }:

let
  host = currentSystemName;
  user = currentSystemUser;

  darwinHome = "/Users/${user}";
  darwinEnvFile = "${darwinHome}/.config/restic/s3.env";
  darwinPasswordFile = "${darwinHome}/.config/restic/password";
  darwinRepositoryFile = "${darwinHome}/.config/restic/repository";

  resticBackupScript = pkgs.writeShellScript "restic-backup-${host}" ''
    set -euo pipefail

    if [ ! -f "${darwinEnvFile}" ]; then
      echo "Missing ${darwinEnvFile}" >&2
      exit 1
    fi
    if [ ! -f "${darwinPasswordFile}" ]; then
      echo "Missing ${darwinPasswordFile}" >&2
      exit 1
    fi
    if [ ! -f "${darwinRepositoryFile}" ]; then
      echo "Missing ${darwinRepositoryFile}" >&2
      exit 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "${darwinEnvFile}"
    set +a
    repo="$(tr -d '\n' < "${darwinRepositoryFile}")"
    if [ -z "$repo" ]; then
      echo "Empty repository in ${darwinRepositoryFile}" >&2
      exit 1
    fi

    exec ${pkgs.restic}/bin/restic \
      --repo "$repo" \
      --password-file "${darwinPasswordFile}" \
      backup \
      --host "${host}" \
      --tag "${host}" \
      --exclude-caches \
      --exclude-if-present ".nobackup" \
      --one-file-system \
      --compression "auto" \
      --exclude "${darwinHome}/Library/Caches" \
      --exclude "${darwinHome}/Library/Logs" \
      --exclude "${darwinHome}/Library/Group Containers" \
      --exclude "${darwinHome}/Library/Containers/*/Data/Library/Caches" \
      --exclude "${darwinHome}/Library/CloudStorage" \
      --exclude "${darwinHome}/Library/Mobile Documents" \
      --exclude "${darwinHome}/Library/Application Support/Spotify/PersistentCache" \
      --exclude "${darwinHome}/Library/Developer/Xcode" \
      --exclude "${darwinHome}/Library/Android" \
      --exclude "${darwinHome}/Documents/Adobe" \
      --exclude "${darwinHome}/Documents" \
      --exclude "${darwinHome}/Desktop" \
      --exclude "${darwinHome}/.BurpSuite" \
      --exclude "${darwinHome}/.android" \
      --exclude "${darwinHome}/.asdf" \
      --exclude "${darwinHome}/.bun" \
      --exclude "${darwinHome}/.cache" \
      --exclude "${darwinHome}/.Trash" \
      --exclude "${darwinHome}/.local/share/mise" \
      --exclude "${darwinHome}/.local/share/nvim" \
      --exclude "${darwinHome}/.dartServer" \
      --exclude "${darwinHome}/.rustup/toolchains" \
      --exclude "${darwinHome}/.tldrc" \
      --exclude "${darwinHome}/.vscode-insiders" \
      --exclude "${darwinHome}/.windsurf" \
      --exclude "${darwinHome}/p/foss" \
      --exclude "${darwinHome}/**/node_modules" \
      "${darwinHome}"
  '';

  resticPruneScript = pkgs.writeShellScript "restic-prune-${host}" ''
    set -euo pipefail

    if [ ! -f "${darwinEnvFile}" ]; then
      echo "Missing ${darwinEnvFile}" >&2
      exit 1
    fi
    if [ ! -f "${darwinPasswordFile}" ]; then
      echo "Missing ${darwinPasswordFile}" >&2
      exit 1
    fi
    if [ ! -f "${darwinRepositoryFile}" ]; then
      echo "Missing ${darwinRepositoryFile}" >&2
      exit 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "${darwinEnvFile}"
    set +a
    repo="$(tr -d '\n' < "${darwinRepositoryFile}")"
    if [ -z "$repo" ]; then
      echo "Empty repository in ${darwinRepositoryFile}" >&2
      exit 1
    fi

    exec ${pkgs.restic}/bin/restic \
      --repo "$repo" \
      --password-file "${darwinPasswordFile}" \
      forget --prune \
      --host "${host}" \
      --keep-hourly 24 \
      --keep-daily 30 \
      --keep-weekly 8 \
      --keep-monthly 12
  '';

  resticCheckScript = pkgs.writeShellScript "restic-check-${host}" ''
    set -euo pipefail

    if [ ! -f "${darwinEnvFile}" ]; then
      echo "Missing ${darwinEnvFile}" >&2
      exit 1
    fi
    if [ ! -f "${darwinPasswordFile}" ]; then
      echo "Missing ${darwinPasswordFile}" >&2
      exit 1
    fi
    if [ ! -f "${darwinRepositoryFile}" ]; then
      echo "Missing ${darwinRepositoryFile}" >&2
      exit 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "${darwinEnvFile}"
    set +a
    repo="$(tr -d '\n' < "${darwinRepositoryFile}")"
    if [ -z "$repo" ]; then
      echo "Empty repository in ${darwinRepositoryFile}" >&2
      exit 1
    fi

    exec ${pkgs.restic}/bin/restic \
      --repo "$repo" \
      --password-file "${darwinPasswordFile}" \
      check \
      --read-data-subset=5%
  '';
in
{
  environment.systemPackages = [ pkgs.restic ];

  launchd.user.agents = {
    restic-backup = {
      command = resticBackupScript;
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 3600;
        StandardOutPath = "/tmp/restic-backup.out.log";
        StandardErrorPath = "/tmp/restic-backup.err.log";
      };
    };

    restic-prune = {
      command = resticPruneScript;
      serviceConfig = {
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
      command = resticCheckScript;
      serviceConfig = {
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
