#!/usr/bin/env bash
set -euo pipefail

uuid="$1"
for entry in '/srv/sea16:/' '/archive:/archive'; do
	path="${entry%%:*}"
	root="${entry#*:}"
	if [[ "$(findmnt --noheadings --raw --mountpoint "$path" --output UUID,FSROOT,FSTYPE)" != "$uuid $root xfs" ]]; then
		echo "$path: expected sea16 XFS mount is missing or incorrect" >&2
		exit 1
	fi
	# A stale, shut-down XFS mount still appears in mountinfo. Read metadata AND
	# directory entries so that case cannot report healthy. No probe writes.
	stat "$path/." >/dev/null
	ls -AU "$path" >/dev/null
done
stat /srv/sea16/tm/aglaea/. >/dev/null
ls -AU /srv/sea16/tm/aglaea >/dev/null
