#!/usr/bin/env node
import { readFile } from 'node:fs/promises';

import { actualApi as api } from './api.mjs';
import {
  dateInTimeZone,
  parseArgs,
  redactSecrets,
  stripTrailingNewline,
} from './config.mjs';
import { assertRateFeedFresh, fetchEcbRates } from './ecb.mjs';
import { runWorker } from './worker.mjs';

function requireString(value, label) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }
  return value;
}

function requireNamedEntity(value, label) {
  return {
    id: requireString(value?.id, `${label}.id`),
    name: requireString(value?.name, `${label}.name`),
  };
}

async function readCredential(variable) {
  const path = requireString(process.env[variable], variable);
  const value = stripTrailingNewline(await readFile(path, 'utf8'));
  return requireString(value, variable);
}

async function main(sensitiveValues) {
  const { configPath, mode } = parseArgs(process.argv.slice(2));
  const fileConfig = JSON.parse(await readFile(configPath, 'utf8'));
  const password = await readCredential('ACTUAL_PASSWORD_FILE');
  sensitiveValues.push(password);
  const syncId = await readCredential('ACTUAL_SYNC_ID_FILE');
  sensitiveValues.push(syncId);
  const config = {
    ...fileConfig,
    actualVersion: requireString(fileConfig.actualVersion, 'actualVersion'),
    adjustmentPayee: requireNamedEntity(
      fileConfig.adjustmentPayee,
      'adjustmentPayee',
    ),
    baseCurrency: requireString(fileConfig.baseCurrency, 'baseCurrency'),
    dataDir: requireString(fileConfig.dataDir, 'dataDir'),
    fxCategory: requireNamedEntity(fileConfig.fxCategory, 'fxCategory'),
    password,
    recoveryDir: requireString(fileConfig.recoveryDir, 'recoveryDir'),
    serverURL: requireString(fileConfig.serverURL, 'serverURL'),
    syncId,
  };
  if (
    !Array.isArray(config.foreignAccounts) ||
    config.foreignAccounts.length === 0
  ) {
    throw new Error('foreignAccounts must contain at least one account');
  }
  const today = dateInTimeZone(
    new Date(),
    requireString(config.timeZone, 'timeZone'),
  );
  const rates = await fetchEcbRates();
  assertRateFeedFresh(rates, today);
  const result = await runWorker({ api, config, mode, rates });
  process.stdout.write(`${JSON.stringify(result)}\n`);
}

const sensitiveValues = [];
main(sensitiveValues).catch(error => {
  process.stderr.write(
    `actual-bank-sync: ${redactSecrets(error.message, sensitiveValues)}\n`,
  );
  process.exitCode = 1;
});
