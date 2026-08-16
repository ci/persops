import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { createRequire } from 'node:module';
import test from 'node:test';

import { planReconciliation } from '../src/reconcile.mjs';
import { validateBridgeRules } from '../src/rules.mjs';

let api;
try {
  api = createRequire(import.meta.url)('@actual-app/api');
} catch (error) {
  if (error.code !== 'MODULE_NOT_FOUND') throw error;
  // Unit tests also run directly from the checkout, where npm dependencies are absent.
}

function bridgeRule(account, variant) {
  const existing = variant === 'existing';
  return {
    stage: 'post',
    conditionsOp: 'and',
    conditions: [
      { field: 'account', op: 'is', value: account.id },
      existing
        ? { field: 'notes', op: 'isNot', value: '' }
        : { field: 'notes', op: 'is', value: '' },
      ...(existing
        ? [{ field: 'notes', op: 'doesNotContain', value: 'FX rate:' }]
        : []),
    ],
    actions: [
      {
        field: 'notes',
        op: 'set',
        options: {
          template: `{{ fixed (div amount 100) 2 }} EUR (FX rate: 5.2525)${existing ? ' • {{ notes }}' : ''}`,
        },
      },
      {
        field: 'amount',
        op: 'set',
        options: { template: '{{ fixed (mul amount 5.2525) 0 }}' },
      },
    ],
  };
}

test(
  'real Actual API preserves a bridge source and does not transform its companion',
  {
    skip: api
      ? false
      : 'npm dependencies are available in the Nix package check',
  },
  async () => {
    const dataDir = await mkdtemp('/tmp/actual-bank-sync-integration-');
    try {
      await api.init({ dataDir });
      await api.runImport('FX Integration', async () => {});

      const account = {
        id: await api.createAccount({ name: 'RevPersEUR', offbudget: false }),
        name: 'RevPersEUR',
        currency: 'EUR',
        bridgeRate: '5.2525',
      };
      const groupId = await api.createCategoryGroup({
        name: 'Integration',
        is_income: false,
      });
      const sourceCategoryId = await api.createCategory({
        name: 'Food',
        group_id: groupId,
      });
      const fxCategoryId = await api.createCategory({
        name: 'Currency Exchange',
        group_id: groupId,
      });
      const adjustmentPayeeId = await api.createPayee({ name: 'FX Adjustment' });
      await api.createRule(bridgeRule(account, 'empty'));
      await api.createRule(bridgeRule(account, 'existing'));
      assert.deepEqual(validateBridgeRules(await api.getRules(), [account]), []);

      const raw = JSON.stringify({
        amount: '1.00',
        transactionAmount: { amount: '1.00', currency: 'EUR' },
      });
      await api.addTransactions(
        account.id,
        [
          {
            amount: 100,
            category: sourceCategoryId,
            cleared: true,
            date: '2026-08-14',
            imported_id: 'bank-id',
            notes: 'dinner',
            raw_synced_data: raw,
          },
        ],
        { learnCategories: false, runTransfers: false },
      );

      let transactions = await api.getTransactions(
        account.id,
        '2026-08-14',
        '2026-08-14',
      );
      const source = transactions.find(row => row.imported_id === 'bank-id');
      assert.equal(source.amount, 525);
      assert.equal(source.raw_synced_data, raw);
      assert.equal(source.notes, '1.00 EUR (FX rate: 5.2525) • dinner');

      const plannerInput = {
        adjustmentPayeeId,
        foreignAccounts: [account],
        fxCategoryId,
        rates: { '2026-08-14': { EUR: '10.5' } },
      };
      const first = planReconciliation({ ...plannerInput, transactions });
      assert.deepEqual(first.errors, []);
      assert.equal(first.creates.length, 1);
      const { account: _account, ...companion } = first.creates[0].fields;
      await api.addTransactions(account.id, [companion], {
        learnCategories: false,
        runTransfers: false,
      });

      transactions = await api.getTransactions(
        account.id,
        '2026-08-14',
        '2026-08-14',
      );
      const unchangedSource = transactions.find(row => row.id === source.id);
      const adjustment = transactions.find(
        row => row.payee === adjustmentPayeeId,
      );
      assert.equal(unchangedSource.amount, 525);
      assert.equal(unchangedSource.raw_synced_data, raw);
      assert.equal(adjustment.amount, 525);
      assert.equal(adjustment.imported_id, null);
      assert.equal(adjustment.raw_synced_data, null);
      assert.match(adjustment.notes, /FX rate:.*\[actual-fx-adj:v1\|/);

      const second = planReconciliation({ ...plannerInput, transactions });
      assert.deepEqual(second.errors, []);
      assert.deepEqual(second.creates, []);
      assert.deepEqual(second.updates, []);
      assert.deepEqual(second.sourceUpdates, []);

      await api.importTransactions(
        account.id,
        [
          {
            amount: 100,
            cleared: true,
            date: adjustment.date,
            imported_id: 'coincidental-bank-id',
            payee_name: 'Coincidental Bank Row',
          },
        ],
        { defaultCleared: true, dryRun: false },
      );
      transactions = await api.getTransactions(
        account.id,
        '2026-08-14',
        '2026-08-14',
      );
      const absorbed = planReconciliation({ ...plannerInput, transactions });
      assert.ok(
        absorbed.errors.some(
          error =>
            error.id === adjustment.id && error.reason === 'absorbed-adjustment',
        ),
      );
    } finally {
      await api?.shutdown().catch(() => {});
      await rm(dataDir, { recursive: true, force: true });
    }
  },
);
