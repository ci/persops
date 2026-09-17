---
name: one-password
description: "Read, store, or inject secrets with the 1Password CLI."
---

# 1Password CLI

Load before any `op` command. Use scoped service-account access first; desktop
authentication requires chat consent. Never print secret values.

## Access paths

### Service account (default)

- Use the existing `OP_SERVICE_ACCOUNT_TOKEN` for the requested vault. `~/.profile`
  may export it; check presence only, never dump the file or environment.
- Every service-account invocation must set `OP_LOAD_DESKTOP_APP_SETTINGS=false`
  and `OP_BIOMETRIC_UNLOCK_ENABLED=false`, pass the token, and keep stdin and
  secret-bearing output off the pane TTY. Use an explicit known `--vault`.
- Do not add `--account` or run `op signin` on this path.
- Token unavailable, expired, insufficiently scoped, or read failed: report the
  redacted error. Do not silently fall back to the desktop app.
- New secrets use the authorized service-account vault unless the user requested
  a personal-account write. Verify storage without printing the value.

```bash
OP_LOAD_DESKTOP_APP_SETTINGS=false \
  OP_BIOMETRIC_UNLOCK_ENABLED=false \
  OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
  op whoami </dev/null >/dev/null
```

### Desktop app (consented fallback)

For an item outside service-account scope, obtain chat consent stating the item
and purpose, unless that access is already authorized in the conversation.

- Use the active physical workstation with a usable 1Password GUI. On a headless
  or remote host, establish the appropriate authorized workstation first; do not
  start an invisible prompt or guess a different host/account.
- Inside the task's tmux window, unset `OP_SERVICE_ACCOUNT_TOKEN` before the
  desktop flow so the token cannot override account selection. Unset the two
  desktop-disabling overrides there as well.
- Default personal/work account: `my.1password.com`. Do not use
  `my.1password.eu` / Titan unless explicitly requested.
- Run `op signin --account my.1password.com` once, then batch the task's reads
  through `op run` / `op inject` where practical. The app prompt handles the
  actual unlock; no additional chat approval is needed for that same access.
- If sign-in reports success but a later command is unauthenticated, keep the
  retry in the same task window. Report blocked interaction rather than looping.

## One shared tmux session, one window per task

Run every `op` command, including version checks and service-account reads, in
the shared `op-work` session. Keep the local socket convention below. Each task
gets one window, reused for all commands/retries and killed when finished so its
exported secrets leave memory with the shell. The `shell` keeper window stays
idle; never send secret work to it or kill another task's running window.

```bash
SOCKET_DIR="${TMPDIR:-/tmp}/op-tmux-sockets"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/op.sock"
SESSION="op-work"
tmux -S "$SOCKET" has-session -t "$SESSION" 2>/dev/null ||
  tmux -S "$SOCKET" new -d -s "$SESSION" -n shell
WIN="$(tmux -S "$SOCKET" new-window -d -t "$SESSION" -n '<task-slug>' -P -F '#{window_id}')"
tmux -S "$SOCKET" send-keys -t "$WIN" -- 'OP_LOAD_DESKTOP_APP_SETTINGS=false OP_BIOMETRIC_UNLOCK_ENABLED=false op --version </dev/null' Enter
```

Send prepared commands/scripts to `$WIN`. Capture only redacted status or shape
checks. Finish with `tmux -S "$SOCKET" kill-window -t "$WIN"`. If tmux is
unavailable, stop rather than bypass this workflow.

## Targeted reads and writes

- Known item: go directly to its named vault, item, and field.
- Unknown item: use vault-scoped, metadata-only search when the user requested
  search, supplied a listing/screenshot, or the exact title guess failed. Print
  candidate titles/IDs only; never enumerate secret values or unrelated vaults.
- For items with several concealed fields, use item JSON plus the exact field
  label. Upstream observed `--fields label=...` returning a different concealed
  field. Reject missing/duplicate matching fields; validate expected shape
  without printing the value before using it.
- Prefer `op run` / `op inject`; if a temporary secret file is necessary, use
  restrictive permissions and remove it at task end.
- For GitHub secret writes, pipe the value to `gh secret set NAME --repo OWNER/REPO`;
  omit `--body` to read stdin. Honor the task's authorization for that write.
- See [CLI examples](references/cli-examples.md) for scoped read/write patterns.

## Repeated macOS prompts

Upstream observed with `op` 2.35 that disabling biometric integration alone
still read desktop settings and triggered App Data Protection. Both overrides
above are required. `OP_LOAD_DESKTOP_APP_SETTINGS` is an undocumented override:
after CLI upgrades, verify a prompt-free service-account check before continuing.

Tmux TTY reuse does not make macOS App Data permission persist across new `op`
processes. Stop a retry loop and inspect relevant panes/process names without
dumping arguments or secrets; do not repeatedly approve dialogs. Avoid unguarded
`op completion` execution in shell startup files. Do not kill active secret tasks.

Installation remains managed by persops; do not adopt upstream's machine-specific
`~/bin/op` installation recipe. For desktop integration setup, read
[get-started](references/get-started.md) only after the fallback is authorized.
