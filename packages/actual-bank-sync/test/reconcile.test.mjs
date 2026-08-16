import assert from 'node:assert/strict';
import test from 'node:test';

import { planReconciliation } from '../src/reconcile.mjs';

const eurAccount = {
  id: 'eur-account',
  name: 'RevPersEUR',
  currency: 'EUR',
  bridgeRate: '5.2525',
};

function plan(transactions, rates = { '2026-08-14': { EUR: '5.0712' } }) {
  return planReconciliation({
    adjustmentPayeeId: 'fx-adjustment-payee',
    foreignAccounts: [eurAccount],
    fxCategoryId: 'fx-category',
    rates,
    transactions,
  });
}

function legacy(overrides = {}) {
  return {
    id: 'source',
    account: eurAccount.id,
    amount: -6482,
    category: 'food-category',
    date: '2026-08-14',
    cleared: true,
    notes: '-12.34 EUR (FX rate: 5.2525)',
    ...overrides,
  };
}

test('leaves a pending source at its bridge amount', () => {
  const result = plan([legacy({ cleared: false })]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.skipped, [
    { id: 'source', reason: 'pending-transaction' },
  ]);
});

test('refuses a source whose amount has drifted from the bridge', () => {
  const result = plan([legacy({ amount: -1234 })]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'bridge-amount-drift' },
  ]);
});

test('refuses an imported bank source without raw sync provenance', () => {
  const result = plan([legacy({ imported_id: 'bank-id' })]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'missing-trusted-original' },
  ]);
});

test('refuses split sources', () => {
  const result = plan([
    legacy({ is_parent: true, subtransactions: [{ id: 'child' }] }),
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'split-transaction' },
  ]);
});

test('uses the prior ECB business day for a weekend source', () => {
  const result = plan([
    legacy({
      amount: 5253,
      date: '2026-08-16',
      notes: '10.00 EUR (FX rate: 5.2525)',
    }),
  ]);

  assert.deepEqual(result.errors, []);
  assert.equal(result.creates[0].fields.amount, -182);
  assert.match(result.creates[0].fields.notes, /date=2026-08-14/);
});

test('waits for a weekday ECB publication', () => {
  const result = plan([
    legacy({
      amount: -5253,
      date: '2026-08-17',
      notes: '-10.00 EUR (FX rate: 5.2525)',
    }),
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.skipped, [
    { id: 'source', reason: 'awaiting-ecb-rate' },
  ]);
});

test('rounds positive and negative half-cents symmetrically', () => {
  const result = plan(
    [
      legacy({
        id: 'positive',
        amount: 5,
        notes: '0.01 EUR (FX rate: 5.2525)',
      }),
      legacy({
        id: 'negative',
        amount: -5,
        notes: '-0.01 EUR (FX rate: 5.2525)',
      }),
    ],
    { '2026-08-14': { EUR: '1.5' } },
  );

  assert.deepEqual(result.errors, []);
  assert.deepEqual(
    result.creates.map(create => create.fields.amount),
    [-3, 3],
  );
  assert.deepEqual(
    result.creates.map((create, index) =>
      create.fields.amount + [5, -5][index],
    ),
    [2, -2],
  );
});

test('does not create a zero-value companion when bridge and target agree', () => {
  const result = plan(
    [
      legacy({
        amount: 5253,
        notes: '10.00 EUR (FX rate: 5.2525)',
      }),
    ],
    { '2026-08-14': { EUR: '5.2525' } },
  );

  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.skipped, [
    { id: 'source', reason: 'no-adjustment-needed' },
  ]);
});

test('accepts normalized bank decimals with zero or one fractional digit', () => {
  const result = plan([
    legacy({
      id: 'whole',
      amount: 525,
      notes: 'ignored bank note',
      raw_synced_data: JSON.stringify({
        amount: '1',
        transactionAmount: { amount: '1', currency: 'EUR' },
      }),
    }),
    legacy({
      id: 'tenths',
      amount: 630,
      notes: 'ignored bank note',
      raw_synced_data: JSON.stringify({
        amount: '1.2',
        transactionAmount: { amount: '1.2', currency: 'EUR' },
      }),
    }),
  ]);

  assert.deepEqual(result.errors, []);
  assert.equal(result.creates.length, 2);
});

test('refuses a malformed linked transfer pair', () => {
  const result = plan([
    legacy({ amount: -5253, notes: '-10.00 EUR (FX rate: 5.2525)', transfer_id: 'ron' }),
    {
      id: 'ron',
      account: 'ron-account',
      amount: 5000,
      date: '2026-08-14',
      cleared: true,
      transfer_id: 'source',
    },
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'invalid-transfer-pair' },
  ]);
});

