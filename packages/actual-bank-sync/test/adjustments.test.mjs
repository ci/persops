import assert from 'node:assert/strict';
import test from 'node:test';

import { planReconciliation } from '../src/reconcile.mjs';

const eurAccount = {
  id: 'eur-account',
  name: 'RevPersEUR',
  currency: 'EUR',
  bridgeRate: '5.2525',
};

test('keeps a bank row at its bridge amount and creates the historical ECB delta', () => {
  const source = {
    id: 'bank-row',
    account: eurAccount.id,
    amount: -6482,
    category: 'dinner-category',
    date: '2026-08-14',
    cleared: true,
    imported_id: 'bank-id',
    notes: '-12.34 EUR (FX rate: 5.2525) • dinner',
    raw_synced_data: JSON.stringify({
      amount: '-12.34',
      transactionAmount: { amount: '-12.34', currency: 'EUR' },
    }),
  };

  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0712' } },
    transactions: [source],
  });

  assert.deepEqual(source.amount, -6482);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.updates, []);
  assert.deepEqual(result.sourceUpdates, []);
  assert.equal(result.creates.length, 1);
  assert.deepEqual(result.creates[0], {
    sourceId: source.id,
    role: 'PRIMARY',
    fields: {
      account: eurAccount.id,
      amount: 224,
      category: 'dinner-category',
      cleared: true,
      date: '2026-08-14',
      notes:
        'FX rate: -12.34 EUR at 5.0712 ECB 2026-08-14 [actual-fx-adj:v1|for=bank-row|role=PRIMARY|orig=-1234|ccy=EUR|rate=5.0712|date=2026-08-14|source=ECB]',
      payee: 'fx-adjustment-payee',
      reconciled: false,
    },
  });
});

test('recognizes the exact companion row and plans no duplicate', () => {
  const source = {
    id: 'bank-row',
    account: eurAccount.id,
    amount: -6482,
    category: 'dinner-category',
    date: '2026-08-14',
    cleared: true,
    imported_id: 'bank-id',
    raw_synced_data: JSON.stringify({
      amount: '-12.34',
      transactionAmount: { amount: '-12.34', currency: 'EUR' },
    }),
  };
  const adjustment = {
    id: 'adjustment-row',
    account: eurAccount.id,
    amount: 224,
    category: 'dinner-category',
    cleared: true,
    date: '2026-08-14',
    notes:
      'FX rate: -12.34 EUR at 5.0712 ECB 2026-08-14 [actual-fx-adj:v1|for=bank-row|role=PRIMARY|orig=-1234|ccy=EUR|rate=5.0712|date=2026-08-14|source=ECB]',
    payee: 'fx-adjustment-payee',
    reconciled: false,
  };

  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0712' } },
    transactions: [source, adjustment],
  });

  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.updates, []);
  assert.deepEqual(result.sourceUpdates, []);
  assert.deepEqual(result.skipped, [
    { id: 'adjustment-row', reason: 'already-reconciled' },
  ]);
});

test('balances a linked cross-currency transfer with opposite companions', () => {
  const source = {
    id: 'foreign-transfer',
    account: eurAccount.id,
    amount: -5253,
    category: null,
    date: '2026-08-14',
    cleared: true,
    imported_id: 'bank-id',
    raw_synced_data: JSON.stringify({
      amount: '-10.00',
      transactionAmount: { amount: '-10.00', currency: 'EUR' },
      bank_transaction_code: { code: 'EXCHANGE' },
    }),
    transfer_id: 'savings-transfer',
  };
  const counterpart = {
    id: 'savings-transfer',
    account: 'ron-savings',
    amount: 5253,
    category: null,
    date: '2026-08-14',
    cleared: true,
    transfer_id: source.id,
  };

  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0712' } },
    transactions: [source, counterpart],
  });

  assert.equal(source.amount, -5253);
  assert.equal(counterpart.amount, 5253);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.sourceUpdates, []);
  assert.deepEqual(result.creates, [
    {
      sourceId: source.id,
      role: 'PRIMARY',
      fields: {
        account: eurAccount.id,
        amount: 182,
        category: 'fx-category',
        cleared: true,
        date: '2026-08-14',
        notes:
          'FX rate: -10.00 EUR at 5.0712 LINKED 2026-08-14 [actual-fx-adj:v1|for=foreign-transfer|role=PRIMARY|orig=-1000|ccy=EUR|rate=5.0712|date=2026-08-14|source=LINKED]',
        payee: 'fx-adjustment-payee',
        reconciled: false,
      },
    },
    {
      sourceId: source.id,
      role: 'COUNTER',
      fields: {
        account: 'ron-savings',
        amount: -182,
        category: 'fx-category',
        cleared: true,
        date: '2026-08-14',
        notes:
          'FX rate: -10.00 EUR at 5.0712 LINKED 2026-08-14 [actual-fx-adj:v1|for=foreign-transfer|role=COUNTER|orig=-1000|ccy=EUR|rate=5.0712|date=2026-08-14|source=LINKED]',
        payee: 'fx-adjustment-payee',
        reconciled: false,
      },
    },
  ]);
});

