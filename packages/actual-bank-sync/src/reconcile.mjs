const ADJUSTMENT_MARKER =
  /\[actual-fx-adj:v1\|for=([^|\]]+)\|role=(PRIMARY|COUNTER)\|orig=(-?\d+)\|ccy=(EUR|GBP)\|rate=([0-9.]+)\|date=(\d{4}-\d{2}-\d{2})\|source=(ECB|EXCHANGE|LINKED)\]$/;

const LEGACY_NOTE =
  /^(-?\d+\.\d{2}) (EUR|GBP) \(FX rate: ([0-9.]+)\)(?: • ([\s\S]*))?$/;

function decimalAmountToCents(value) {
  if (typeof value !== 'string') {
    throw new Error('invalid-trusted-original');
  }
  const match = /^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(value);
  if (!match) {
    throw new Error('invalid-trusted-original');
  }
  const cents =
    Number(match[2]) * 100 + Number((match[3] ?? '').padEnd(2, '0'));
  if (!Number.isSafeInteger(cents)) {
    throw new Error('invalid-trusted-original');
  }
  return match[1] === '-' ? -cents : cents;
}

function roundMoney(value) {
  return Math.sign(value) * Math.round(Math.abs(value));
}

function resolveRate(rates, currency, date) {
  const rateDate = Object.keys(rates)
    .filter(candidate => candidate <= date && rates[candidate]?.[currency])
    .sort()
    .at(-1);
  if (!rateDate) {
    throw new Error(`no ${currency} ECB rate on or before ${date}`);
  }
  return { rate: rates[rateDate][currency], rateDate };
}

function shouldAwaitRate(rates, date) {
  const latestRateDate = Object.keys(rates).sort().at(-1);
  if (!latestRateDate) return false;
  const day = new Date(`${date}T00:00:00Z`).getUTCDay();
  return date > latestRateDate && day >= 1 && day <= 5;
}

function readOriginal(transaction, account) {
  if (transaction.raw_synced_data) {
    const raw = parseRaw(transaction);
    const currency =
      raw.transactionAmount?.currency ?? raw.transaction_amount?.currency;
    const amount = raw.amount ?? raw.transactionAmount?.amount;
    const originalCents = decimalAmountToCents(amount);
    if (currency !== account.currency) {
      throw new Error('trusted-original-mismatch');
    }
    return {
      currency,
      entryReference: raw.entry_reference ?? raw.entryReference,
      isExchange: raw.bank_transaction_code?.code === 'EXCHANGE',
      originalCents,
    };
  }

  if (transaction.imported_id && !transaction.starting_balance_flag) {
    throw new Error('missing-trusted-original');
  }

  const legacy = LEGACY_NOTE.exec(transaction.notes ?? '');
  if (!legacy) {
    throw new Error('missing-bridge-marker');
  }
  if (legacy[2] !== account.currency || legacy[3] !== account.bridgeRate) {
    throw new Error('bridge-marker-drift');
  }
  return {
    currency: legacy[2],
    isExchange: false,
    originalCents: decimalAmountToCents(legacy[1]),
  };
}

function parseRaw(transaction) {
  try {
    return JSON.parse(transaction.raw_synced_data);
  } catch {
    throw new Error('invalid-trusted-original');
  }
}

function exchangeMetadata(transaction) {
  if (!transaction.raw_synced_data) return null;
  let raw;
  try {
    raw = parseRaw(transaction);
  } catch {
    return null;
  }
  if (raw.bank_transaction_code?.code !== 'EXCHANGE') return null;
  const amount = raw.amount ?? raw.transactionAmount?.amount;
  let originalCents;
  try {
    originalCents = decimalAmountToCents(amount);
  } catch {
    originalCents = null;
  }
  return {
    currency:
      raw.transactionAmount?.currency ?? raw.transaction_amount?.currency,
    entryReference: raw.entry_reference ?? raw.entryReference,
    originalCents,
  };
}

function formatForeignAmount(cents) {
  const sign = cents < 0 ? '-' : '';
  const absolute = Math.abs(cents);
  return `${sign}${Math.floor(absolute / 100)}.${String(absolute % 100).padStart(2, '0')}`;
}

function renderAdjustmentNote({
  sourceId,
  role,
  originalCents,
  currency,
  rate,
  rateDate,
  source,
}) {
  return `FX rate: ${formatForeignAmount(originalCents)} ${currency} at ${rate} ${source} ${rateDate} [actual-fx-adj:v1|for=${sourceId}|role=${role}|orig=${originalCents}|ccy=${currency}|rate=${rate}|date=${rateDate}|source=${source}]`;
}

