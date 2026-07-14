---
name: share-page
description: "Publish an HTML page to the personal share domain share.ca7.ir. Explicit trigger only: /share-page, 'publish this on share.ca7.ir', 'put this on my share domain'. Do NOT trigger on generic 'share' wording, Artifacts, or claude.ai sharing."
---

# Share Page

Publish a standalone HTML file at `https://share.ca7.ir/<random-hash>` for
sharing with others. Invoke only on an explicit ask ("publish on share.ca7.ir",
"give me a share link on my domain", `/share-page`) — never proactively, and
never for the word "share" alone (sharing to Slack, sharing context, Claude
Artifacts, etc. are not this skill).

## Setup facts

- Cloudflare Worker `share-pages` serves KV-backed pages on route
  `share.ca7.ir/*` (zone `ca7.ir`). Proxied AAAA `share` → `100::` exists.
- Pages live in Workers KV namespace `share-pages`; key = hash, value = full
  HTML.
- All credentials/IDs live in the 1Password item
  `op://Private/cloudflare-api-token`: fields `credential` (API token,
  also scoped for zones `catalinirimie.com` and `viii.cm`), `account_id`,
  and `share_pages_kv_namespace_id`. Follow the `one-password` skill rules
  for `op` reads; never print the token.
- The worker serves `text/html` with `x-robots-tag: noindex` and 404s every
  key not in KV (including `/`). Unlisted-URL security only — do not publish
  secrets or private data.

## Publish

The page must be a complete self-contained document (`<!doctype html>` …
inline CSS/JS, no external assets required by CSP anywhere, just good
practice). Then:

```bash
HASH=$(openssl rand -hex 12)
TOKEN=$(op read "op://Private/cloudflare-api-token/credential")
ACCT=$(op read "op://Private/cloudflare-api-token/account_id")
NS=$(op read "op://Private/cloudflare-api-token/share_pages_kv_namespace_id")
curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCT/storage/kv/namespaces/$NS/values/$HASH" \
  -H "Authorization: Bearer $TOKEN" --data-binary "@page.html"
curl -s -o /dev/null -w "%{http_code}\n" "https://share.ca7.ir/$HASH"   # expect 200
```

Give the user the full URL. To update a page in place, re-PUT the same key.
To unpublish, DELETE the same KV values endpoint.

## List / cleanup

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACCT/storage/kv/namespaces/$NS/keys" | jq -r '.result[].name'
```

## Guardrails

- Never touch the `ca7.ir` apex or its DNS record — it points at a legacy EC2
  box that serves the old site.
- One page = one KV write. Do not re-upload or modify the worker script for
  publishing; only change the worker if the serving behavior itself must
  change.
- Hashes are the only access control: always `openssl rand -hex 12`, never
  guessable names.