test('pairs provider exchange legs by entry reference and derives the exact RON value', () => {
  const source = {
    id: 'foreign-exchange',
    account: eurAccount.id,
    amount: 7879,
    category: null,
    date: '2026-08-03',
    cleared: true,
    imported_id: 'foreign-bank-id',
    raw_synced_data: JSON.stringify({
      entry_reference: 'shared-reference',
      amount: '15.00',
      transactionAmount: { amount: '15.00', currency: 'EUR' },
      bank_transaction_code: { code: 'EXCHANGE' },
    }),
  };
  const domestic = {
    id: 'ron-exchange',
    account: 'ron-current',
    amount: -7923,
    category: null,
    date: '2026-08-03',
    cleared: true,
    imported_id: 'ron-bank-id',
    raw_synced_data: JSON.stringify({
      entry_reference: 'shared-reference',
      amount: '-79.23',
      transactionAmount: { amount: '-79.23', currency: 'RON' },
      bank_transaction_code: { code: 'EXCHANGE' },
    }),
  };

  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: {},
    transactions: [source, domestic],
  });

  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.skipped, []);
  assert.deepEqual(result.sourceUpdates, [
    { id: 'foreign-exchange', fields: { category: 'fx-category' } },
    { id: 'ron-exchange', fields: { category: 'fx-category' } },
  ]);
  assert.deepEqual(result.creates, [
    {
      sourceId: source.id,
      role: 'PRIMARY',
      fields: {
        account: eurAccount.id,
        amount: 44,
        category: 'fx-category',
        cleared: true,
        date: '2026-08-03',
        notes:
          'FX rate: 15.00 EUR at 5.282000 EXCHANGE 2026-08-03 [actual-fx-adj:v1|for=foreign-exchange|role=PRIMARY|orig=1500|ccy=EUR|rate=5.282000|date=2026-08-03|source=EXCHANGE]',
        payee: 'fx-adjustment-payee',
        reconciled: false,
      },
    },
  ]);
});

test('updates only a drifted companion row', () => {
  const source = {
    id: 'bank-row',
    account: eurAccount.id,
    amount: -5253,
    category: 'food-category',
    date: '2026-08-14',
    cleared: true,
    raw_synced_data: JSON.stringify({
      amount: '-10.00',
      transactionAmount: { amount: '-10.00', currency: 'EUR' },
    }),
  };
  const adjustment = {
    id: 'adjustment-row',
    account: eurAccount.id,
    amount: 999,
    category: 'old-category',
    cleared: true,
    date: '2026-08-14',
    notes:
      'FX rate: -10.00 EUR at 5.0712 ECB 2026-08-14 [actual-fx-adj:v1|for=bank-row|role=PRIMARY|orig=-1000|ccy=EUR|rate=5.0712|date=2026-08-14|source=ECB]',
    payee: 'fx-adjustment-payee',
    reconciled: false,
  };

  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0712' } },
    transactions: [source, adjustment],
  });

  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.creates, []);
  assert.equal(result.updates.length, 1);
  assert.equal(result.updates[0].id, adjustment.id);
  assert.equal(result.updates[0].fields.amount, 182);
  assert.equal(result.updates[0].fields.category, 'food-category');
});

test('uses a legacy bridge note as the trusted original for a starting balance', () => {
  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0000' } },
    transactions: [
      {
        id: 'starting-balance',
        account: eurAccount.id,
        amount: 5253,
        category: 'starting-balance-category',
        date: '2026-08-14',
        cleared: true,
        notes: '10.00 EUR (FX rate: 5.2525) • ',
        starting_balance_flag: true,
      },
    ],
  });

  assert.deepEqual(result.errors, []);
  assert.equal(result.creates.length, 1);
  assert.equal(result.creates[0].fields.amount, -253);
  assert.equal(
    result.creates[0].fields.category,
    'starting-balance-category',
  );
});

test('fails closed if bank matching absorbs a companion row', () => {
  const source = {
    id: 'bank-row',
    account: eurAccount.id,
    amount: -5253,
    date: '2026-08-14',
    cleared: true,
    raw_synced_data: JSON.stringify({
      amount: '-10.00',
      transactionAmount: { amount: '-10.00', currency: 'EUR' },
    }),
  };
  const adjustment = {
    id: 'adjustment-row',
    account: eurAccount.id,
    amount: 182,
    date: '2026-08-14',
    imported_id: 'unexpected-bank-id',
    notes:
      'FX rate: -10.00 EUR at 5.0712 ECB 2026-08-14 [actual-fx-adj:v1|for=bank-row|role=PRIMARY|orig=-1000|ccy=EUR|rate=5.0712|date=2026-08-14|source=ECB]',
    payee: 'fx-adjustment-payee',
    reconciled: false,
  };

  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0712' } },
    transactions: [source, adjustment],
  });

  assert.deepEqual(result.errors, [
    { id: 'adjustment-row', reason: 'absorbed-adjustment' },
  ]);
});

test('fails closed for an orphaned companion marker', () => {
  const result = planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates: { '2026-08-14': { EUR: '5.0712' } },
    transactions: [
      {
        id: 'orphan',
        account: eurAccount.id,
        amount: 182,
        date: '2026-08-14',
        notes:
          'FX rate: -10.00 EUR at 5.0712 ECB 2026-08-14 [actual-fx-adj:v1|for=missing-source|role=PRIMARY|orig=-1000|ccy=EUR|rate=5.0712|date=2026-08-14|source=ECB]',
        payee: 'fx-adjustment-payee',
        reconciled: false,
      },
    ],
  });

  assert.deepEqual(result.errors, [
    { id: 'orphan', reason: 'orphan-adjustment' },
  ]);
});
