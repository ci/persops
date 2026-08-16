import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm, stat } from 'node:fs/promises';
import test from 'node:test';

import { saveRecoveryArtifact } from '../src/recovery.mjs';

const zip = new TextEncoder().encode('PK\u0003\u0004offline-budget');

test('writes a private hashed recovery export and retains the newest copies', async () => {
  const directory = await mkdtemp('/tmp/actual-recovery-test-');
  try {
    for (const hour of [1, 2, 3]) {
      await saveRecoveryArtifact({
        data: zip,
        directory,
        keep: 2,
        now: new Date(`2026-08-16T0${hour}:00:00Z`),
      });
    }

    const files = (await readdir(directory)).sort();
    assert.deepEqual(files, [
      'actual-2026-08-16T02-00-00.000Z.zip',
      'actual-2026-08-16T02-00-00.000Z.zip.sha256',
      'actual-2026-08-16T03-00-00.000Z.zip',
      'actual-2026-08-16T03-00-00.000Z.zip.sha256',
    ]);
    const latest = `${directory}/actual-2026-08-16T03-00-00.000Z.zip`;
    assert.equal((await stat(latest)).mode & 0o777, 0o600);
    assert.deepEqual(new Uint8Array(await readFile(latest)), zip);
    assert.match(
      await readFile(`${latest}.sha256`, 'utf8'),
      /^[a-f0-9]{64}  actual-2026-08-16T03-00-00\.000Z\.zip\n$/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('refuses a non-ZIP recovery export', async () => {
  const directory = await mkdtemp('/tmp/actual-recovery-test-');
  try {
    await assert.rejects(
      saveRecoveryArtifact({
        data: new Uint8Array([1, 2, 3, 4]),
        directory,
      }),
      /not an Actual ZIP export/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
