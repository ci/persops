# Actual bank sync and currency reconciliation

`actual-bank-sync.timer` runs once per day at 06:00 Europe/Bucharest with up to
15 minutes of jitter. The existing Actual restic backup runs around 01:30,
before the sync.

The service makes one bank-sync attempt and does not retry automatically. It
refuses to run unless that backup completed successfully within the last 26
hours. This covers the daily cadence, randomized delay, and DST while still
blocking the next sync after a missed backup. Immediately before any bank sync
or reconciliation it also writes a
mode-`0600` Actual export plus SHA-256 sidecar under
`/var/lib/actual-bank-sync/recovery`, retaining the newest seven exports.

The worker uses the official `@actual-app/api` package at exactly the same
version as `actual-server`. Nix evaluation fails if those versions drift.

## Private configuration

The Actual password and budget sync ID stay outside the Nix store:

```text
/etc/secrets/actual-automation/password
/etc/secrets/actual-automation/sync-id
/etc/secrets/actual-automation/enabled
```

All three files are root-owned mode `0400`; the password and sync ID are
exposed to the dynamic service user with systemd credentials. The `enabled`
marker file is an explicit activation gate, including for manual starts.
The account IDs, names, currencies, stable
bridge rates, dedicated adjustment payee, and dedicated FX category are
private-repository configuration in `modules/actual-bank-sync.nix`.

The payee/category IDs are pinned from the supervised setup after the category
reorganization. The worker validates both ID and name before taking a recovery
export, syncing a bank, or changing a transaction.

## Currency behavior

The two post-import bridge rules for each foreign account must remain present.
They put every incoming EUR/GBP amount into a stable RON representation before
Actual performs imported-ID and fuzzy transaction matching. That bridge value
is permanent: the worker never changes a bank row's amount or note after sync.
It instead creates worker-owned companion transactions whose amount is the
difference between the bridge value and the desired historical RON value.

The worker:

- leaves pending transactions at the bridge rate;
- values cleared ordinary rows at the transaction-date ECB rate, using the
  prior published business day when needed, through one companion in the same
  account and category;
- preserves both halves and the link of a cross-currency Actual transfer, then
  adds equal-and-opposite companions to the foreign and RON accounts;
- pairs provider exchange legs by their shared `entry_reference`, uses the
  exact RON leg rather than ECB, and categorizes the two bank legs plus the
  companion to the dedicated FX category;
- records source row ID, role, original foreign amount, currency, effective
  rate, rate date, and source in a versioned companion marker;
- keeps companions cleared but unreconciled, with no imported ID, raw bank
  data, split, or transfer link. If bank matching ever absorbs one, the worker
  fails closed.

For bank-synced rows, the original foreign amount and currency come from
`raw_synced_data`, not from the note. Starting balances use the legacy bridge
note. Every source amount must equal the configured bridge conversion before
it can be reconciled.

The worker refuses the whole reconciliation batch if rules, accounts, the
dedicated payee/category, source bridge amounts, transfer pairs, provider
exchange pairs, or companion invariants drift, or if a foreign transaction is
split. After applying a batch it syncs and reruns the planner; any remaining
operation or error fails the service. If an API write fails mid-plan, the
worker replans the partial state and reports whether the next run can resume
it; the pre-run export remains available for a full restore.

`balance_current` from Enable Banking remains the bank's native-currency
balance. Actual's ledger balance is RON after conversion, so those two fields
are intentionally not compared or overwritten by the worker.

## Operations

Inspect the units:

```sh
systemctl status actual-bank-sync.timer
systemctl status actual-bank-sync.service
journalctl -u actual-bank-sync.service
```

The rollout gate is: fresh live export, creation or selection of the dedicated
payee and category, pinned IDs in Nix, a plan-only run, a verified restic
backup, and one supervised reconciliation. Remove the `enabled` marker to
disable both scheduled and manual runs without changing the configuration.

After setup, a manual run is:

```sh
sudo systemctl start actual-bank-sync.service
```

Before a manual migration or repair, first run and verify
`restic-backups-actual-daily.service`.
