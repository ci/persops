# Scoped CLI examples

Run inside the task window created by `SKILL.md`. These examples assume an
already authorized item/vault. Do not print captured values or enable shell tracing.

## Service-account reads and writes

```bash
set -euo pipefail
set +x
export OP_LOAD_DESKTOP_APP_SETTINGS=false
export OP_BIOMETRIC_UNLOCK_ENABLED=false
# OP_SERVICE_ACCOUNT_TOKEN must already be available in this task window.
VAULT="<authorized vault>"
ITEM="<known item>"
FIELD="<exact field label>"
value="$(
  OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
    op item get "$ITEM" --vault "$VAULT" --format json </dev/null |
    FIELD_LABEL="$FIELD" node -e '
      let s="";
      process.stdin.on("data", d => s += d);
      process.stdin.on("end", () => {
        const fields = (JSON.parse(s).fields || []).filter(f => f.label === process.env.FIELD_LABEL);
        if (fields.length !== 1 || !fields[0].value) process.exit(2);
        process.stdout.write(fields[0].value);
      });'
)"
test -n "$value" || exit 1
printf 'field length: %s\n' "${#value}"

# When this write is requested, use the authorized value without printing it.
OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
  op item create --vault "$VAULT" --category "API Credential" \
  --title "<new item>" "api_token[password]=$value" </dev/null >/dev/null
unset value
```

Verify a new item by reading its exact field and checking expected shape or
equality in memory. Use a known secret reference with `op run` / `op inject`
when the consumer supports it. Never demonstrate injection with `printenv`.

## Consented desktop flow

Only after the `SKILL.md` desktop gate is satisfied, in the same task window:

```bash
unset OP_SERVICE_ACCOUNT_TOKEN
unset OP_LOAD_DESKTOP_APP_SETTINGS OP_BIOMETRIC_UNLOCK_ENABLED
op signin --account my.1password.com
# Subsequent authorized commands use --account my.1password.com.
```

Do not copy desktop `--account` flags into service-account commands. Clean up
temporary files and kill the task window when finished.
