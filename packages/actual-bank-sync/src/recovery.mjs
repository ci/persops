import { createHash, randomUUID } from 'node:crypto';
import {
  chmod,
  mkdir,
  open,
  readdir,
  rename,
  unlink,
} from 'node:fs/promises';

async function writeAtomic(path, data) {
  const temporary = `${path}.tmp-${process.pid}-${randomUUID()}`;
  const handle = await open(temporary, 'wx', 0o600);
  try {
    await handle.writeFile(data);
    await handle.sync();
  } finally {
    await handle.close();
  }
  await rename(temporary, path);
}

export async function saveRecoveryArtifact({
  data,
  directory,
  keep = 7,
  now = new Date(),
}) {
  if (
    !(data instanceof Uint8Array) ||
    data.length < 4 ||
    data[0] !== 0x50 ||
    data[1] !== 0x4b ||
    data[2] !== 0x03 ||
    data[3] !== 0x04
  ) {
    throw new Error('recovery data is not an Actual ZIP export');
  }
  if (!Number.isInteger(keep) || keep < 1) {
    throw new Error('recovery retention must be a positive integer');
  }

  await mkdir(directory, { recursive: true, mode: 0o700 });
  await chmod(directory, 0o700);
  const timestamp = now.toISOString().replaceAll(':', '-');
  const fileName = `actual-${timestamp}.zip`;
  const path = `${directory}/${fileName}`;
  const digest = createHash('sha256').update(data).digest('hex');
  await writeAtomic(path, data);
  await writeAtomic(`${path}.sha256`, `${digest}  ${fileName}\n`);

  const oldExports = (await readdir(directory))
    .filter(entry => /^actual-.*\.zip$/.test(entry))
    .sort()
    .slice(0, -keep);
  for (const oldExport of oldExports) {
    await unlink(`${directory}/${oldExport}`);
    await unlink(`${directory}/${oldExport}.sha256`).catch(() => {});
  }

  return { digest, fileName };
}
