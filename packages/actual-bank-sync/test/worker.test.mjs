import assert from 'node:assert/strict';
import test from 'node:test';

import { runWorker } from '../src/worker.mjs';

const foreignAccount = {
  id: 'eur-account',
  name: 'RevPersEUR',
  currency: 'EUR',
  bridgeRate: '5.2525',
};

function bridgeRule(id, notesConditions) {
  const existingNotes = notesConditions.some(condition => condition.op === 'isNot');
  return {
    id,
    stage: 'post',
    conditionsOp: 'and',
    conditions: [
      { field: 'account', op: 'is', value: foreignAccount.id },
      ...notesConditions,
    ],
    actions: [
      {
        op: 'set',
        field: 'notes',
        options: {
          template: `{{ fixed (div amount 100) 2 }} EUR (FX rate: 5.2525)${existingNotes ? ' • {{ notes }}' : ''}`,
        },
      },
      {
        op: 'set',
        field: 'amount',
        options: { template: '{{ fixed (mul amount 5.2525) 0 }}' },
      },
    ],
  };
}

function fakeApi({ bankSyncError, failAdd = false } = {}) {
  const calls = [];
  const transactions = [
    {
      id: 'bank-row',
      account: foreignAccount.id,
      amount: -6482,
      category: 'food-category',
      date: '2026-08-14',
      cleared: true,
      imported_id: 'bank-id',
      raw_synced_data: JSON.stringify({
        amount: '-12.34',
        transactionAmount: { amount: '-12.34', currency: 'EUR' },
      }),
    },
  ];
  let created = 0;
  return {
    calls,
    transactions,
    async init() {
      calls.push('init');
    },
    async getServerVersion() {
      calls.push('version');
      return { version: '26.8.1' };
    },
    async downloadBudget() {
      calls.push('download');
    },
    async sync() {
      calls.push('sync');
    },
    async exportBudget() {
      calls.push('export');
      return new Uint8Array([0x50, 0x4b, 0x03, 0x04]);
    },
    async getAccounts() {
      calls.push('accounts');
      return [
        { id: foreignAccount.id, name: foreignAccount.name, closed: false },
        { id: 'source-account', name: 'RevPersRON', closed: false },
        { id: 'ron-account', name: 'RevolutSavings', closed: false },
      ];
    },
    async getCategories() {
      calls.push('categories');
      return [{ id: 'fx-category', name: 'Currency Exchange' }];
    },
    async getPayees() {
      calls.push('payees');
      return [{ id: 'fx-adjustment-payee', name: 'FX Adjustment' }];
    },
    async getRules() {
      calls.push('rules');
      return [
        bridgeRule('empty-notes', [
          { field: 'notes', op: 'is', value: '' },
        ]),
        bridgeRule('existing-notes', [
          { field: 'notes', op: 'isNot', value: '' },
          { field: 'notes', op: 'doesNotContain', value: 'FX rate:' },
        ]),
      ];
    },
    async runBankSync() {
      calls.push('bank-sync');
      if (bankSyncError) throw bankSyncError;
    },
    async getTransactions(accountId) {
      calls.push(`transactions:${accountId}`);
      return transactions.filter(transaction => transaction.account === accountId);
    },
    async batchBudgetUpdates(callback) {
      calls.push('batch-start');
      await callback();
      calls.push('batch-end');
    },
    async updateTransaction(id, fields) {
      calls.push(`update:${id}`);
      Object.assign(
        transactions.find(transaction => transaction.id === id),
        fields,
      );
    },
    async addTransactions(accountId, rows, options) {
      calls.push(`add:${accountId}:${rows.length}`);
      assert.deepEqual(options, {
        learnCategories: false,
        runTransfers: false,
      });
      if (failAdd) throw new Error('write failed');
      for (const row of rows) {
        transactions.push({
          id: `created-${++created}`,
          account: accountId,
          ...row,
        });
      }
    },
    async shutdown() {
      calls.push('shutdown');
    },
  };
}

const config = {
  actualVersion: '26.8.1',
  adjustmentPayee: { id: 'fx-adjustment-payee', name: 'FX Adjustment' },
  baseCurrency: 'RON',
  clearMatchedTransfersTo: { id: 'ron-account', name: 'RevolutSavings' },
  dataDir: '/tmp/actual-test',
  foreignAccounts: [foreignAccount],
  fxCategory: { id: 'fx-category', name: 'Currency Exchange' },
  password: 'not-logged',
  recoveryDir: '/tmp/actual-test/recovery',
  serverURL: 'https://actual.example.test',
  syncId: 'sync-id',
};
const rates = { '2026-08-14': { EUR: '5.0712' } };
const saveRecovery = async ({ data, directory }) => {
  assert.equal(data[0], 0x50);
  assert.equal(directory, config.recoveryDir);
  return { digest: 'digest', fileName: 'recovery.zip' };
};

