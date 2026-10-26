#!/usr/bin/env bash
set -euo pipefail

awdl_state() {
	/sbin/ifconfig awdl0 | /usr/bin/awk '
    NR == 1 { print ($0 ~ /[<,]UP[,>]/ ? "on" : "off") }
  '
}

show_state() {
	local current
	current=$(awdl_state)
	printf 'AWDL is %s\n' "$current"
}

usage() {
	printf 'Usage: awdl [on|off|toggle|status]\n' >&2
	exit 2
}

case "${1:-status}" in
status)
	[ "$#" -le 1 ] || usage
	show_state
	exit 0
	;;
on | off | toggle)
	[ "$#" -eq 1 ] || usage
	target=$1
	;;
*) usage ;;
esac

current=$(awdl_state)
if [ "$target" = toggle ]; then
	if [ "$current" = on ]; then target=off; else target=on; fi
fi
if [ "$current" = "$target" ]; then
	show_state
	exit 0
fi

if [ "$target" = on ]; then action=up; else action=down; fi
if [ "$(/usr/bin/id -u)" -eq 0 ]; then
	/sbin/ifconfig awdl0 "$action"
elif [ -t 0 ]; then
	/usr/bin/sudo /sbin/ifconfig awdl0 "$action"
else
	# Use macOS authorization when there is no terminal for sudo to prompt in.
	/usr/bin/osascript -e "do shell script \"/sbin/ifconfig awdl0 $action\" with administrator privileges"
fi

/bin/sleep 1
actual=$(awdl_state)
printf 'AWDL is %s\n' "$actual"
if [ "$actual" != "$target" ]; then
	printf 'macOS did not leave AWDL %s; no background enforcer is installed.\n' "$target" >&2
	exit 1
fi
