# Private notifications

Amalthea runs ntfy on loopback and exposes it only as the named Tailscale
service `svc:notify` at <https://notify.reverse-justitia.ts.net/>. The short
links `go/notify` and `go/n` point there.

Authentication is deny-by-default and provisioned from the 1Password item
`ntfy-amalthea`:

- `cat` has read/write access to all topics for personal clients;
- `uptime-kuma` has write-only access to the `alerts` topic;
- both use dedicated bearer tokens; passwords remain available for interactive
  login.

The declarative values are installed outside Git and the Nix store:

```sh
./scripts/ntfy-secrets-install
```

ntfy keeps seven days of messages. `upstream-base-url = "https://ntfy.sh"`
enables instant iOS notifications by forwarding an opaque poll request; message
contents remain on Amalthea, and the phone still needs Tailnet access to fetch
them. Subscribe the mobile app to the `alerts` topic on the private server and
use the personal token from 1Password.

## Uptime Kuma

OpenTofu owns the `ntfy` notification channel in Kuma. Its state is sensitive
and lives outside Git under `$XDG_STATE_HOME/persops/uptime-kuma` (or
`~/.local/state/persops/uptime-kuma`). Plan and apply explicitly:

```sh
./scripts/uptime-kuma-config plan
./scripts/uptime-kuma-config apply
```

The provider is pinned to `breml/uptimekuma` 0.4.0. The generic notification
resource is intentional: in 0.4.0 the typed ntfy resource declares credential
fields but does not send them during create/update. Recheck this workaround and
the provider's internal Socket.IO compatibility whenever Kuma or the provider
is upgraded.

The channel is the default for new monitors. Existing monitors are attached on
channel creation; `apply_existing` is a one-shot action, so subsequent refreshes
ignore that flag. Monitor definitions are not managed by this configuration.

The ntfy state directory has a nightly restic backup tagged `ntfy`. This does
not fix the shared failure domain: if Amalthea or its Tailnet path is completely
down, neither Kuma nor ntfy can deliver an alert. Add an off-host dead-man check
for that case.

## Sources

- [ntfy access control](https://docs.ntfy.sh/config/#access-control)
- [ntfy iOS instant notifications](https://docs.ntfy.sh/config/#ios-instant-notifications)
- [NixOS ntfy module](https://github.com/NixOS/nixpkgs/blob/46db2e09cbf86d00267a656ad245bd0cc2c5542b/nixos/modules/services/misc/ntfy-sh.nix)
- [Uptime Kuma ntfy implementation](https://github.com/louislam/uptime-kuma/blob/2.5.3/server/notification-providers/ntfy.js)
- [Provider 0.4.0 ntfy resource](https://github.com/breml/terraform-provider-uptimekuma/blob/v0.4.0/internal/provider/resource_notification_ntfy.go)
