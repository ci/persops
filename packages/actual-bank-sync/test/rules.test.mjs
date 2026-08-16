import assert from 'node:assert/strict';
import test from 'node:test';

import { validateBridgeRules } from '../src/rules.mjs';

const account = {
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
      { field: 'account', op: 'is', value: 'eur-account' },
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

test('accepts the two stable bridge rules for a foreign account', () => {
  const rules = [
    bridgeRule('empty-notes', [
      { field: 'notes', op: 'is', value: '' },
    ]),
    bridgeRule('existing-notes', [
      { field: 'notes', op: 'isNot', value: '' },
      { field: 'notes', op: 'doesNotContain', value: 'FX rate:' },
    ]),
  ];

  assert.deepEqual(validateBridgeRules(rules, [account]), []);
});

test('fails closed when either bridge rule is missing', () => {
  const errors = validateBridgeRules(
    [
      bridgeRule('empty-notes', [
        { field: 'notes', op: 'is', value: '' },
      ]),
    ],
    [account],
  );

  assert.deepEqual(errors, [
    { accountId: 'eur-account', reason: 'expected-two-bridge-rules', found: 1 },
  ]);
});

test('rejects an OR bridge rule that could apply to unrelated transactions', () => {
  const empty = bridgeRule('empty-notes', [
    { field: 'notes', op: 'is', value: '' },
  ]);
  empty.conditionsOp = 'or';
  const existing = bridgeRule('existing-notes', [
    { field: 'notes', op: 'isNot', value: '' },
    { field: 'notes', op: 'doesNotContain', value: 'FX rate:' },
  ]);

  assert.deepEqual(validateBridgeRules([empty, existing], [account]), [
    { accountId: 'eur-account', reason: 'invalid-bridge-rule-shape' },
  ]);
});

test('rejects amount-before-notes action ordering', () => {
  const empty = bridgeRule('empty-notes', [
    { field: 'notes', op: 'is', value: '' },
  ]);
  empty.actions.reverse();
  const existing = bridgeRule('existing-notes', [
    { field: 'notes', op: 'isNot', value: '' },
    { field: 'notes', op: 'doesNotContain', value: 'FX rate:' },
  ]);

  assert.deepEqual(validateBridgeRules([empty, existing], [account]), [
    { accountId: 'eur-account', reason: 'invalid-bridge-rule-shape' },
  ]);
});

test('rejects extra bridge conditions or actions', () => {
  const empty = bridgeRule('empty-notes', [
    { field: 'notes', op: 'is', value: '' },
  ]);
  empty.conditions.push({ field: 'cleared', op: 'is', value: true });
  const existing = bridgeRule('existing-notes', [
    { field: 'notes', op: 'isNot', value: '' },
    { field: 'notes', op: 'doesNotContain', value: 'FX rate:' },
  ]);

  assert.deepEqual(validateBridgeRules([empty, existing], [account]), [
    { accountId: 'eur-account', reason: 'invalid-bridge-rule-shape' },
  ]);
});
