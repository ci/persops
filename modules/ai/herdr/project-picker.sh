# Pick a project (a directory holding .git or .jj) and focus the herdr workspace already
# open there, or create one. A herdr take on `tms`: same search roots and exclusions.
# modules/rex.nix builds a Rex copy that sets REX_SESSIONS_LUA and uses Rex sessions instead.
if [ -n "${REX_SESSIONS_LUA:-}" ]; then
  # dir, label and session ID for every terminal in every Rex session; pwd is a file://host/ URL
  open_terminals() {
    rex "do" "$REX_SESSIONS_LUA" --json |
      jq -r '.[] | .pwds[]? as $pwd | [($pwd | sub("^file://[^/]*"; "")), .label, .session_id] | @tsv'
  }
  focus() { rex "do" session.select "session_id=$1" >/dev/null; }
  create() {
    # The app stays on its current session after `rex new`, so select the new one.
    focus "$(rex new "$(basename "$1")" --cwd "$1" --json | jq -r .session_id)"
  }
else
  herdr="${HERDR_BIN_PATH:-herdr}"
  open_terminals() {
    "$herdr" pane list | jq -r --argjson ws "$("$herdr" workspace list)" '
      ($ws.result.workspaces | map({key: .workspace_id, value: .label}) | from_entries) as $label
      | .result.panes[]
      | ([.foreground_cwd // .cwd, .cwd] | unique[] | select(. != null)) as $dir
      | [$dir, $label[.workspace_id], .workspace_id]
      | @tsv
    '
  }
  focus() { "$herdr" workspace focus "$1" >/dev/null; }
  create() { "$herdr" workspace create --cwd "$1" --label "$(basename "$1")" --focus >/dev/null; }
fi

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

# dir \t label \t workspace or session ID, one row per terminal
open_rows="$(open_terminals | sort -u)"
# Directory -> label of the workspace that already has a pane there.
open_dirs="$(cut -f1,2 <<<"$open_rows")"

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
id="$(awk -F'\t' -v dir="$dir" '$1 == dir { print $3; exit }' <<<"$open_rows")"
if [ -n "$id" ]; then
  focus "$id"
else
  create "$dir"
fi