function isSplit(transaction) {
  return Boolean(
    transaction.is_parent ||
      transaction.isParent ||
      transaction.is_child ||
      transaction.isChild ||
      transaction.parent_id ||
      transaction.subtransactions?.length,
  );
}

function adjustmentKey(sourceId, role) {
  return `${sourceId}\0${role}`;
}

function sameManagedFields(transaction, fields) {
  return Object.entries(fields).every(
    ([key, value]) => transaction[key] === value,
  );
}

export function planReconciliation({
  adjustmentPayeeId,
  baseCurrency = 'RON',
  foreignAccounts,
  fxCategoryId,
  rates,
  transactions,
}) {
  const accountById = new Map(
    foreignAccounts.map(account => [account.id, account]),
  );
  const transactionById = new Map(
    transactions.map(transaction => [transaction.id, transaction]),
  );
  const creates = [];
  const updates = [];
  const sourceUpdates = [];
  const skipped = [];
  const errors = [];
  const adjustments = new Map();
  const adjustmentCandidateIds = new Set();
  const exchangesByReference = new Map();
  const expectedAdjustmentKeys = new Set();

  function recordExpected(expected) {
    const key = adjustmentKey(expected.sourceId, expected.role);
    expectedAdjustmentKeys.add(key);
    const adjustment = adjustments.get(key);
    if (!adjustment) {
      creates.push(expected);
    } else if (sameManagedFields(adjustment, expected.fields)) {
      skipped.push({ id: adjustment.id, reason: 'already-reconciled' });
    } else {
      updates.push({ id: adjustment.id, fields: expected.fields });
    }
  }

  for (const transaction of transactions) {
    const exchange = exchangeMetadata(transaction);
    if (exchange?.entryReference) {
      const matches = exchangesByReference.get(exchange.entryReference) ?? [];
      matches.push({ transaction, ...exchange });
      exchangesByReference.set(exchange.entryReference, matches);
    }

    const marker = ADJUSTMENT_MARKER.exec(transaction.notes ?? '');
    const usesManagedPayee =
      Boolean(adjustmentPayeeId) && transaction.payee === adjustmentPayeeId;
    if (!marker && !usesManagedPayee) continue;
    adjustmentCandidateIds.add(transaction.id);
    if (!marker) {
      errors.push({ id: transaction.id, reason: 'invalid-adjustment-marker' });
      continue;
    }
    if (
      !usesManagedPayee ||
      transaction.imported_id ||
      transaction.raw_synced_data ||
      transaction.transfer_id ||
      isSplit(transaction)
    ) {
      errors.push({ id: transaction.id, reason: 'absorbed-adjustment' });
      continue;
    }
    if (transaction.reconciled) {
      errors.push({ id: transaction.id, reason: 'reconciled-adjustment' });
      continue;
    }
    const key = adjustmentKey(marker[1], marker[2]);
    if (adjustments.has(key)) {
      errors.push({ id: transaction.id, reason: 'duplicate-adjustment' });
      continue;
    }
    adjustments.set(key, transaction);
  }

  for (const transaction of transactions) {
    const account = accountById.get(transaction.account);
    if (!account || adjustmentCandidateIds.has(transaction.id)) continue;

    if (isSplit(transaction)) {
      errors.push({ id: transaction.id, reason: 'split-transaction' });
      continue;
    }

    try {
      const original = readOriginal(transaction, account);
      const bridgeAmount = roundMoney(
        original.originalCents * Number(account.bridgeRate),
      );
      if (transaction.amount !== bridgeAmount) {
        errors.push({ id: transaction.id, reason: 'bridge-amount-drift' });
        continue;
      }
      if (!transaction.cleared) {
        skipped.push({ id: transaction.id, reason: 'pending-transaction' });
        continue;
      }
      let rate;
      let rateDate;
      let targetAmount;
      let category = transaction.category;
      let source = 'ECB';
      let counterpart;

      if (transaction.transfer_id) {
        counterpart = transactionById.get(transaction.transfer_id);
        if (
          !counterpart ||
          counterpart.transfer_id !== transaction.id ||
          accountById.has(counterpart.account) ||
          counterpart.date !== transaction.date ||
          isSplit(counterpart) ||
          counterpart.amount !== -bridgeAmount
        ) {
          errors.push({ id: transaction.id, reason: 'invalid-transfer-pair' });
          continue;
        }
        if (shouldAwaitRate(rates, transaction.date)) {
          skipped.push({ id: transaction.id, reason: 'awaiting-ecb-rate' });
          continue;
        }
        ({ rate, rateDate } = resolveRate(
          rates,
          original.currency,
          transaction.date,
        ));
        targetAmount = roundMoney(original.originalCents * Number(rate));
        category = fxCategoryId;
        source = 'LINKED';
      } else if (original.isExchange) {
        if (!original.entryReference) {
          errors.push({ id: transaction.id, reason: 'invalid-exchange-pair' });
          continue;
        }
        const candidates = (
          exchangesByReference.get(original.entryReference) ?? []
        ).filter(
          candidate =>
            candidate.transaction.id !== transaction.id &&
            !accountById.has(candidate.transaction.account) &&
            candidate.currency === baseCurrency,
        );
        if (candidates.length === 0) {
          skipped.push({ id: transaction.id, reason: 'awaiting-fx-pair' });
          continue;
        }
        if (candidates.length !== 1) {
          errors.push({ id: transaction.id, reason: 'ambiguous-exchange-pair' });
          continue;
        }
        counterpart = candidates[0].transaction;
        if (!counterpart.cleared) {
          skipped.push({ id: transaction.id, reason: 'awaiting-fx-pair' });
          continue;
        }
        targetAmount = -counterpart.amount;
        if (
          counterpart.date !== transaction.date ||
          counterpart.transfer_id ||
          isSplit(counterpart) ||
          candidates[0].originalCents !== counterpart.amount ||
          targetAmount === 0 ||
          original.originalCents === 0 ||
          Math.sign(targetAmount) !== Math.sign(original.originalCents)
        ) {
          errors.push({ id: transaction.id, reason: 'invalid-exchange-pair' });
          continue;
        }
        rate = (
          Math.abs(targetAmount) / Math.abs(original.originalCents)
        ).toFixed(6);
        rateDate = transaction.date;
        source = 'EXCHANGE';
        category = fxCategoryId;
        if (transaction.category !== fxCategoryId) {
          sourceUpdates.push({
            id: transaction.id,
            fields: { category: fxCategoryId },
          });
        }
        if (counterpart.category !== fxCategoryId) {
          sourceUpdates.push({
            id: counterpart.id,
            fields: { category: fxCategoryId },
          });
        }
      } else {
        if (shouldAwaitRate(rates, transaction.date)) {
          skipped.push({ id: transaction.id, reason: 'awaiting-ecb-rate' });
          continue;
        }
        ({ rate, rateDate } = resolveRate(
          rates,
          original.currency,
          transaction.date,
        ));
        targetAmount = roundMoney(original.originalCents * Number(rate));
      }
      const amount = targetAmount - bridgeAmount;
      if (amount === 0) {
        skipped.push({ id: transaction.id, reason: 'no-adjustment-needed' });
        continue;
      }
      recordExpected({
        sourceId: transaction.id,
        role: 'PRIMARY',
        fields: {
          account: transaction.account,
          amount,
          category,
          cleared: true,
          date: transaction.date,
          notes: renderAdjustmentNote({
            sourceId: transaction.id,
            role: 'PRIMARY',
            originalCents: original.originalCents,
            currency: original.currency,
            rate,
            rateDate,
            source,
          }),
          payee: adjustmentPayeeId,
          reconciled: false,
        },
      });
      if (source === 'LINKED') {
        recordExpected({
          sourceId: transaction.id,
          role: 'COUNTER',
          fields: {
            account: counterpart.account,
            amount: -amount,
            category: fxCategoryId,
            cleared: true,
            date: transaction.date,
            notes: renderAdjustmentNote({
              sourceId: transaction.id,
              role: 'COUNTER',
              originalCents: original.originalCents,
              currency: original.currency,
              rate,
              rateDate,
              source,
            }),
            payee: adjustmentPayeeId,
            reconciled: false,
          },
        });
      }
    } catch (error) {
      errors.push({ id: transaction.id, reason: error.message });
    }
  }

  for (const [key, adjustment] of adjustments) {
    if (!expectedAdjustmentKeys.has(key)) {
      errors.push({ id: adjustment.id, reason: 'orphan-adjustment' });
    }
  }

  return { creates, updates, sourceUpdates, skipped, errors };
}
