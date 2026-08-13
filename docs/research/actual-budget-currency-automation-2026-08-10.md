# Actual Budget currency automation on Amalthea

## Finding

Deterministic automation is supported through Actual's official Node client,
`@actual-app/api`, and its CLI wrapper. Actual does not expose a conventional
REST API: the client downloads a local budget copy, runs the Actual engine
headlessly, and synchronizes changes back to the server.

Sources:

- [Using the API](https://actualbudget.org/docs/api/)
- [API reference](https://actualbudget.org/docs/api/reference/)
- [CLI](https://actualbudget.org/docs/api/cli/)

Amalthea currently runs Actual 26.7.0. Both `@actual-app/api@26.7.0` and
`@actual-app/cli@26.7.0` exist, so the automation can be pinned in lockstep with
the server. The pinned Nixpkgs revision packages `actual-server` 26.7.0 but does
not expose `actual-cli`; the npm client should therefore be packaged with Nix,
not installed globally. The automation should verify `getServerVersion()`
before changing anything.

## Relevant supported operations

- Rule reconciliation: `getRules`, `createRule`, `updateRule`, `deleteRule`.
  `updateRule` requires the complete rule object, including its ID.
- Transaction reconciliation: `getTransactions`, `updateTransaction`.
- Bank sync: `runBankSync({ accountId })`; verify the result by querying the
  resulting transactions because the method returns no transaction summary.
- Sync lifecycle: `init`, `downloadBudget`, `sync`, `exportBudget`, `shutdown`.
- `batchBudgetUpdates` reduces calls, but the documentation does not promise
  transactional rollback.

Source: [API reference](https://actualbudget.org/docs/api/reference/).

## Two viable policies

### API-managed rules

Reconcile the two documented post-stage rules for each foreign account, using
account UUIDs and a managed rule-ID state file. Fetch the latest ECB rate,
update the rate literals, verify canonical rule objects, and sync. New rules
should use rule formulas (`options.formula`) because rule-action templates are
deprecated. Formula examples:

- amount: `=ROUND(amount * RATE, 0)`
- note: `=CONCATENATE(FORMATNUMBER(amount / 100, 2), " EUR (FX rate: ...)", ...)`

This is configuration-as-code, but a transaction imported late or backfilled
is valued at the rate installed when it is imported, not its transaction date.

Sources:

- [Multi-currency workaround](https://actualbudget.org/docs/budgeting/multi-currency/)
- [Rule formulas](https://actualbudget.org/docs/experimental/formulas/)
- [Rule-action templating](https://actualbudget.org/docs/experimental/rule-templating/)
- [Rule model](https://github.com/actualbudget/actual/blob/master/packages/loot-core/src/types/models/rule.ts)

### Post-sync transaction reconciliation (recommended)

Run bank sync, fetch each unprocessed foreign-account transaction, select the
official rate for its transaction date, then update its amount and notes. Add a
versioned marker containing the original foreign amount, currency, rate source,
rate date, and applied rate. Re-running the job validates or skips marked rows,
making it idempotent without modifying bank-owned `imported_id` values.

This produces stable historical results for delayed and backfilled bank data.
It also allows a dry-run report before mutation and deterministic verification
afterward.

Safety rules:

- fail on missing or duplicate expected account names; persist and verify UUIDs;
- never overwrite unexpected manually edited managed rules or markers;
- skip/fail transfers unless both linked sides are handled deliberately;
- skip/fail split transactions unless the complete parent and children are
  updated with exact sum-preserving rounding;
- export the budget before mutation and retain the existing restic backup;
- use one API process/data directory and an external non-overlap lock;
- call `sync()` before reads and after writes, then always `shutdown()`.

Sources:

- [Transactions, transfers, and splits](https://actualbudget.org/docs/api/reference/#transactions)
- [Actual CLI locking pattern](https://github.com/actualbudget/actual/blob/master/packages/cli/src/lock.ts)
- [Actual CLI connection lifecycle](https://github.com/actualbudget/actual/blob/master/packages/cli/src/connection.ts)

## FX source

Use the ECB reference-rate feed. It quotes currencies per EUR, so:

- EUR to RON: `RON/EUR`
- USD to RON: `(RON/EUR) / (USD/EUR)`
- GBP to RON: `(RON/EUR) / (GBP/EUR)`

Validate the publication date, required currencies, finite positive values,
and staleness before any mutation. On weekends and holidays, use the latest
published business-day rate. ECB describes these as informational reference
rates; prefer a bank-supplied booked rate when one is available.

Sources:

- [ECB daily XML](https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml)
- [ECB reference rates](https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html)

## NixOS shape

Package a small Node program with `@actual-app/api@26.7.0`. Run it as a hardened
oneshot service after `actual.service`, connecting to `http://127.0.0.1:5006`.
Provide the Actual password with a systemd credential, keep the full budget cache
in a private runtime directory, and keep rule IDs/checksums in a private state
directory. A timer can run after ECB publication and/or invoke bank sync before
reconciliation. Add service/timer checks to `scripts/remote-verify`.

Recommended rollout: dry-run against the current EUR/GBP accounts; export and
backup; migrate the browser-created template rules; run one real reconciliation;
verify account balances, markers, rule drift, sync, and an isolated restore.
