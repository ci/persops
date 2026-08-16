function matches(item, expected) {
  return Object.entries(expected).every(([key, value]) => item?.[key] === value);
}

function expectedConditions(account, variant) {
  const conditions = [
    { field: 'account', op: 'is', value: account.id },
  ];
  if (variant === 'empty') {
    conditions.push({ field: 'notes', op: 'is', value: '' });
  } else {
    conditions.push(
      { field: 'notes', op: 'isNot', value: '' },
      { field: 'notes', op: 'doesNotContain', value: 'FX rate:' },
    );
  }
  return conditions;
}

function expectedActions(account, variant) {
  const noteSuffix = variant === 'existing' ? ' • {{ notes }}' : '';
  return [
    {
      field: 'notes',
      op: 'set',
      template: `{{ fixed (div amount 100) 2 }} ${account.currency} (FX rate: ${account.bridgeRate})${noteSuffix}`,
    },
    {
      field: 'amount',
      op: 'set',
      template: `{{ fixed (mul amount ${account.bridgeRate}) 0 }}`,
    },
  ];
}

function isBridgeCandidate(rule, account) {
  const targetsAccount = rule.conditions?.some(condition =>
    matches(condition, { field: 'account', op: 'is', value: account.id }),
  );
  return (
    targetsAccount &&
    rule.actions?.some(action => {
      const template = action.options?.template ?? '';
      return (
        (action.field === 'notes' &&
          template.includes(`${account.currency} (FX rate:`)) ||
        (action.field === 'amount' && template.includes('mul amount'))
      );
    })
  );
}

function isCanonicalBridgeRule(rule, account, variant) {
  const conditions = expectedConditions(account, variant);
  const actions = expectedActions(account, variant);
  return (
    rule.stage === 'post' &&
    rule.conditionsOp === 'and' &&
    rule.conditions?.length === conditions.length &&
    rule.conditions.every((condition, index) =>
      matches(condition, conditions[index]),
    ) &&
    rule.actions?.length === actions.length &&
    rule.actions.every(
      (action, index) =>
        matches(action, {
          field: actions[index].field,
          op: actions[index].op,
        }) &&
        action.options?.template === actions[index].template,
    )
  );
}

export function validateBridgeRules(rules, foreignAccounts) {
  const errors = [];
  for (const account of foreignAccounts) {
    const candidates = rules.filter(rule => isBridgeCandidate(rule, account));
    if (candidates.length !== 2) {
      errors.push({
        accountId: account.id,
        reason: 'expected-two-bridge-rules',
        found: candidates.length,
      });
      continue;
    }
    const canonical =
      candidates.some(rule => isCanonicalBridgeRule(rule, account, 'empty')) &&
      candidates.some(rule => isCanonicalBridgeRule(rule, account, 'existing'));
    if (!canonical) {
      errors.push({ accountId: account.id, reason: 'invalid-bridge-rule-shape' });
    }
  }
  return errors;
}
