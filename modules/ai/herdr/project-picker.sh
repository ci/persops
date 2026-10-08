# Pick a project (a directory holding .git or .jj) and focus the herdr workspace already
# open there, or create one. A herdr take on `tms`: same search roots and exclusions.
herdr="${HERDR_BIN_PATH:-herdr}"

excludes=(
  node_modules .venv target .elixir_ls _build deps dist assets public vendor .sass-cache
  wp-content tmp cache .next .vinxi .output .react-router .expo opensrc .context
)
exclude_args=()
for dir in "${excludes[@]}"; do
  exclude_args+=(--exclude "$dir")
done

list_projects() {
  # .git may be a file (worktrees), so match both types and prune at the marker.
  if [ -d "$HOME/p" ]; then
    fd --hidden --no-ignore --prune --max-depth 6 --type d --type f \
      "${exclude_args[@]}" '^\.(git|jj)$' "$HOME/p" --exec dirname '{}'
  fi
  if [ -d "$HOME/ctf" ]; then
    fd --max-depth 1 --type d . "$HOME/ctf" --exec echo '{}'
  fi
}

panes="$("$herdr" pane list)"
labels="$("$herdr" workspace list)"

# Directory -> label of the workspace that already has a pane there.
open_dirs="$(
  jq -r --argjson ws "$labels" '
    ($ws.result.workspaces | map({key: .workspace_id, value: .label}) | from_entries) as $label
    | .result.panes[]
    | [(.foreground_cwd // .cwd), $label[.workspace_id]]
    | @tsv
  ' <<<"$panes" | sort -u
)"

selection="$(
  list_projects | sort -u | awk -F'\t' -v home="$HOME" -v open="$open_dirs" '
    BEGIN {
      n = split(open, rows, "\n")
      for (i = 1; i <= n; i++) { split(rows[i], f, "\t"); if (f[1] != "") label[f[1]] = f[2] }
    }
    {
      shown = $0; sub("^" home, "~", shown)
      if ($0 in label) print "0\t" $0 "\t● " shown "  [" label[$0] "]"
      else print "1\t" $0 "\t  " shown
    }
  ' | sort -t "$(printf '\t')" -k1,1 -s | cut -f2- |
    fzf --height 100% --no-border --delimiter '\t' --with-nth 2 --prompt 'project> ' --no-sort --layout reverse \
      --header '● = already open' \
      --preview 'ls -A {1} | head -60' --preview-window 'right,40%,border-left'
)" || exit 0

dir="${selection%%$'\t'*}"
workspace_id="$(
  jq -r --arg dir "$dir" '
    [.result.panes[] | select((.foreground_cwd // .cwd) == $dir or .cwd == $dir)][0].workspace_id // empty
  ' <<<"$panes"
)"
if [ -n "$workspace_id" ]; then
  "$herdr" workspace focus "$workspace_id" >/dev/null
else
  "$herdr" workspace create --cwd "$dir" --label "$(basename "$dir")" --focus >/dev/null
fi
