const MODES = new Set(['plan', 'reconcile', 'run']);

export function parseArgs(args) {
  const parsed = {};
  for (let index = 0; index < args.length; index += 2) {
    const flag = args[index];
    const value = args[index + 1];
    if (flag !== '--mode' && flag !== '--config') {
      throw new Error(`unknown argument: ${flag}`);
    }
    if (value === undefined || value.startsWith('--')) {
      throw new Error(`${flag} requires a value`);
    }
    if (flag === '--mode') parsed.mode = value;
    if (flag === '--config') parsed.configPath = value;
  }
  if (!parsed.mode) throw new Error('--mode is required');
  if (!MODES.has(parsed.mode)) throw new Error(`invalid mode: ${parsed.mode}`);
  if (!parsed.configPath) throw new Error('--config is required');
  return parsed;
}

export function stripTrailingNewline(value) {
  return value.replace(/(?:\r\n|\r|\n)+$/, '');
}

export function redactSecrets(message, secrets) {
  let redacted = String(message);
  const uniqueSecrets = [...new Set(secrets)]
    .filter(Boolean)
    .sort((a, b) => b.length - a.length);
  for (const secret of uniqueSecrets) {
    redacted = redacted.replaceAll(secret, '[REDACTED]');
    redacted = redacted.replaceAll(encodeURIComponent(secret), '[REDACTED]');
  }
  return redacted;
}

export function dateInTimeZone(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en', {
    day: '2-digit',
    month: '2-digit',
    timeZone,
    year: 'numeric',
  }).formatToParts(date);
  const byType = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${byType.year}-${byType.month}-${byType.day}`;
}
