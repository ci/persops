# Amalthea metrics

Open <https://home.reverse-justitia.ts.net/grafana/> from a personal,
user-owned Tailscale device. The Home page also links to Grafana. Tailscale
Serve supplies identity; Grafana gives those users Viewer access. There is no
password/anonymous login or initial admin account. Tagged servers do not have
a user identity and cannot log in. Dashboards, datasource, alerts and notification
policy are managed in `modules/monitoring`, not through the UI.

The existing `svc:home` HTTPS service also serves `/grafana`; no new Tailscale
service approval, ACL grant, public exposure or firewall port is required.
Tailscale strips the prefix and replaces incoming identity headers. Grafana
trusts that header only from loopback; local processes are inside this trust
boundary. The backend and all exporters also bind only to loopback.
Grafana queries through vmauth's query endpoint allowlist on port 8427; ingestion
and administrative paths are denied, including GET requests with bodies through
Grafana's datasource proxy. vmauth's own internal API uses a separate loopback
listener on port 8426.

## Collection and storage

VictoriaMetrics scrapes every minute and retains 30 days. Its memory allowance
is 512 MiB and it stops ingestion below 10 GiB free disk space. This is a free
space safeguard, not a fixed database-size quota. Monitor actual storage growth.

- Node Exporter: CPU, memory, swap, filesystems, disk I/O, network and selected
  systemd services. These are system services; user services and containers need
  separate coverage in the next phase.
- smartctl exporter: internal NVMe only, every minute. It does not probe/wake
  USB disks. The existing Kuma archive probe remains responsible for mount health.
- Grafana, VictoriaMetrics, the query proxy and ntfy export their own operational metrics.

The overview and storage dashboards include cumulative NVMe errors and spare
history. Existing errors and reduced spare stay amber even when SMART passes
and the daily regression monitor recovers. Historical data starts on deployment;
the pre-existing daily JSONL history remains on disk and is backed up.

## Alerting

Grafana alerts on new NVMe media errors, spare drops, critical warnings, spare
at/below its reported threshold, sustained temperature above 70 C, filesystems
over 90%, memory availability below 5%, and failed scrapes. Missing metric data
and evaluation errors also notify; initial rate queries need two samples.
New-error and spare-drop notifications cover a rolling 30-minute window.

Alerts and recoveries use ntfy's existing `alerts` topic. This phase shares the
existing write-only `uptime-kuma` notification credential, rendered by opnix
into a root-only Grafana environment file. No credentials enter Git/Nix store.
Kuma continues to own availability and scheduled-job checks, including its daily
NVMe regression check. Pheme's independent watcher remains unchanged; Grafana
cannot report a total Amalthea outage from the failed machine.

`restic-backups-monitoring-daily` runs nightly around 03:00. It takes an online
SQLite backup of Grafana and backs that up with `/var/lib/nvme-health` to the
existing Storage Box repository. Grafana's local database encryption key is
generated once as application state, with mode 0600, and backed up alongside
the database. Restore both together; a missing key with an existing database
fails startup rather than silently generating a replacement. External ntfy
credentials continue to come from opnix. The 30-day metrics database is disposable and
is not copied live into Restic. Backup freshness coverage is a follow-up.

## Verification and next phase

Check `grafana`, `grafana-metrics-proxy`, `victoriametrics`, `prometheus-node-exporter`, and
`prometheus-smartctl-exporter` with systemctl. Query
`http://127.0.0.1:8428/api/v1/query?query=up` locally; all six targets should be
1. Grafana's local `/api/health` should return 200; protected APIs without an
identity must return 401. An HTTP request carrying a fake identity through
Tailscale must not retain that identity.

Next: scrape Kuma with a dedicated API key, export durable scheduled-job success
timestamps, add persistent container metrics, and install an Alloy push agent
on Aglaea with explicit sleep/offline semantics. Extend the independent watchdog
to cover this telemetry pipeline. Ergane remains isolated.
