# Uptime Kuma monitoring

OpenTofu in `infra/uptime-kuma` owns the monitors and their explicit ntfy
notification bindings. Nix owns the service. Use `scripts/uptime-kuma-config
plan` and `scripts/uptime-kuma-config apply`; credentials come from 1Password
and sensitive state stays outside Git. Avoid editing managed monitors in the UI.

## Apps and network

- Actual Budget `/health` and ntfy `/v1/health` check application health.
- Home Assistant, Homepage, and GoLinks check their HTTP front doors.
- All app checks use the same Tailnet HTTPS routes as clients, validate TLS,
  and enable certificate-expiry notifications. This does not test logged-in
  workflows or guarantee that every API works.
- Home router `aletheia` is pinged at its stable Tailnet IP `100.116.69.49`.
- Home DNS resolves `example.com` using that router directly, not a fallback
  resolver. Failure can mean router, Tailnet path, DNS daemon, or upstream DNS.

Checks run every minute; two retries mean three consecutive failed checks
before a down alert. Recovery alerts remain enabled; repeat-down reminders are
disabled. Brief service pauses for nightly backups should fit inside this grace
period. If a backup regularly takes longer, add a narrow maintenance window
instead of disabling alerts.

All alerts go to ntfy's `alerts` topic. Kuma and ntfy share Amalthea: they cannot
reliably report total host failure or their own complete outage. An independent
off-host watchdog and notification route remain separate follow-up work.
