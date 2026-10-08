# tmux-thumbs in a popup: pull copyable tokens (URLs, paths, hashes, IPs, ...) out of the
# visible text of the pane underneath, newest first, and fzf one.
#   enter   copy to the clipboard
#   tab     type it into the pane (like thumbs' uppercase hint)
#   ctrl-o  open it (URL or path)
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_ACTIVE_PANE_ID:?herdr did not pass HERDR_ACTIVE_PANE_ID}"

# Earlier patterns win where matches overlap, so keep the most specific first.
patterns=(
  -e '(https?|ftp|file|ssh|git)://[^[:space:]"'"'"'<>()`]+'
  -e '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}'
  -e '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
  -e '\b[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?\b'
  -e '(~|\.{1,2})?(/[[:alnum:]._@%+=:,~-]+)+/?'
  -e '[[:alnum:]._-]+(/[[:alnum:]._-]+)+\.[[:alnum:]]+(:[0-9]+){0,2}'
  -e '\b[0-9a-f]{7,40}\b'
  -e '#[0-9a-fA-F]{6}\b'
)

tokens="$(
  "$herdr" pane read "$pane" --source visible --format text |
    rg --only-matching --no-line-number "${patterns[@]}" |
    sed -E 's/[.,;:]+$//' |
    awk 'length($0) > 3 { lines[NR] = $0 } END { for (i = NR; i > 0; i--) if (i in lines && !seen[lines[i]]++) print lines[i] }'
)"
[ -n "$tokens" ] || { echo "nothing to pick"; sleep 1; exit 0; }

result="$(fzf --height 100% --no-border --prompt 'hint> ' --layout reverse --expect tab,ctrl-o \
  --header 'enter copy · tab type into pane · ctrl-o open' <<<"$tokens")" || exit 0
key="$(head -n1 <<<"$result")"
choice="$(sed -n 2p <<<"$result")"
[ -n "$choice" ] || exit 0

case "$key" in
  tab) "$herdr" pane send-text "$pane" "$choice" >/dev/null ;;
  ctrl-o)
    if command -v open >/dev/null; then open "${choice/#\~/$HOME}"; else xdg-open "${choice/#\~/$HOME}"; fi
    ;;
  *)
    if command -v pbcopy >/dev/null && [ -z "${SSH_CONNECTION:-}" ]; then
      printf '%s' "$choice" | pbcopy
    else
      # OSC 52 reaches the attached client's clipboard, including over --remote.
      printf '\e]52;c;%s\a' "$(printf '%s' "$choice" | base64 | tr -d '\n')"
    fi
    ;;
esac
