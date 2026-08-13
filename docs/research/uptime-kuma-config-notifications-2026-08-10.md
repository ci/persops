# Uptime Kuma configuration and reusable notifications

## Finding

Uptime Kuma 2.3.2 does not provide an upstream-supported declarative
configuration API, management REST API, Terraform provider, or configuration
CLI for monitors, notifications, or status pages. Its own README describes the
application as a WebSocket SPA rather than a REST API, and the project owner
explicitly says the Socket.IO calls are internal and may change without notice.

The application does expose authenticated Socket.IO handlers for monitor,
notification, and status-page CRUD. The active third-party
`breml/uptimekuma` Terraform provider wraps that interface. Its current v0.4.0
release specifically adopts a client for Kuma 2.3.2. Deterministic
reconciliation is therefore practical without writing a custom client, but it
still depends on an unstable upstream interface and should be version-pinned
and tested when Kuma changes.

Sources:

- [Uptime Kuma 2.3.2 README](https://github.com/louislam/uptime-kuma/blob/2.3.2/README.md#L151-L158)
- [Upstream API discussion and maintainer warning](https://github.com/louislam/uptime-kuma/issues/118#issuecomment-940320063)
- [Monitor Socket.IO handlers](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/server.js#L724-L800)
- [Notification Socket.IO handlers](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/server.js#L1537-L1575)
- [Status-page Socket.IO handlers](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/socket-handlers/status-page-socket-handler.js#L268-L523)
- [`breml/uptimekuma` Terraform provider](https://github.com/breml/terraform-provider-uptimekuma)
- [Provider releases and Kuma 2.3.2 support](https://github.com/breml/terraform-provider-uptimekuma/releases/tag/v0.4.0)

## What the official interfaces actually support

- Kuma API keys authenticate the Prometheus `/metrics` endpoint; they do not
  turn the internal Socket.IO management surface into a supported API. The
  official Prometheus guide says basic authentication is permanently replaced
  for that endpoint after the first API key is created.
- The public HTTP routes expose status-page and badge data, not management CRUD.
- v2 removed the deprecated JSON backup/restore feature. Upstream supports
  backing up the data directory; this preserves state but is not configuration
  as code.
- The package has maintenance commands such as password reset, but no monitor
  or notification management CLI.

Sources:

- [Prometheus integration](https://github.com/louislam/uptime-kuma/wiki/Prometheus-Integration)
- [`/metrics` registration in 2.3.2](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/server.js#L333-L337)
- [Public HTTP API router](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/routers/api-router.js)
- [Public status-page router](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/routers/status-page-router.js)
- [v1 to v2 migration guide](https://github.com/louislam/uptime-kuma/wiki/Migration-From-v1-To-v2)
- [2.3.2 package scripts](https://github.com/louislam/uptime-kuma/blob/2.3.2/package.json)

## Recommended configuration-as-code shape

Use OpenTofu with `breml/uptimekuma` pinned to v0.4.0 for the deployed Kuma
2.3.2. Keep reviewed HCL in the repository for monitors, groups, tags,
maintenance windows, and notification bindings. Keep the Kuma admin password
and notification tokens in systemd credentials, 1Password, or private files
outside both Git and the Nix store.

Nix should continue to own the Kuma process, loopback binding, Tailnet service,
and backups. OpenTofu should own Kuma's application resources. Prefer explicit
`plan` and `apply` operations during deployment rather than applying on every
boot. A periodic `plan -detailed-exitcode` may report drift without changing
live state.

The OpenTofu state is itself sensitive: providers may persist notification
tokens and other sensitive resource attributes in plaintext even when CLI
output redacts them. Store state outside Git with restrictive permissions and
include it in the encrypted backup. The existing administrator account should
remain private Kuma state rather than being recreated declaratively.

The provider supports monitors, groups, tags, maintenance windows, and native
notification resources including ntfy and Pushover. It does not currently
provide a status-page creation resource, so status pages remain UI-managed or
would need a small custom adapter. If the provider proves unreliable after a
future Kuma upgrade, the broader fallback is a version-gated Socket.IO
reconciler that reads current state, modifies only explicitly managed resources,
supports dry-run, and verifies normalized state after applying.

Direct SQLite writes are not recommended: they bypass Kuma validation and
runtime start/stop behavior, couple us to migrations and relation tables, and
can leave the running process out of sync.

Sources:

- [Provider configuration](https://github.com/breml/terraform-provider-uptimekuma/blob/v0.4.0/docs/index.md)
- [Provider HTTP monitor resource](https://github.com/breml/terraform-provider-uptimekuma/blob/v0.4.0/docs/resources/monitor_http.md)
- [Provider ntfy notification resource](https://github.com/breml/terraform-provider-uptimekuma/blob/v0.4.0/docs/resources/notification_ntfy.md)
- [Provider Pushover notification resource](https://github.com/breml/terraform-provider-uptimekuma/blob/v0.4.0/docs/resources/notification_pushover.md)
- [OpenTofu sensitive-data guidance](https://opentofu.org/docs/language/state/sensitive-data/)
- [Upstream Python Socket.IO wrapper and compatibility table](https://github.com/lucasheld/uptime-kuma-api)

## Notifications

### Reusable self-hosted bus: ntfy

ntfy is the best reusable homelab notification endpoint here. Any application
can publish a structured notification with a normal HTTP PUT/POST; it has iOS,
Android, desktop/PWA clients, topics, priority, tags, actions, authentication,
tokens, and per-topic ACLs. Uptime Kuma 2.3.2 has a native ntfy provider that
supports basic or bearer authentication, separate down priority, templates,
tags, and a link action.

NixOS already has a native `services.ntfy-sh` module. It generates `server.yml`,
binds to `127.0.0.1:2586` by default, uses a hardened dynamic-user service, and
provides `environmentFile` specifically for declarative users/tokens without
putting secrets in the Nix store. Recommended deployment:

- `svc:notify` / `https://notify.reverse-justitia.ts.net/` on the Tailnet;
- `auth-default-access = "deny-all"`;
- one read token for personal clients and distinct write-only publisher
  identities/topics for Kuma and later applications;
- short message retention and no attachments unless needed;
- an off-host receiver for truly critical infrastructure alerts.

For instant self-hosted iOS delivery, ntfy requires forwarding opaque poll
requests to an APNS/Firebase-connected upstream such as `ntfy.sh`; the actual
message remains on the private server, but the phone must be able to reach the
Tailnet URL to fetch it.

Sources:

- [ntfy overview](https://github.com/binwiederhier/ntfy#readme)
- [ntfy publishing API](https://docs.ntfy.sh/publish/)
- [ntfy authentication and declarative ACLs](https://docs.ntfy.sh/config/#access-control)
- [ntfy self-hosted iOS delivery](https://docs.ntfy.sh/config/#ios-instant-notifications)
- [Pinned NixOS ntfy module](https://github.com/NixOS/nixpkgs/blob/e9a7635a57597d9754eccebdfc7045e6c8600e6b/nixos/modules/services/misc/ntfy-sh.nix)
- [Kuma 2.3.2 ntfy provider](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/notification-providers/ntfy.js)

### Useful alternatives

- **Pushover:** best low-maintenance external last mile. It has a simple API,
  native phone/desktop clients, priorities, and acknowledged/repeating emergency
  alerts. Individual use is a one-time USD 4.99 per platform, and the normal
  allowance is 10,000 messages/month. It is proprietary and stores delivery
  state outside the homelab, but avoids operating another notification server.
- **Apprise API:** best later if one generic endpoint must fan out by tags to
  ntfy, Pushover, email, Slack, and many other sinks. Its configuration can be
  file-backed and locked read-only, but the official API intentionally has no
  authentication or TLS; it must remain loopback-only or be tightly protected
  by Tailnet grants. Kuma's direct Apprise provider merely shells out to the
  `apprise` executable, so it also needs that binary added to the service PATH.
- **Gotify:** a good self-hosted REST/WebSocket alternative, but its official
  client story is Android plus web UI, whereas ntfy has official iOS support.
- **Generic webhook:** a transport, not a destination. Kuma can POST its
  heartbeat, monitor, and message objects or a custom template; use it only when
  there is already a durable receiver/router.
- **SMTP/email:** universal and useful as an audit/fallback channel, but weaker
  for time-critical alerts because delivery and spam filtering are outside our
  control.
- **Discord/Slack:** easy incoming webhooks and good team history, but they bind
  infrastructure alerts to a chat vendor and channel. Add them as secondary
  sinks if already used, not as the homelab's generic notification contract.

Sources:

- [Pushover message API](https://pushover.net/api)
- [Pushover pricing](https://pushover.net/pricing)
- [Apprise API](https://github.com/caronc/apprise-api#readme)
- [Kuma 2.3.2 Apprise provider](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/notification-providers/apprise.js)
- [Gotify server](https://github.com/gotify/server#readme)
- [Kuma 2.3.2 webhook payload](https://github.com/louislam/uptime-kuma/blob/2.3.2/server/notification-providers/webhook.js)
- [Slack incoming webhooks](https://api.slack.com/messaging/webhooks)
- [Discord webhooks](https://docs.discord.com/developers/resources/webhook)

## Recommendation

Manage Kuma resources with exact-pinned OpenTofu and the third-party provider;
keep Nix responsible for the service itself. For the simplest reliable phone
alerting, use Pushover as the primary critical destination. Add ntfy as the
common self-hosted notification service when a reusable topic-based endpoint
for Kuma and other applications is worth operating. A useful two-tier setup is
normal events to ntfy and high-severity failures to Pushover. Do not add Apprise
API until at least two applications need routing or fan-out that direct native
integrations and ntfy topics cannot express cleanly.

This still leaves one monitoring rule: Kuma on Amalthea cannot alert when
Amalthea itself is completely unavailable. That eventually needs a second
monitor or dead-man check in another failure domain; changing notification
providers alone cannot solve it.