test('refuses linked transfer halves with different dates', () => {
  const result = plan([
    legacy({
      amount: -5253,
      notes: '-10.00 EUR (FX rate: 5.2525)',
      transfer_id: 'ron',
    }),
    {
      id: 'ron',
      account: 'ron-account',
      amount: 5253,
      date: '2026-08-13',
      cleared: true,
      transfer_id: 'source',
    },
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'invalid-transfer-pair' },
  ]);
});

test('refuses ambiguous provider exchange counterparts', () => {
  const raw = (amount, currency) =>
    JSON.stringify({
      entry_reference: 'same-reference',
      amount,
      transactionAmount: { amount, currency },
      bank_transaction_code: { code: 'EXCHANGE' },
    });
  const result = plan([
    legacy({
      amount: 5253,
      notes: '10.00 EUR (FX rate: 5.2525)',
      raw_synced_data: raw('10.00', 'EUR'),
    }),
    {
      id: 'ron-one',
      account: 'ron-account',
      amount: -50,
      date: '2026-08-14',
      cleared: true,
      raw_synced_data: raw('-0.50', 'RON'),
    },
    {
      id: 'ron-two',
      account: 'ron-account',
      amount: -52,
      date: '2026-08-14',
      cleared: true,
      raw_synced_data: raw('-0.52', 'RON'),
    },
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'ambiguous-exchange-pair' },
  ]);
});

test('refuses a provider exchange counterpart that drifted from its raw amount', () => {
  const raw = (amount, currency) =>
    JSON.stringify({
      entry_reference: 'same-reference',
      amount,
      transactionAmount: { amount, currency },
      bank_transaction_code: { code: 'EXCHANGE' },
    });
  const result = plan([
    legacy({
      amount: 5253,
      notes: '10.00 EUR (FX rate: 5.2525)',
      raw_synced_data: raw('10.00', 'EUR'),
    }),
    {
      id: 'ron-side',
      account: 'ron-account',
      amount: -6000,
      date: '2026-08-14',
      cleared: true,
      raw_synced_data: raw('-50.00', 'RON'),
    },
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'source', reason: 'invalid-exchange-pair' },
  ]);
});

test('waits when the provider exchange counterpart is still pending', () => {
  const raw = (amount, currency) =>
    JSON.stringify({
      entry_reference: 'same-reference',
      amount,
      transactionAmount: { amount, currency },
      bank_transaction_code: { code: 'EXCHANGE' },
    });
  const result = plan([
    legacy({
      amount: 5253,
      notes: '10.00 EUR (FX rate: 5.2525)',
      raw_synced_data: raw('10.00', 'EUR'),
    }),
    {
      id: 'ron-side',
      account: 'ron-account',
      amount: -5000,
      date: '2026-08-14',
      cleared: false,
      raw_synced_data: raw('-50.00', 'RON'),
    },
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, []);
  assert.deepEqual(result.skipped, [
    { id: 'source', reason: 'awaiting-fx-pair' },
  ]);
});

test('does not reinterpret a malformed dedicated-payee row as a source', () => {
  const result = plan([
    legacy({
      id: 'bad-adjustment',
      payee: 'fx-adjustment-payee',
      notes: 'manually-created row',
    }),
  ]);

  assert.deepEqual(result.creates, []);
  assert.deepEqual(result.errors, [
    { id: 'bad-adjustment', reason: 'invalid-adjustment-marker' },
  ]);
});

test('refuses duplicate and reconciled companion markers', () => {
  const notes =
    'FX rate: -12.34 EUR at 5.0712 ECB 2026-08-14 [actual-fx-adj:v1|for=source|role=PRIMARY|orig=-1234|ccy=EUR|rate=5.0712|date=2026-08-14|source=ECB]';
  const result = plan([
    legacy(),
    {
      id: 'first',
      account: eurAccount.id,
      amount: 224,
      date: '2026-08-14',
      notes,
      payee: 'fx-adjustment-payee',
      reconciled: false,
    },
    {
      id: 'second',
      account: eurAccount.id,
      amount: 224,
      date: '2026-08-14',
      notes,
      payee: 'fx-adjustment-payee',
      reconciled: true,
    },
  ]);

  assert.deepEqual(result.errors, [
    { id: 'second', reason: 'reconciled-adjustment' },
  ]);
});
