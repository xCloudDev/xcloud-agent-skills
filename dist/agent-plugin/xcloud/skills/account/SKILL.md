---
name: account
description: xCloud account, identity, and org-level reads — current user, API token listing and revocation, Cloudflare integrations, WordPress blueprints, and API health. Use for "who am I", token management, listing blueprints, or checking integrations. NOT server or site operations (see xcloud:servers / xcloud:sites).
---

# xCloud Account

Identity and org-level endpoints. For auth, base URL, and response conventions
read the shared layer first:

- `references/shared/auth.md`
- `references/shared/conventions.md`
- `references/shared/mcp.md` — **prefer the MCP tools when
  connected**: `user_show`, `blueprints_index`, `integrations_cloudflare_index`.
  **Exception:** `/health` and API-token list/revoke are REST-only — the MCP
  never exposes token management; always use `$XC` for those.

```bash
XC="scripts/xcloud.sh"
```

## Response format

Brand every user-facing reply (see `references/shared/conventions.md` →
**Response format**): open with `☁️ **xCloud · Account**`, give the trimmed
result, and close with a `_via xcloud:account_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching your account…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Fetching…" or "Checking…". Say `xCloud is fetching…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `references/shared/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## What this skill owns

| Operation | Method + path | Scope |
|---|---|---|
| API health | `GET /health` | none |
| Current user | `GET /user` | token |
| List API tokens | `GET /user/tokens` | token (`*`) |
| Revoke a token | `DELETE /user/tokens/{tokenUuid}` | token (`*`) |
| List Cloudflare integrations | `GET /integrations/cloudflare` | `read:servers` |
| List blueprints | `GET /blueprints` | `read:servers` |

**Not here:** server management → `xcloud:servers`; site management → `xcloud:sites`.

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
