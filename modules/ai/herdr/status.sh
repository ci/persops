# One herdr tab-bar status entry per call; print nothing to hide the entry.
case "${1:-}" in
  load)
    if [ -r /proc/loadavg ]; then
      read -r one _ </proc/loadavg
    else
      one="$(sysctl -n vm.loadavg | awk '{print $2}')"
    fi
    printf 'load %s\n' "$one"
    ;;
  battery)
    if command -v pmset >/dev/null; then
      pmset -g batt | awk -F'; *|\t' '/%/ {
        pct = $2; state = $3
        printf "%s%s\n", (state == "charging" || state == "charged" || state == "AC attached") ? "⚡" : "bat ", pct
      }'
    else
      for bat in /sys/class/power_supply/BAT*; do
        [ -r "$bat/capacity" ] && printf 'bat %s%%\n' "$(cat "$bat/capacity")" && break
      done
    fi
    ;;
esac
