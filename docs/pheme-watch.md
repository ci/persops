# Reciprocal monitoring

Amalthea's Kuma checks Pheme over Tailscale ICMP and four public Matrix HTTP
endpoints (client, federation, client/server discovery). These prove reachability
and HTTPS availability, not authenticated message delivery or federation end-to-end.
Configuration: `infra/uptime-kuma/pheme.tf`; apply with the existing
`scripts/uptime-kuma-config` workflow.

Pheme runs a small Python/systemd watcher independently of Matrix containers:

- TSMP checks Amalthea and aletheia's encrypted Tailscale transport. TSMP stops
  before the peer OS/application ACLs; no new host/SSH grants are needed.
- HTTPS checks private ntfy's `/v1/health` endpoint, including DNS and TLS.
- Three consecutive failures trigger DOWN; the next success triggers RECOVERED.
  Polling is every 60 seconds after completion, so detection takes roughly 3 minutes.
- Normal alerts publish to private `alerts` with a separate `pheme-watch` user
  allowed to **write only** that topic. Its token cannot subscribe or write others.
- If private publishing fails, send minimal outage text to a free ntfy.sh topic.
  Recovery goes to whichever route accepted DOWN, including hosted fallback.
  Failed sends retry each poll. State survives restarts; a crash between acceptance
  and saving state can duplicate a message (at-least-once best effort).

## Security and secrets

The fallback name is 256 random bits, stored as `pheme_fallback_topic` in
`Personal/ntfy-amalthea` in 1Password, alongside `pheme_watch_token` and
`pheme_watch_password_hash`. Never commit or log the topic. Free ntfy.sh topics
have **no authenticated ownership**: anyone obtaining the name can read or forge
messages. Use only generic outage text, never logs, account data, or credentials.
Rotate the topic and resubscribe clients if leaked. Hosted delivery depends on
ntfy.sh and its free-tier limits; no availability guarantee.

Add a second subscription in the phone ntfy app: server `https://ntfy.sh`, topic
copied from that 1Password field, no login required. Keep the existing private
`alerts` subscription. On the laptop open the topic URL on ntfy.sh, subscribe,
and allow notifications; its permissions/subscriptions are separate from private
ntfy. Publish acceptance alone does not prove the phone displayed a notification.

The Tailscale policy needs this **single grant**, preserving all existing isolation:

```json
{"src":["100.75.219.10"],"dst":["svc:notify"],"ip":["tcp:443"]}
```

Add a policy test for that source accepting `svc:notify:443` and denying
`svc:actual:443`, `svc:uptime:443`, `tag:server:22`, and router port 53.
Do not grant all `tag:public` nodes, or add public Funnel exposure.

## Install/update

Use one dedicated, signed-in 1Password tmux session. Provision the named fields
first (`ntfy token generate`, `ntfy user hash`, and a cryptographic random topic).
Then, from the reviewed source checkout:

```sh
bash scripts/ntfy-secrets-install
ssh amalthea sudo systemctl restart ntfy-sh
bash scripts/pheme-watch-install
```

The installer targets only Pheme, stages exact source, verifies systemd units,
installs root-owned code and root-only credentials, then enables the timer.
No NixOS switch, packages, Docker, Matrix configuration, or other services change.
The watcher runs unprivileged with a systemd credential and a private state
directory; only tailscaled's local socket and outbound HTTPS/TSMP are used.

Check `systemctl status pheme-watch.timer` and `journalctl -u pheme-watch.service`.
The journal reports boolean probe/delivery results, never secret URLs. A failed
delivery sets service failure and is retried by the timer. State lives at
`/var/lib/pheme-watch/state.json`; do not remove during an incident.

Test without disturbing services using a transient systemd unit with the same
`User=pheme-watch`, `LoadCredential=credentials.json:/etc/secrets/pheme-watch/credentials.json`,
and `/usr/bin/python3 /opt/persops-pheme-watch/watch.py --test primary` (or `fallback`).
Tests send explicitly labeled messages and do not change incident state.
Verify the writer gets HTTP403 when reading `alerts` or publishing another topic.

To disable, stop/disable `pheme-watch.timer`, then stop `pheme-watch.service`.
Keep credentials/state until any pending recovery has been delivered. Remove the
narrow grant and dedicated ntfy account only when decommissioning.

## Limits

Both hosts monitor each other, but neither can report if both lose connectivity.
Kuma cannot send its own outage alert from a dead Amalthea; Pheme covers that case.
A separate external heartbeat service would be needed to detect simultaneous
failure or a broken watcher. Public Matrix checks may fail during home WAN loss;
the off-host watcher supplies the independent perspective. Existing ntfy
`upstream-base-url` is an iOS wake-up relay, not this fallback mechanism.
