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

## Daily jobs

Seven push monitors cover Actual bank sync and the Actual, GoLinks, Home
Assistant, Kuma, ntfy, and archive backups. A separate Nix-managed timer polls
systemd every five minutes; it does not run, restart, or modify these jobs.
It reports down for a failed latest run, disabled/inactive job timer, missing
unit, or no observed successful completion in 26 hours. Observed success/failure
survives reboots in its private state directory. On a fresh install without any
completion evidence, it reports down rather than fabricating a success.

The 26-hour window accommodates DST and daily schedule jitter. Kuma's 15-minute
push deadline independently catches a stalled checker or broken delivery path.
Latest-run failure alerts arrive on the next poll; successful recovery clears
them. A success is the systemd job's exit result, not a fresh restore test or an
independent audit of bank-provider data. If observation fails, no heartbeat is
sent for that job, so its push deadline eventually reports down.

After applying OpenTofu, run `scripts/kuma-job-secrets-install`, then deploy
Amalthea. Tokens are exported from the private OpenTofu state into a root-owned
0400 file and loaded through systemd credentials, never embedded in Nix or Git.
Repeat token installation if a push monitor is recreated. Lost checker state
is reconstructed from current systemd results; after reboot, absent evidence
stays down until the next successful scheduled run.

The observer uses a dedicated unprivileged system account: Amalthea's system
D-Bus rejects transient `DynamicUser` identities. The fixed account can read
unit properties without permission to start or change units. Filesystem and
credential isolation remain enabled.
