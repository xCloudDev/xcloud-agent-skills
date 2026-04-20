---
name: xcloud-public-api
description: Interact with the xCloud Public API at https://app.xcloud.host/api/v1 using the published docs at https://app.xcloud.host/api/v1/docs. Covers auth, scopes, curl patterns, endpoint selection, and async polling.
version: 1.0.0
author: Cypher
license: MIT
---

# xCloud Public API

Use this whenever the task involves reading or mutating xCloud resources through the hosted Public API rather than via the repo or UI.

Docs source: `https://app.xcloud.host/api/v1/docs`
Base URL: `https://app.xcloud.host/api/v1`
OpenAPI version in docs: `3.0.3`
API version in docs: `v1.0.0-beta`

## What this API covers

- Health check
- Current user and API token listing/revocation
- Cloudflare integrations
- Servers
- Server sites/databases/cron jobs/monitoring/tasks/PHP versions
- Server reboot
- Sudo user list/create/delete
- WordPress site creation on a server
- Blueprints list
- Sites
- Site status, SSL, domain, backups, monitoring, events, deployment logs, git, SSH config
- Site backup trigger
- Site rescue trigger
- Site cache purge
- Site SSH/SFTP config update

## Authentication

All endpoints except `GET /health` require a Sanctum personal access token.

Required headers:

```http
Authorization: Bearer <token>
Accept: application/json
Content-Type: application/json
```

Preferred env var when using terminal:

```bash
export XCLOUD_API_TOKEN='...'
```

Canonical curl wrapper:

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json"
```

If the user asks you to use the API and no token is available, ask them for a token or ask where it is stored.

## Scopes

- `read:servers` — list/view servers, databases, cron jobs, PHP versions, monitoring, sudo users
- `write:servers` — reboot servers, create WordPress sites, manage sudo users
- `read:sites` — list/view sites, backups, SSL, domain, git, deployment logs, SSH config
- `write:sites` — trigger backups, purge cache, update SSH/SFTP config
- `*` — full access to all endpoints

## Response conventions

Success envelope:

```json
{
  "success": true,
  "message": "Operation completed successfully.",
  "data": {}
}
```

Many list endpoints in the docs show paginated list responses, but the live API may return pagination as `data.items` plus `data.pagination` instead of `data.data` plus `data.meta`.

Live verified example shape from `GET /servers`:

```json
{
  "success": true,
  "message": "Success",
  "data": {
    "items": [],
    "pagination": {
      "total": 1,
      "per_page": 15,
      "current_page": 1,
      "last_page": 1
    }
  }
}
```

So when scripting, inspect the actual payload first and support both shapes:
- `data.items` / `data.pagination`
- `data.data` / `data.meta`

## Rate limits

- Authenticated: 60 requests/minute
- Unauthenticated: 10 requests/minute

Expect `429` with `Retry-After` if exceeded.

## Resource identifiers

- Servers use `{uuid}`
- Sites use `{uuid}`
- Sudo users use `{sudo_user_uuid}`
- User token revocation uses numeric `{tokenId}` in the current docs
- Prefer UUID endpoints for servers/sites and do not assume numeric IDs except where the docs explicitly say so

## Core workflow

1. Verify connectivity first when useful:

```bash
curl -sS https://app.xcloud.host/api/v1/health
```

2. Resolve the resource UUID before mutating it:
- use `GET /servers` to find server UUIDs
- use `GET /sites` or `GET /servers/{uuid}/sites` to find site UUIDs
- use `GET /blueprints` before using `blueprint_uuid`

3. For async write operations, poll a read endpoint afterward:
- server reboot -> `GET /servers/{uuid}/tasks` or `GET /servers/{uuid}`
- WordPress site creation -> `GET /sites/{uuid}/status`
- site backup -> `GET /sites/{uuid}/events` or `GET /sites/{uuid}/backups`
- cache purge -> `GET /sites/{uuid}/events`
- sudo user create/delete -> `GET /servers/{uuid}/sudo-users`

4. Keep responses trimmed with `jq` so you return useful output, not raw noise.

## Canonical read examples

Health:

```bash
curl -sS https://app.xcloud.host/api/v1/health | jq
```

Current user:

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  https://app.xcloud.host/api/v1/user | jq
```

List servers:

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | jq
```

Get one server:

```bash
SERVER_UUID='replace-me'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | jq
```

List sites across all servers:

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=100" | jq
```

Get one site:

```bash
SITE_UUID='replace-me'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq
```

List blueprints:

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/blueprints?per_page=100" | jq
```

## Canonical write examples

Reboot server:

```bash
SERVER_UUID='replace-me'
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/reboot" | jq
```

Create/update sudo user:

```bash
SERVER_UUID='replace-me'
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sudo-users" \
  -d '{
    "username": "deploy",
    "password": "S3cur3P@ss!",
    "ssh_public_keys": ["ssh-ed25519 AAAA... user@host"],
    "is_temporary": false
  }' | jq
