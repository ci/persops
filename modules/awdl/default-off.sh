#!/usr/bin/env bash
set -euo pipefail

# AWDL can appear after launchd starts the job; retry briefly, then exit.
attempt=0
while [ "$attempt" -lt 120 ]; do
	if /sbin/ifconfig awdl0 down 2>/dev/null; then
		exit 0
	fi
	attempt=$((attempt + 1))
	/bin/sleep 1
done
printf 'AWDL boot default failed after 120 attempts.\n' >&2
exit 1
