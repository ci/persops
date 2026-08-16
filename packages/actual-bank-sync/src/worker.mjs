import { planReconciliation } from './reconcile.mjs';
import { saveRecoveryArtifact } from './recovery.mjs';
import { validateBridgeRules } from './rules.mjs';

const VALID_MODES = new Set(['plan', 'reconcile', 'run']);

function countReasons(errors) {
  const counts = new Map();
  for (const error of errors) {
    counts.set(error.reason, (counts.get(error.reason) ?? 0) + 1);
  }
  return [...counts.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([reason, count]) => `${reason}=${count}`)
    .join(', ');
}

function validateAccounts(accounts, foreignAccounts) {
  const errors = [];
  for (const expected of foreignAccounts) {
    const actual = accounts.find(account => account.id === expected.id);
    if (!actual) {
      errors.push(`${expected.name}: missing account id ${expected.id}`);
    } else if (actual.name !== expected.name) {
      errors.push(`${expected.id}: expected name ${expected.name}`);
    } else if (actual.closed) {
      errors.push(`${expected.name}: account is closed`);
    }
    const sameName = accounts.filter(account => account.name === expected.name);
    if (sameName.length !== 1 || sameName[0].id !== expected.id) {
      errors.push(`${expected.name}: account name is not unique and stable`);
    }
  }
  return errors;
}

function validateNamedEntity(entities, expected, label) {
  const actual = entities.find(entity => entity.id === expected?.id);
  if (!actual) return [`${label}: missing id ${expected?.id ?? '<unset>'}`];
  if (actual.name !== expected.name) {
    return [`${label}: expected name ${expected.name}, got ${actual.name}`];
  }
  return [];
}

async function getAllTransactions(api, accounts) {
  const transactions = [];
  const seen = new Set();
  for (const account of accounts) {
    const accountTransactions = await api.getTransactions(
      account.id,
      '1900-01-01',
      '9999-12-31',
    );
    for (const transaction of accountTransactions) {
      if (!seen.has(transaction.id)) {
        transactions.push(transaction);
        seen.add(transaction.id);
      }
    }
  }
  return transactions;
}

function planCount(plan) {
  return plan.creates.length + plan.updates.length + plan.sourceUpdates.length;
}

function plannerInput(config, rates, transactions) {
  return {
    adjustmentPayeeId: config.adjustmentPayee.id,
    baseCurrency: config.baseCurrency,
    foreignAccounts: config.foreignAccounts,
    fxCategoryId: config.fxCategory.id,
    rates,
    transactions,
  };
}

async function exportBudget(api) {
  if (typeof api.exportBudget === 'function') {
    return api.exportBudget();
  }
  const result = await api.internal?.send('export-budget');
  if (!result?.data) {
    throw new Error('Actual budget export failed');
  }
  return result.data;
}

async function applyPlan(api, plan) {
  await api.batchBudgetUpdates(async () => {
    for (const update of [...plan.sourceUpdates, ...plan.updates]) {
      await api.updateTransaction(update.id, update.fields);
    }

    const createsByAccount = new Map();
    for (const create of plan.creates) {
      const rows = createsByAccount.get(create.fields.account) ?? [];
      const { account: _account, ...fields } = create.fields;
      rows.push(fields);
      createsByAccount.set(create.fields.account, rows);
    }
    for (const [accountId, rows] of createsByAccount) {
      await api.addTransactions(accountId, rows, {
        learnCategories: false,
        runTransfers: false,
      });
    }
  });
}

export async function runWorker({
  api,
  config,
  mode,
  rates,
  saveRecovery = saveRecoveryArtifact,
}) {
  if (!VALID_MODES.has(mode)) {
    throw new Error(`invalid mode: ${mode}`);
  }

  let initialized = false;
  try {
    await api.init({
      dataDir: config.dataDir,
      password: config.password,
      serverURL: config.serverURL,
      verbose: false,
    });
    initialized = true;

    const versionResult = await api.getServerVersion();
    if (versionResult.version !== config.actualVersion) {
      throw new Error(
        `Actual server version mismatch: expected ${config.actualVersion}, got ${versionResult.version ?? versionResult.error}`,
      );
    }

    await api.downloadBudget(config.syncId, { password: config.password });
    await api.sync();

    const accounts = await api.getAccounts();
    const entityErrors = [
      ...validateAccounts(accounts, config.foreignAccounts),
      ...validateNamedEntity(
        await api.getPayees(),
        config.adjustmentPayee,
        'adjustment payee',
      ),
      ...validateNamedEntity(
        await api.getCategories(),
        config.fxCategory,
        'FX category',
      ),
    ];
    if (entityErrors.length > 0) {
      throw new Error(`entity validation failed: ${entityErrors.join('; ')}`);
    }

    const ruleErrors = validateBridgeRules(
      await api.getRules(),
      config.foreignAccounts,
    );
    if (ruleErrors.length > 0) {
      throw new Error(
        `bridge rule validation failed: ${countReasons(ruleErrors)}`,
      );
    }

    const recovery =
      mode === 'plan'
        ? null
        : await saveRecovery({
            data: await exportBudget(api),
            directory: config.recoveryDir,
          });

    let bankSyncError;
    if (mode === 'run') {
      try {
        await api.runBankSync();
      } catch (error) {
        bankSyncError = error;
      }
    }

    const transactions = await getAllTransactions(api, accounts);
    const plan = planReconciliation(plannerInput(config, rates, transactions));
    if (plan.errors.length > 0) {
      throw new Error(
        `reconciliation refused: ${plan.errors.length} transaction error(s): ${countReasons(plan.errors)}`,
      );
    }

    let applied = 0;
    const planned = planCount(plan);
    if (mode !== 'plan' && planned > 0) {
      try {
        await applyPlan(api, plan);
      } catch {
        const partialTransactions = await getAllTransactions(api, accounts);
        const partial = planReconciliation(
          plannerInput(config, rates, partialTransactions),
        );
        if (partial.errors.length > 0) {
          throw new Error(
            `reconciliation apply failed; recovery=${recovery.fileName}; partial state requires restore; errors=${partial.errors.length}`,
          );
        }
        throw new Error(
          `reconciliation apply failed; recovery=${recovery.fileName}; partial state is resumable; remaining=${planCount(partial)}`,
        );
      }
      applied = planned;
    }

    if (mode !== 'plan') {
      await api.sync();
      const verifiedTransactions = await getAllTransactions(api, accounts);
      const verified = planReconciliation(
        plannerInput(config, rates, verifiedTransactions),
      );
      const remaining = planCount(verified);
      if (verified.errors.length > 0 || remaining > 0) {
        throw new Error(
          `post-apply verification failed: remaining=${remaining}, errors=${verified.errors.length}`,
        );
      }
    }

    if (bankSyncError) {
      throw new Error(
        `bank sync failed after reconciliation: ${bankSyncError.message}`,
      );
    }

    return {
      applied,
      bankSync: mode === 'run' ? 'ok' : 'skipped',
      awaitingFxPair: plan.skipped.filter(
        item => item.reason === 'awaiting-fx-pair',
      ).length,
      pending: plan.skipped.filter(item => item.reason === 'pending-transaction')
        .length,
      planned,
      recovery: recovery?.fileName ?? null,
    };
  } finally {
    if (initialized) {
      await api.shutdown();
    }
  }
}