test('run mode leaves the bank row immutable and creates one verified companion', async () => {
  const api = fakeApi();

  const result = await runWorker({
    api,
    config,
    mode: 'run',
    rates,
    saveRecovery,
  });

  assert.equal(result.planned, 1);
  assert.equal(result.applied, 1);
  assert.equal(api.transactions[0].amount, -6482);
  assert.equal(api.transactions[0].notes, undefined);
  assert.equal(api.transactions[1].amount, 224);
  assert.match(api.transactions[1].notes, /\[actual-fx-adj:v1\|/);
  assert.ok(api.calls.indexOf('export') < api.calls.indexOf('bank-sync'));
  assert.ok(api.calls.indexOf('bank-sync') < api.calls.indexOf('add:eur-account:1'));
  assert.equal(api.calls.at(-1), 'shutdown');
});

test('run mode clears only the configured side of a matched cleared transfer', async () => {
  const api = fakeApi();
  api.transactions.push(
    {
      id: 'cleared-transfer-source',
      account: 'source-account',
      amount: -500,
      category: null,
      date: '2026-08-22',
      cleared: true,
      transfer_id: 'pending-transfer-target',
    },
    {
      id: 'pending-transfer-target',
      account: 'ron-account',
      amount: 500,
      category: null,
      date: '2026-08-22',
      cleared: false,
      transfer_id: 'cleared-transfer-source',
    },
    {
      id: 'unmatched-transfer-target',
      account: 'ron-account',
      amount: 600,
      category: null,
      date: '2026-08-22',
      cleared: false,
      transfer_id: 'missing-transfer-source',
    },
  );

  const result = await runWorker({
    api,
    config,
    mode: 'run',
    rates,
    saveRecovery,
  });

  assert.equal(result.planned, 2);
  assert.equal(result.applied, 2);
  assert.equal(api.transactions[2].cleared, true);
  assert.equal(api.transactions[3].cleared, false);
});

test('plan mode reports companion work without backup, bank sync, or mutation', async () => {
  const api = fakeApi();

  const result = await runWorker({
    api,
    config,
    mode: 'plan',
    rates,
    saveRecovery,
  });

  assert.equal(result.planned, 1);
  assert.equal(result.applied, 0);
  assert.equal(api.transactions.length, 1);
  assert.ok(!api.calls.includes('export'));
  assert.ok(!api.calls.includes('bank-sync'));
  assert.ok(!api.calls.some(call => call.startsWith('add:')));
  assert.equal(api.calls.at(-1), 'shutdown');
});

test('reconcile mode exports through the Actual 26.7 internal API seam', async () => {
  const api = fakeApi();
  delete api.exportBudget;
  api.internal = {
    async send(message) {
      api.calls.push(`internal:${message}`);
      assert.equal(message, 'export-budget');
      return { data: new Uint8Array([0x50, 0x4b, 0x03, 0x04]) };
    },
  };

  const result = await runWorker({
    api,
    config,
    mode: 'reconcile',
    rates,
    saveRecovery,
  });

  assert.equal(result.recovery, 'recovery.zip');
  assert.ok(api.calls.includes('internal:export-budget'));
});

test('run mode categorizes both provider exchange legs and adds their exact delta', async () => {
  const api = fakeApi();
  Object.assign(api.transactions[0], {
    amount: 7879,
    category: null,
    date: '2026-08-03',
    raw_synced_data: JSON.stringify({
      entry_reference: 'shared-reference',
      amount: '15.00',
      transactionAmount: { amount: '15.00', currency: 'EUR' },
      bank_transaction_code: { code: 'EXCHANGE' },
    }),
  });
  api.transactions.push({
    id: 'ron-exchange',
    account: 'ron-account',
    amount: -7923,
    category: null,
    date: '2026-08-03',
    cleared: true,
    raw_synced_data: JSON.stringify({
      entry_reference: 'shared-reference',
      amount: '-79.23',
      transactionAmount: { amount: '-79.23', currency: 'RON' },
      bank_transaction_code: { code: 'EXCHANGE' },
    }),
  });

  const result = await runWorker({
    api,
    config,
    mode: 'run',
    rates,
    saveRecovery,
  });

  assert.equal(result.planned, 3);
  assert.equal(result.applied, 3);
  assert.equal(api.transactions[0].amount, 7879);
  assert.equal(api.transactions[1].amount, -7923);
  assert.equal(api.transactions[0].category, 'fx-category');
  assert.equal(api.transactions[1].category, 'fx-category');
  assert.equal(api.transactions[2].amount, 44);
});

test('an interrupted create reports a resumable plan and its recovery artifact', async () => {
  const api = fakeApi({ failAdd: true });

  await assert.rejects(
    runWorker({ api, config, mode: 'reconcile', rates, saveRecovery }),
    /apply failed; recovery=recovery\.zip; partial state is resumable; remaining=1/,
  );

  assert.equal(api.transactions.length, 1);
  assert.equal(api.calls.at(-1), 'shutdown');
});

test('a bank failure is surfaced only after safe companion reconciliation', async () => {
  const api = fakeApi({ bankSyncError: new Error('bank unavailable') });

  await assert.rejects(
    runWorker({ api, config, mode: 'run', rates, saveRecovery }),
    /bank sync failed after reconciliation: bank unavailable/,
  );

  assert.equal(api.transactions.length, 2);
  assert.equal(api.transactions[0].amount, -6482);
  assert.equal(api.calls.at(-1), 'shutdown');
});

test('a stale dedicated payee id fails before backup or transaction mutation', async () => {
  const api = fakeApi();
  const staleConfig = {
    ...config,
    adjustmentPayee: { id: 'missing-payee', name: 'FX Adjustment' },
  };

  await assert.rejects(
    runWorker({ api, config: staleConfig, mode: 'run', rates, saveRecovery }),
    /entity validation failed: adjustment payee: missing id missing-payee/,
  );

  assert.ok(!api.calls.includes('export'));
  assert.ok(!api.calls.includes('bank-sync'));
  assert.equal(api.transactions.length, 1);
  assert.equal(api.calls.at(-1), 'shutdown');
});
