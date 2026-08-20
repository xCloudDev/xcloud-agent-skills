
# xCloud SSL

Owns every SSL/certificate operation in the xCloud Public API. For auth, base
URL, the response envelope, pagination, and rate limits, read the shared layer
first — this skill does not repeat it:

- `reference/auth.md`
- `reference/conventions.md`
- `reference/mcp.md` — **prefer the MCP tools when
  connected**: `sites_ssl`, `sites_sslCertificates`, `sites_sslCertificates_create`,
  `sites_ssl_renew`, `ssl-certificates_show`, `ssl-certificates_status`,
  `ssl-certificates_destroy`; the `$XC` calls below are the REST fallback.

All calls go through the shared wrapper:

```bash
XC="scripts/xcloud.sh"
```

Set `XCLOUD_API_BASE_URL=http://xcloud.test` (plus
`XCLOUD_ALLOW_INSECURE_HTTP=1` — plaintext http is refused without it) for
local, unset (or
`https://app.xcloud.host`) for live.

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · SSL** — <site domain>`, give the
trimmed result, and close with a `_via xcloud:ssl_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is renewing the SSL certificate for
\`<domain>\`…`; the first call of a task opens with
`☁️ xCloud is starting a session…`. **Every progress line and every action
sentence must start with `xCloud` as the actor — never a bare verb like
"Renewing…" or "Checking…". Say `xCloud is renewing…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## What this skill owns

| Operation | Method + path | Scope |
|---|---|---|
| Get site SSL info | `GET /sites/{uuid}/ssl` | `read:sites` |
| List site certificates | `GET /sites/{uuid}/ssl-certificates` | `read:sites` |
| Install a certificate | `POST /sites/{uuid}/ssl-certificates` | `write:sites` |
| Renew a certificate | `POST /sites/{uuid}/ssl/renew` | `write:sites` + `site:manage-ssl` |
| Get certificate by UUID | `GET /ssl-certificates/{uuid}` | `read:sites` |
| Get certificate status | `GET /ssl-certificates/{uuid}/status` | `read:sites` |
| Delete a certificate | `DELETE /ssl-certificates/{uuid}` | `write:sites` |

**Not here:** site backups/domains/cache/SSH → `xcloud:sites`; WordPress plugin
vulnerabilities → `xcloud:wordpress`; server firewall/fail2ban → `xcloud:servers`.

## Workflow

1. Resolve the site UUID first (via `xcloud:sites`: `GET /sites?search=<domain>`).
2. Inspect current SSL before changing it.
3. Installs/renewals are async — poll certificate status afterward.

## Reads

Current SSL state for a site:

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/ssl" | jq '.data'
```

List a site's certificates:

```bash
"$XC" GET "/sites/$SITE_UUID/ssl-certificates" \
  | jq '(.data.items // .data.data // .data) | map({uuid, provider, status, domains, expires_at})'
```

Certificate detail / status by UUID:

```bash
CERT_UUID='replace-me'
"$XC" GET "/ssl-certificates/$CERT_UUID" | jq '.data'
"$XC" GET "/ssl-certificates/$CERT_UUID/status" | jq '.data'
```

## Writes

Install a Let's Encrypt (xCloud-managed) certificate:

```bash
"$XC" POST "/sites/$SITE_UUID/ssl-certificates" '{"provider":"xcloud"}' | jq '.data'
```

Install a custom certificate (PEM body + key required). The private key is a
secret — build the JSON with `jq -n` from files and pipe it on **stdin** (`-`)
so it never appears in any process argument list:

```bash
jq -n --rawfile cert cert.pem --rawfile key key.pem \
  '{provider: "custom", certificate: $cert, private_key: $key}' \
  | "$XC" POST "/sites/$SITE_UUID/ssl-certificates" - | jq '.data'
```

Use the team's Cloudflare integration:

```bash
"$XC" POST "/sites/$SITE_UUID/ssl-certificates" '{"provider":"cloudflare"}' | jq '.data'
```

Switch providers when one is already configured — `force` is required:

```bash
"$XC" POST "/sites/$SITE_UUID/ssl-certificates" '{"provider":"cloudflare","force":true}' | jq '.data'
```

WordPress site adopting HTTPS for the first time — opt into the DB search-replace:

```bash
"$XC" POST "/sites/$SITE_UUID/ssl-certificates" '{"provider":"xcloud","ssl_search_replace":true}' | jq '.data'
```

Renew (only fires if the cert expires within 7 days unless forced):

```bash
"$XC" POST "/sites/$SITE_UUID/ssl/renew" '{}'            | jq '.data'   # guarded
"$XC" POST "/sites/$SITE_UUID/ssl/renew" '{"force":true}' | jq '.data'  # skip the 7-day guard
```

Delete a certificate (restate the target before running):

```bash
"$XC" DELETE "/ssl-certificates/$CERT_UUID" | jq '.message'
```

## Request notes (from the spec)

- `provider` ∈ `xcloud` | `custom` | `cloudflare` (required on install).
- `provider=custom` requires both `certificate` and `private_key` (PEM).
- `force: true` is required only to switch to a *different* provider; ignored
  when none is set or the provider matches.
- `ssl_search_replace` applies to WordPress sites only; silently ignored
  elsewhere.
- Renew without `force` is a no-op unless the cert is within 7 days of expiry.

## Pitfalls

- `403` on renew with a valid token = missing `site:manage-ssl` team permission.
- Private key material is never returned by reads — do not expect it.
- Installs/renewals report success before issuance completes; confirm via
  `GET /ssl-certificates/{uuid}/status`.
