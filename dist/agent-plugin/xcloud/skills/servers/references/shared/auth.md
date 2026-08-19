# Authentication (shared)

Shared by every xCloud domain skill.

## Two ways to connect — MCP first

1. **xCloud MCP (recommended).** If tools from the MCP server named `xcloud` are available in
   the session, the account is already connected via OAuth — **no token setup is
   needed** and the rest of this file does not apply. Use the MCP tools directly;
   see `references/shared/mcp.md` for the transport rule, tool naming, and the
   confirm-before-destructive contract. If the user has no connection yet,
   onboard them with the MCP connect instructions in `references/shared/mcp.md`
   **before** falling back to a raw API token.
2. **REST API token (fallback).** For agents without MCP support, and for the
   REST-only operations (`/health`, API-token list/revoke). The Public API
   authenticates via [Sanctum personal access tokens](https://laravel.com/docs/sanctum)
   (Bearer auth) — everything below covers this path.

## Environment variables

```bash
export XCLOUD_API_TOKEN="..."                         # required
export XCLOUD_API_BASE_URL="https://app.xcloud.host"  # default (live)
# Local development (plaintext http needs the explicit override):
export XCLOUD_API_BASE_URL="http://xcloud.test"
export XCLOUD_ALLOW_INSECURE_HTTP=1
```

The base URL is the **only** thing that changes between local and live — never
hardcode a host in a skill body.

## Proactive token onboarding

If `XCLOUD_API_TOKEN` is missing or a request returns `401`, stop before any
write operation and guide the user through setup. **Offer the xCloud MCP
connector first** (`references/shared/mcp.md` → Connecting) — OAuth, no secret to
store. Only if MCP isn't an option for their client, walk them through the
token path below. Be proactive and helpful, but do **not** ask the user to
paste a raw production token into the chat by default. Direct them to the
runtime's environment, settings file, or secret store.

Use this wording pattern:

```text
☁️ **xCloud · Setup**

xCloud needs an API token before it can inspect or manage your hosting account.
Create a scoped token in the xCloud dashboard, store it in your agent runtime as
`XCLOUD_API_TOKEN`, restart the agent if needed, then ask me to check the xCloud
connection.

_via xCloud/account_
```

After setup, verify with `GET /health` and `GET /user` before continuing the
original task.

## Setting the token in a portable client

**Step 1 — generate the token.** In the xCloud dashboard, open **Profile → API
Tokens → Generate New Token**. Select the narrowest required scopes and copy the
token immediately.

**Step 2 — store the token.** Put `XCLOUD_API_TOKEN` in the client environment or
its secure secret store. Do not put a token in `plugin.json`, `mcp.json`, a skill
file, source control, or chat. Set `XCLOUD_API_BASE_URL` only for a non-default
xCloud host.

For a temporary terminal session:

```bash
export XCLOUD_API_TOKEN="..."
export XCLOUD_API_BASE_URL="https://app.xcloud.host"
```

Use the client's documented environment or secret configuration for persistent
storage. Restart the client if it does not reload environment changes.

> **Browser/chat-only agents:** prefer the **xCloud MCP connector**
> (`references/shared/mcp.md`) — OAuth, nothing pasted in chat. If a token in chat is
> truly the only option, explain the risk first and enforce all of the
> following:
>
> - **Scoped and short-lived only.** The narrowest scopes that cover the task
>   (e.g. `read:sites`) — **never a `*` (full-access) token in chat**: it can
>   manage every resource *and mint/revoke other tokens*.
> - **Never echo the token back**, in full or in part, in any later message.
> - **Revoke it when the session ends** — treat every token that has touched a
>   chat transcript as exposed.
>
> **If a token is exposed (pasted in the wrong place, shared transcript,
> committed):** revoke it immediately — xCloud dashboard → **Profile → API
> Tokens** → delete it, or via the API: `GET /user/tokens` to find its `uuid`,
> then `DELETE /user/tokens/{tokenUuid}` (the `account` skill; needs a `*`-scope
> token). Then generate a fresh scoped token and update the runtime. Rotate
> routinely, not only after incidents.

## Generating a token

xCloud dashboard → **Profile → API Tokens → Generate New Token** → choose scopes
→ copy immediately (shown once).

## Scopes (Sanctum abilities)

| Scope | Grants |
|---|---|
| `read:sites` | All `GET` under `/sites/*` and `/ssl-certificates/*` |
| `write:sites` | All write methods under `/sites/*` |
| `read:servers` | All `GET` under `/servers/*` |
| `write:servers` | All write methods under `/servers/*` |
| `*` | Full access (incl. token management) |

## Fine-grained authorization

Scopes are coarse; each request also passes a per-resource policy check. A `403`
with a valid token means the user lacks a required team permission (e.g.
`site:manage-ssl` for SSL renewal), not that the token is wrong.

## Verifying auth

```bash
"$SKILL_ROOT/scripts/xcloud.sh" GET /user
```

`401` → token missing/expired/revoked. `403` → scope or team-permission gap.
