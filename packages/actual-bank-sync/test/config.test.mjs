import assert from 'node:assert/strict';
import test from 'node:test';

import {
  dateInTimeZone,
  parseArgs,
  redactSecrets,
  stripTrailingNewline,
} from '../src/config.mjs';

test('parses the explicit worker mode and config path', () => {
  assert.deepEqual(
    parseArgs(['--mode', 'run', '--config', '/etc/actual-bank-sync.json']),
    { mode: 'run', configPath: '/etc/actual-bank-sync.json' },
  );
});

test('refuses implicit or unknown CLI inputs', () => {
  assert.throws(() => parseArgs(['--mode', 'run']), /--config is required/);
  assert.throws(
    () => parseArgs(['--mode', 'maybe', '--config', '/tmp/config']),
    /invalid mode: maybe/,
  );
  assert.throws(
    () => parseArgs(['--mode', 'run', '--surprise', 'yes']),
    /unknown argument: --surprise/,
  );
});

test('credential cleanup removes only terminal line endings', () => {
  assert.equal(stripTrailingNewline(' secret with spaces \r\n'), ' secret with spaces ');
});

test('computes the calendar date in the configured timezone', () => {
  assert.equal(
    dateInTimeZone(new Date('2026-08-15T22:30:00Z'), 'Europe/Bucharest'),
    '2026-08-16',
  );
});

test('redacts every loaded credential from dependency errors', () => {
  assert.equal(
    redactSecrets(
      'unknown file sync-secret while authenticating hunter2',
      ['hunter2', 'sync-secret'],
    ),
    'unknown file [REDACTED] while authenticating [REDACTED]',
  );
});
