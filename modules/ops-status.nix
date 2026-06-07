{ pkgs, ... }:

let
  opsStatus = pkgs.writeShellScriptBin "ops-status" ''
    #!${pkgs.bash}/bin/bash
    set -u

    status=0
    include_remote=0

    usage() {
      printf 'usage: ops-status [--remote]\n' >&2
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --remote)
          include_remote=1
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          usage
          exit 2
          ;;
      esac
      shift
    done

    have() {
      command -v "$1" >/dev/null 2>&1
    }

    section() {
      printf '\n%s\n' "$1"
    }

    row() {
      printf '  %-24s %s\n' "$1" "$2"
    }

    note() {
      row "$1" "$2"
    }

    ok() {
      row "$1" "[ok] $2"
    }

    warn() {
      if [ "$status" -lt 1 ]; then
        status=1
      fi
      row "$1" "[warn] $2"
    }

    fail() {
      status=2
      row "$1" "[fail] $2"
    }

    first_line() {
      sed -n '1p'
    }

    short() {
      awk '{ if (length($0) > 110) print substr($0, 1, 107) "..."; else print }'
    }

    timed() {
      local seconds="$1"
      shift
      ${pkgs.coreutils}/bin/timeout -k 2s "$seconds" "$@" 2>&1
    }

    file_mtime() {
      stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
    }

    file_age() {
      local file="$1"
      local now
      local mtime
      local age

      if [ ! -e "$file" ]; then
        return 1
      fi

      now="$(date +%s)"
      mtime="$(file_mtime "$file")" || return 1
      age=$((now - mtime))

      if [ "$age" -lt 120 ]; then
        printf '%ss ago' "$age"
      elif [ "$age" -lt 7200 ]; then
        printf '%sm ago' "$((age / 60))"
      elif [ "$age" -lt 172800 ]; then
        printf '%sh ago' "$((age / 3600))"
      else
        printf '%sd ago' "$((age / 86400))"
      fi
    }

    last_nonempty() {
      local file="$1"

      if [ -f "$file" ]; then
        sed '/^[[:space:]]*$/d' "$file" | tail -n 1
      fi
    }

    check_recent_file() {
      local label="$1"
      local file="$2"
      local max_age="$3"
      local age_text
      local now
      local mtime
      local age

      if [ ! -e "$file" ]; then
        warn "$label" "missing $file"
        return
      fi

      age_text="$(file_age "$file")" || {
        warn "$label" "cannot read mtime for $file"
        return
      }
      now="$(date +%s)"
      mtime="$(file_mtime "$file")" || {
        warn "$label" "cannot read mtime for $file"
        return
      }
      age=$((now - mtime))

      if [ "$age" -gt "$max_age" ]; then
        warn "$label" "$file updated $age_text"
      else
        ok "$label" "$file updated $age_text"
      fi
    }

    check_stderr_tail() {
      local label="$1"
      local file="$2"
      local tail_line

      if [ ! -s "$file" ]; then
        ok "$label" "stderr empty"
        return
      fi

      tail_line="$(last_nonempty "$file" | short)"
      warn "$label" "stderr: $tail_line"
    }

    check_launch_agent() {
      local label="$1"
      local unit="$2"
      local out
      local exit_code
      local state_text

      if ! have launchctl; then
        warn "$label" "launchctl missing"
        return
      fi

      if ! out="$(launchctl print "gui/$(id -u)/$unit" 2>&1)"; then
        warn "$label" "not loaded"
        return
      fi

      state_text="$(printf '%s\n' "$out" | awk -F'= ' '/state =/ { print $2; exit }')"
      exit_code="$(printf '%s\n' "$out" | awk -F'= ' '/last exit code =/ { print $2; exit }')"
      if [ -z "$state_text" ]; then
        state_text="unknown state"
      fi
      if [ -z "$exit_code" ]; then
        exit_code="unknown"
      fi

      if [ "$exit_code" = "0" ]; then
        ok "$label" "$state_text, last exit 0"
      else
        warn "$label" "$state_text, last exit $exit_code"
      fi
    }

    show_system() {
      local os
      local host
      local uptime_text
      local disk_path
      local disk_text

      os="$(uname -s)"
      host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf unknown)"

      section "system"
      note "host" "$host ($os $(uname -m))"
      note "time" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
      uptime_text="$(uptime 2>/dev/null | sed 's/^ *//')"
      if [ -n "$uptime_text" ]; then
        note "uptime" "$uptime_text"
      fi

      disk_path="/"
      if [ "$os" = "Darwin" ] && [ -d /System/Volumes/Data ]; then
        disk_path="/System/Volumes/Data"
      fi
      disk_text="$(df -h "$disk_path" 2>/dev/null | awk -v path="$disk_path" 'NR == 2 { print $4 " free, " $5 " used on " path }')"
      if [ -n "$disk_text" ]; then
        note "disk" "$disk_text"
      else
        warn "disk" "cannot read $disk_path"
      fi
    }

    show_nix() {
      local version
      local generation
      local nh_version

      section "nix"
      if have nix; then
        version="$(nix --version 2>/dev/null | first_line)"
        ok "nix" "$version"
        if nix store ping --store daemon >/dev/null 2>&1; then
          ok "nix daemon" "reachable"
        else
          warn "nix daemon" "not reachable"
        fi
      else
        warn "nix" "command missing"
      fi

      if [ -e /run/current-system ]; then
        generation="$(readlink /run/current-system 2>/dev/null | sed 's#.*/##')"
        note "current system" "$generation"
      fi

      if have nh; then
        nh_version="$(nh --version 2>/dev/null | first_line)"
        note "nh" "$nh_version"
      fi
    }

    show_repo() {
      local repo
      local out
      local first

      repo="$HOME/p/persops"
      section "persops"

      if [ ! -d "$repo" ]; then
        warn "repo" "$repo missing"
        return
      fi

      if [ -d "$repo/.jj" ] && have jj; then
        if ! out="$(jj --ignore-working-copy -R "$repo" status 2>&1)"; then
          warn "jj" "$(printf '%s\n' "$out" | first_line | short)"
          return
        fi

        if printf '%s\n' "$out" | grep -q 'The working copy has no changes.'; then
          ok "jj" "clean"
        else
          first="$(printf '%s\n' "$out" | first_line | short)"
          warn "jj" "$first"
        fi
      else
        warn "jj" "not a jj repo or jj missing"
      fi
    }

    show_restic_darwin() {
      section "restic"
      check_launch_agent "backup agent" "org.nixos.restic-backup"
      check_launch_agent "prune agent" "org.nixos.restic-prune"
      check_launch_agent "check agent" "org.nixos.restic-check"
      check_recent_file "backup output" "/tmp/restic-backup.out.log" 10800
      check_recent_file "prune output" "/tmp/restic-prune.out.log" 172800
      check_recent_file "check output" "/tmp/restic-check.out.log" 777600
      check_stderr_tail "backup stderr" "/tmp/restic-backup.err.log"
      check_stderr_tail "prune stderr" "/tmp/restic-prune.err.log"
      check_stderr_tail "check stderr" "/tmp/restic-check.err.log"
    }

    show_restic_linux() {
      section "restic"
      if ! have systemctl; then
        warn "systemd" "systemctl missing"
        return
      fi

      for unit in restic-backups-home-hourly.timer restic-backups-home-prune-daily.timer restic-backups-home-check-weekly.timer; do
        if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .; then
          if systemctl is-active --quiet "$unit"; then
            ok "$unit" "active"
          else
            warn "$unit" "$(systemctl is-active "$unit" 2>/dev/null)"
          fi
        else
          warn "$unit" "not installed"
        fi
      done
    }

    show_time_machine() {
      local status_out
      local status_rc
      local latest_out
      local latest_rc
      local snapshots
      local snapshots_rc
      local tmutil_timeout

      if ! have tmutil; then
        return
      fi

      tmutil_timeout="8s"
      section "time machine"
      if status_out="$(timed "$tmutil_timeout" tmutil status)"; then
        if printf '%s\n' "$status_out" | grep -q 'Running = 1'; then
          ok "status" "running"
        elif printf '%s\n' "$status_out" | grep -q 'Running = 0'; then
          ok "status" "idle"
        else
          warn "status" "$(printf '%s\n' "$status_out" | first_line | short)"
        fi
      else
        status_rc="$?"
        if [ "$status_rc" -eq 124 ] || [ "$status_rc" -eq 137 ]; then
          warn "status" "timed out after $tmutil_timeout"
        else
          warn "status" "$(printf '%s\n' "$status_out" | first_line | short)"
        fi
      fi

      if latest_out="$(timed "$tmutil_timeout" tmutil latestbackup)" && printf '%s\n' "$latest_out" | grep -q '^/'; then
        ok "latest" "$(printf '%s\n' "$latest_out" | first_line)"
      else
        latest_rc="$?"
        if [ "$latest_rc" -eq 124 ] || [ "$latest_rc" -eq 137 ]; then
          warn "latest" "timed out after $tmutil_timeout"
        else
          warn "latest" "$(printf '%s\n' "$latest_out" | first_line | short)"
        fi
      fi

      if snapshots="$(timed "$tmutil_timeout" tmutil listlocalsnapshots /)"; then
        snapshots="$(printf '%s\n' "$snapshots" | wc -l | tr -d ' ')"
        note "local snapshots" "$snapshots"
      else
        snapshots_rc="$?"
        if [ "$snapshots_rc" -eq 124 ] || [ "$snapshots_rc" -eq 137 ]; then
          warn "local snapshots" "timed out after $tmutil_timeout"
        else
          warn "local snapshots" "$(printf '%s\n' "$snapshots" | first_line | short)"
        fi
      fi
    }

    show_network() {
      local self
      local ip

      section "network"
      if have tailscale; then
        if self="$(tailscale status --self 2>&1)" && ! printf '%s\n' "$self" | grep -qi 'failed'; then
          ip="$(tailscale ip -4 2>/dev/null | first_line)"
          if printf '%s\n' "$ip" | grep -qi 'failed'; then
            warn "tailscale" "$(printf '%s\n' "$ip" | first_line | short)"
          else
            ok "tailscale" "$ip"
          fi
        else
          warn "tailscale" "$(printf '%s\n' "$self" | first_line | short)"
        fi
      else
        warn "tailscale" "command missing"
      fi
    }

    show_desktop() {
      local version_out

      if ! have aerospace; then
        return
      fi

      section "desktop"
      version_out="$(aerospace --version 2>&1)"
      if printf '%s\n' "$version_out" | grep -q 'server version: Unknown'; then
        warn "aerospace" "server not running"
      else
        ok "aerospace" "$(printf '%s\n' "$version_out" | tail -n 1)"
      fi
    }

    show_systemd() {
      local state
      local failed_units

      if ! have systemctl; then
        return
      fi

      section "systemd"
      state="$(systemctl is-system-running 2>/dev/null)"
      case "$state" in
        running|degraded)
          if [ "$state" = "running" ]; then
            ok "system" "$state"
          else
            warn "system" "$state"
          fi
          ;;
        *)
          warn "system" "$state"
          ;;
      esac

      failed_units="$(systemctl --failed --no-legend --plain 2>/dev/null)"
      if [ -n "$failed_units" ]; then
        warn "failed units" "$(printf '%s\n' "$failed_units" | first_line | short)"
      else
        ok "failed units" "none"
      fi

      for unit in tailscaled.service samba-smbd.service; do
        if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .; then
          if systemctl is-active --quiet "$unit"; then
            ok "$unit" "active"
          else
            warn "$unit" "$(systemctl is-active "$unit" 2>/dev/null)"
          fi
        fi
      done
    }

    show_user_services() {
      local unit_state

      if ! have systemctl; then
        return
      fi

      section "agent services"
      for unit in codex-remote-control.service claude-remote-control.service; do
        unit_state="$(systemctl --user is-active "$unit" 2>/dev/null)"
        case "$unit_state" in
          active)
            ok "$unit" "active"
            ;;
          inactive|failed|activating|deactivating)
            warn "$unit" "$unit_state"
            ;;
          *)
            warn "$unit" "not available"
            ;;
        esac
      done
    }

    show_remote() {
      local out

      section "remote"
      if [ "$include_remote" -ne 1 ]; then
        note "amalthea" "skipped; use --remote"
        return
      fi

      if ! have ssh; then
        warn "ssh" "command missing"
        return
      fi

      if ! out="$(ssh -o BatchMode=yes -o ConnectTimeout=5 cat@amalthea 'hostname; systemctl is-system-running 2>/dev/null || true; systemctl is-active tailscaled.service 2>/dev/null || true; systemctl is-active samba-smbd.service 2>/dev/null || true' 2>&1)"; then
        warn "amalthea" "$(printf '%s\n' "$out" | first_line | short)"
        return
      fi

      note "amalthea" "$(printf '%s\n' "$out" | sed -n '1p')"
      note "remote system" "$(printf '%s\n' "$out" | sed -n '2p')"
      note "tailscaled" "$(printf '%s\n' "$out" | sed -n '3p')"
      note "samba" "$(printf '%s\n' "$out" | sed -n '4p')"
    }

    os="$(uname -s)"

    show_system
    show_nix
    show_repo
    if [ "$os" = "Darwin" ]; then
      show_restic_darwin
      show_time_machine
      show_desktop
    else
      show_restic_linux
      show_systemd
      show_user_services
    fi
    show_network
    show_remote

    section "summary"
    case "$status" in
      0)
        ok "overall" "clean"
        ;;
      1)
        warn "overall" "warnings present"
        ;;
      *)
        fail "overall" "failures present"
        ;;
    esac

    exit "$status"
  '';
in
{
  home.packages = [
    opsStatus
  ];
}
