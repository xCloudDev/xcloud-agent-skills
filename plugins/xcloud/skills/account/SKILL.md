---
name: account
description: xCloud account, teams, and org-level reads — current user, the teams this connection may act on (multi-team), incident alerts (list, read, mark as read), API token listing and revocation, connected Git providers and their repositories, Cloudflare integrations, WordPress blueprints, and API health. Use for "who am I", "which teams can you see", "switch to the Acme team", "any open alerts?", "mark resolved alerts as read", token management, or checking integrations. NOT server or site operations (see xcloud:servers / xcloud:sites), NOT billing (see xcloud:billing).
---

# xCloud Account

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Identity and org-level endpoints. For auth, base URL, and response conventions
read the shared layer first:

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/mcp.md` — **prefer the MCP tools when
  connected**: `user_show`, `teams_index`, `alerts_index`, `alerts_show`,
  `alerts_read`, `integrations_git_index`, `integrations_git_repositories`,
  `blueprints_index`, `integrations_cloudflare_index`.
  **Exception:** `/health` and API-token list/revoke are REST-only — the MCP
  never exposes token management; always use `$XC` for those.

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
```

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · Account**`, give the trimmed
result, and close with a `_via xcloud:account_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching your account…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Fetching…" or "Checking…". Say `xCloud is fetching…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## What this skill owns

| Operation | Method + path | Scope |
|---|---|---|
| API health | `GET /health` | none |
| Current user | `GET /user` | token |
| Teams this token may act on | `GET /teams` | token |
| Incident alerts (filter `unread`, `severity`, `category`) | `GET /alerts` | `read:servers` or `read:sites` |
| One alert | `GET /alerts/{alertUuid}` | `read:servers` or `read:sites` |
| Mark an alert read / unread | `PUT /alerts/{alertUuid}/read` | `read:servers` or `read:sites` |
| List API tokens | `GET /user/tokens` | token (`*`) |
| Revoke a token | `DELETE /user/tokens/{tokenUuid}` | token (`*`) |
| List Cloudflare integrations | `GET /integrations/cloudflare` | `read:servers` |
| List connected Git providers | `GET /integrations/git` | `read:servers` |
| Repositories a provider exposes | `GET /integrations/git/{provider_uuid}/repositories` | `read:servers` |
| List blueprints | `GET /blueprints` | `read:servers` |

**Not here:** server management → `xcloud:servers`; site management →
`xcloud:sites`; deploying → `xcloud:deploy`; plans and invoices →
`xcloud:billing`.

## Teams

`GET /teams` lists the default team and every extra team granted to this token
or connection, with the user's `role` in each. When the user names a team,
match it here and pass its uuid as `team` (MCP) or `XCLOUD_TEAM_ID` (REST) on
every call of that task — see `reference/conventions.md` → **Teams**. One team
listed while the user expects more means the connection was authorized for one
team: explain how to re-authorize it with more (`reference/mcp.md`).

## Incident alerts

`GET /alerts` is the team's incident-notification **history** (availability,
resources, deployments, backups, SSL, security), newest first, with an
`unread_count`. It is not a list of currently open incidents: before calling
something "still broken", check the resource itself (site status, SSL, backup
status). Summarise one line per alert — what, which resource, when — and group
repeats ("3 failed backups on `shop.example.com` since Monday"). Offer the fix
through the owning skill. Marking read (`PUT … {"is_read": true}`) only changes
this user's read state; do it when asked, or for alerts the user confirms are
resolved.

## Examples

Health (the only unauthenticated endpoint):

```bash
"$XC" GET /health | jq
```

Who am I (verifies the token):

```bash
"$XC" GET /user | jq '.data | {uuid, name, email, team: .team.name}'
```

List API tokens (needs the `*` scope) — note each token's `uuid`, which is what
the revoke call below takes:

```bash
"$XC" GET /user/tokens | jq '(.data.items // .data.data // .data) | map({uuid, name, last_used_at})'
```

Revoke a token (pass the `uuid` from the list above — restate before running):

```bash
TOKEN_UUID='8c1f3a89-2c4e-4a73-9d4c-8b1f2a3d4e5f'
"$XC" DELETE "/user/tokens/$TOKEN_UUID" | jq '.message'
```

Teams and unread error alerts:

```bash
"$XC" GET /teams | jq '.data | map({uuid, name, role, is_default})'
"$XC" GET "/alerts?unread=true&severity=error&per_page=20" \
  | jq '{unread: .data.unread_count, alerts: (.data.items | map({title, category, at: .recorded_at, resource: .resource.name}))}'
ALERT_UUID='replace-me'
"$XC" PUT "/alerts/$ALERT_UUID/read" '{"is_read":true}' | jq '.data | {title, is_read}'
```

Cloudflare integrations on the team:

```bash
"$XC" GET /integrations/cloudflare | jq '.data'
```

Blueprints (resolve a `blueprint_uuid` before creating a WordPress site):

```bash
"$XC" GET "/blueprints?per_page=100" \
  | jq '(.data.items // .data.data // .data) | map({uuid, name, is_default, is_public})'
```

## Pitfalls

- Token revocation is keyed by the token's **`uuid`** (from `GET /user/tokens`),
  not a numeric id — `DELETE /user/tokens/{tokenUuid}`.
- `GET /user/tokens` returns `403` unless the token carries the `*` scope.
- `blueprints` requires `read:servers`, not `read:sites`.
- Alerts are filtered by what the token may read: a `read:sites`-only token sees
  site alerts, not server ones.