```

Delete sudo user:

```bash
SERVER_UUID='replace-me'
SUDO_USER_UUID='replace-me'
curl -sS -X DELETE \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sudo-users/$SUDO_USER_UUID" | jq
```

Create WordPress site:

```bash
SERVER_UUID='replace-me'
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites/wordpress" \
  -d '{
    "mode": "live",
    "domain": "example.com",
    "title": "My Awesome Site",
    "php_version": "8.2",
    "ssl": {"provider": "letsencrypt"},
    "cache": {"full_page": true, "object_cache": true}
  }' | jq
```

Trigger backup:

```bash
SITE_UUID='replace-me'
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backup" | jq
```

Purge full-page cache:

```bash
SITE_UUID='replace-me'
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/cache/purge" | jq
```

Update SSH/SFTP config to public keys:

```bash
SITE_UUID='replace-me'
curl -sS -X PUT \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
  -d '{
    "authentication_mode": "public_key",
    "ssh_public_keys": ["ssh-ed25519 AAAA... user@host"]
  }' | jq
```

Update SSH/SFTP config to password auth:

```bash
SITE_UUID='replace-me'
curl -sS -X PUT \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
  -d '{
    "authentication_mode": "password",
    "password": "Str0ngP@ssw0rd!"
  }' | jq
```

## Polling patterns

Poll site status after WordPress creation:

```bash
SITE_UUID='replace-me'
watch -n 10 "curl -sS -H 'Authorization: Bearer $XCLOUD_API_TOKEN' -H 'Accept: application/json' https://app.xcloud.host/api/v1/sites/$SITE_UUID/status | jq"
```

Poll site events after backup or cache purge:

```bash
SITE_UUID='replace-me'
watch -n 10 "curl -sS -H 'Authorization: Bearer $XCLOUD_API_TOKEN' -H 'Accept: application/json' https://app.xcloud.host/api/v1/sites/$SITE_UUID/events | jq"
```

## Common filters

Servers:
- `GET /servers?search=<term>`
- `GET /servers?status=active`
- `GET /servers?page=1&per_page=100`

Sites:
- `GET /sites?search=<domain-or-title>`
- `GET /sites?status=active`
- `GET /sites?type=wordpress`
- `GET /sites?server_uuid=<server-uuid>`
- `GET /sites?page=1&per_page=100`

## Important constraints from the docs

- The API is beta; response shapes may change.
- `GET /health` is the only unauthenticated endpoint.
- `domain` is required for WordPress creation when `mode=live`.
- For demo WordPress sites, omit `domain`.
- `ssl.provider` is required for live WordPress creation.
- `blueprint_uuid` and `snapshot_uuid` are mutually exclusive in WordPress create requests.
- Auto-generated credentials may be returned only once in WordPress create responses.
- For SSH updates:
  - `authentication_mode=public_key` requires `ssh_public_keys`
  - `authentication_mode=password` requires `password`

## Good operating style

- Prefer read endpoints first to resolve UUIDs before writes.
- Before destructive or state-changing actions, restate the target resource clearly.
- Return a concise summary plus the relevant fields extracted with `jq`.
- For bulk inspection, prefer a shape-tolerant jq expression, for example:
  `jq '(.data.items // .data.data // []) | map({uuid,name,status})'`
- For pagination metadata, prefer:
  `jq '.data.pagination // .data.meta'`
- For blueprints, start with `jq '(.data.items // []) | map({uuid,name,is_default,is_public})'`.

## Pitfalls

- Do not assume all list endpoints use the same pagination shape; blueprints differ.
- Do not assume numeric IDs except where the docs explicitly show one, such as `/user/tokens/{tokenId}`.
- Do not expect private keys or secret SSH material to be returned.
- Async operations may return success immediately while work is still in progress; always poll a read endpoint.

## Troubleshooting pattern: site is provisioned but returns 502

When a site is publicly returning `502 Bad Gateway` but the xCloud API still reports it as `provisioned`, use this quick triage flow:

1. Reproduce the HTTP failure directly:

```bash
curl -sS -I https://example.com
```

2. Pull the site details, status, events, SSH config, and related server tasks:

```bash
SITE_UUID='replace-me'
SERVER_UUID='replace-me'

curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events" | jq
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" | jq
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/tasks" | jq
```

3. Correlate recent failed events with the site user from `GET /sites/{uuid}/ssh`.

Live finding from this account: for `dev8.io`, the site returned nginx 502 while events repeatedly showed:

```text
sudo: unknown user dev8
sudo: error initializing audit plugin sudoers_audit
```

and `GET /sites/{uuid}/ssh` showed:

```json
{ "site_user": "dev8" }
```

That strongly indicates the site's OS user is missing, which likely breaks PHP-FPM/pool execution for the site and surfaces as nginx 502.

4. If you see that pattern, treat the likely root cause as:
- missing site system user
- broken PHP-FPM pool/runtime for that site

Secondary findings like revoked SSL may also exist, but they do not usually explain an nginx-generated 502.

## Verification

When setting up or troubleshooting API access, verify in this order:

```bash
curl -sS https://app.xcloud.host/api/v1/health | jq
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" https://app.xcloud.host/api/v1/user | jq
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers?per_page=1" | jq
```

If `/user` fails with 401, the token is wrong or missing.
If `/user` works but a later endpoint returns 403, the token likely lacks the needed scope.
