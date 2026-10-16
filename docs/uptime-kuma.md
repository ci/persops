# Uptime Kuma monitoring

Five reciprocal checks cover Pheme's Tailscale reachability and Matrix's public
client, federation, and two discovery endpoints. They check availability, not
authenticated message delivery; definitions live in `infra/uptime-kuma/pheme.tf`.

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

Eight push monitors cover Actual bank sync, the 6-hourly 1Password secret poll
(12-hour window, see [secrets](secrets.md)), and the Actual, GoLinks, Home
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

After applying OpenTofu, run `scripts/kuma-job-secrets-install` from the
1Password tmux session, then deploy Amalthea (or start
`opnix-secrets-poll.service`). The script publishes the tokens from private
OpenTofu state to the `persops/kuma-job-tokens` document; opnix writes them to a
root-owned 0400 file loaded through systemd credentials, never embedded in Nix
or Git. Republish if a push monitor is recreated. Lost checker state
is reconstructed from current systemd results; after reboot, absent evidence
stays down until the next successful scheduled run.

The observer uses a dedicated unprivileged system account: Amalthea's system
D-Bus rejects transient `DynamicUser` identities. The fixed account can read
unit properties without permission to start or change units. Filesystem and
credential isolation remain enabled.

## Archive disk availability and recovery

`Archive disk health` is independent of the daily backup deadline. A root-owned,
read-only `sea16-health.service` runs every two minutes (20-second timeout). It
checks the XFS UUID and mount roots at `/srv/sea16` and `/archive`, then reads
directory metadata and entries there and in the Time Machine directory. An
unmounted disk, wrong filesystem/bind mount, or XFS shutdown fails the probe.
The unprivileged checker above reports the result to Kuma every five minutes,
with a ten-minute success-age limit. That margin avoids false alarms when a poll
overlaps a running probe and must use its previous observation; failed probes
still report down on the next poll. This is not a SMART check, data checksum
verification, or a substitute for a UPS. The 15-minute missing-push deadline
still detects a broken checker/delivery path.

Amalthea's `sea16-lifecycle.nix` binds disk consumers to the mount/encryption
lifecycle: disk disappearance stops SMB and active archive jobs before unmounting
and closing LUKS. Arrival of the configured LUKS UUID requests `sea16-online`,
which opens LUKS, mounts the disk and archive bind, initializes quotas, and starts
SMB in dependency order, then queues a catch-up archive backup. It makes at most
four attempts within five minutes, 15 seconds apart; it never force-unmounts,
kills unrelated processes, or invokes filesystem repair. Normal XFS journal
replay on mount is allowed. Cryptsetup is headless: a bad/missing key fails
instead of falling back to an unattended password prompt. If another process
pins a mount or recovery fails,
the health monitor stays down; investigate rather than forcing recovery. After
resolving the cause, reset the failed units (including `sea16-online.service`)
and start `sea16-online.service` to retry.

Rollout: apply the OpenTofu monitor definition and republish job tokens as above
before deploying the Nix configuration. The deployment need not unplug the live
disk; a future device arrival activates automatic recovery. To exercise the new
ordering immediately, use a planned maintenance window for a controlled stop
and start, not a physical power pull. A UPS should power **both** Amalthea and
the HDD power adapter, with graceful host shutdown on low battery.
