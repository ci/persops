#!/usr/bin/env bash
set -euo pipefail

# These formerly vendored files are mutable; preserve local edits outside discovery.
pi_dir="${1:?usage: retire-pi-compound-engineering.sh PI_AGENT_DIR}"
backup_dir=""
for path in "$pi_dir"/skills/ce-* "$pi_dir/skills/lfg" "$pi_dir"/agents/ce-*.md "$pi_dir/compound-engineering"; do
	[[ -e "$path" || -L "$path" ]] || continue
	if [[ -z "$backup_dir" ]]; then
		mkdir -p "$pi_dir/backups"
		backup_dir="$(mktemp -d "$pi_dir/backups/retired-compound-engineering.XXXXXX")"
	fi
	rel="${path#"$pi_dir/"}"
	mkdir -p "$backup_dir/$(dirname "$rel")"
	mv "$path" "$backup_dir/$rel"
	echo "Retired $path -> $backup_dir/$rel" >&2
done
