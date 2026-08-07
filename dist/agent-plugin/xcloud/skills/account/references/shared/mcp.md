# xCloud MCP (shared)

Shared by every `xcloud:*` domain skill. The **xCloud MCP server** exposes every
authenticated Public API operation as a native MCP tool — **110 tools, full
parity** with the REST surface (only `/health` and API-token management remain
REST-only; see below).

- **Endpoint:** `https://app.xcloud.host/mcp` (Streamable HTTP)
- **Docs:** <https://app.xcloud.host/mcp/docs>

## Transport preference (the rule)

> **If `mcp__xcloud__*` tools are available in this session, use them —
> do not shell out to `scripts/xcloud.sh` for operations the MCP covers.**
> Fall back to the REST wrapper only when (a) the MCP server is not connected,
> or (b) the operation is REST-only (`/health`, `GET /user/tokens`,
> `DELETE /user/tokens/{tokenUuid}`).

Why MCP first: typed parameters (no hand-built JSON), a built-in
confirm-before-destructive contract, team-scoped OAuth instead of a raw token in
the environment, and `dashboard_url` links on every server/site.

## Tool naming

Tool names mirror the endpoint path — segments joined by `_`, CRUD verbs as
suffixes (`_create`, `_update`, `_destroy`, `_show`, `_index`):

| REST operation | MCP tool |
|---|---|
| `GET /servers` | `servers_index` |
| `GET /servers/{uuid}` | `servers_show` |
| `POST /servers/{uuid}/reboot` | `servers_reboot` |
| `POST /servers/{uuid}/sites/wordpress` | `servers_sites_wordpress_create` |
| `GET /sites/{uuid}/ssl` | `sites_ssl` |
| `POST /sites/{uuid}/ssl/renew` | `sites_ssl_renew` |
| `DELETE /sites/{uuid}` | `sites_destroy` |
| `GET /vulnerabilities` | `vulnerabilities_index` |
| `GET /user` | `user_show` |

Every tool description embeds its REST path, so the endpoint tables in each
skill map 1:1 to tool names.

## Destructive-tool contract

Every destructive MCP tool requires `confirm: true`, to be set **only after
the human has explicitly approved that specific action**. Describe what will
happen (target resource by name, effect, blast radius), get approval, then call
with `confirm: true`. This is enforced by the server-side tool schema — an
unconfirmed destructive call is rejected. The skills' own guardrails (read
first, restate the target, poll async completion) still apply.

## Connecting (tell the user, per client)

**Claude Code:**

```bash
claude mcp add xcloud --transport http https://app.xcloud.host/mcp
```

Then `/mcp` → **Authenticate** (browser OAuth). Grant **Read** (`mcp:read`) or
**Read & write** (`mcp:write`).

**Claude Desktop / claude.ai:** Settings → **Connectors** → **Add custom
connector** → name `xcloud`, URL `https://app.xcloud.host/mcp` → sign in.

**Cursor** (`~/.cursor/mcp.json`) and other HTTP-capable clients:

```json
{ "mcpServers": { "xcloud": { "url": "https://app.xcloud.host/mcp" } } }
```

**No browser / headless:** use an API token that carries the `mcp:invoke` scope
(plus the granular `read:`/`write:` scopes needed):

```bash
claude mcp add xcloud --transport http https://app.xcloud.host/mcp \
  --header 'Authorization: Bearer YOUR_TOKEN'
```

stdio-only clients can bridge with `npx mcp-remote`.

Access is team-scoped. Every MCP connection appears in the dashboard's API key
management for revocation. Verify with *"who am I on xCloud?"* (`user_show`).

## REST-only operations

The MCP does **not** expose these — always use `scripts/xcloud.sh` for them:

| Operation | Method + path | Why |
|---|---|---|
| API health | `GET /health` | unauthenticated probe |
| List API tokens | `GET /user/tokens` | token management stays out of MCP |
| Revoke a token | `DELETE /user/tokens/{tokenUuid}` | token management stays out of MCP |

## Errors

- `401` → OAuth session expired or invalid API key → reconnect/authenticate.
- `403` → approval declined, read-only grant used for a write, or a missing
  team permission (e.g. `site:manage-ssl`) — same fine-grained policy as REST.
- "Lacks the … ability" → the API-key connection is missing a scope.

## dashboard_url

Servers and sites returned by MCP tools carry a `dashboard_url` that opens that
exact resource in the xCloud dashboard. Surface it in replies when useful —
never construct dashboard URLs by hand.
