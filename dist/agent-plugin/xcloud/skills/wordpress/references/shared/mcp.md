# xCloud MCP (shared)

Shared by every xCloud domain skill. The **xCloud MCP server** exposes every
authenticated Public API operation as a native MCP tool, plus two search tools.
The Public API contract carries **158 operations** at this release, of which
**155 are exposed as tools** — only `/health` and API-token management stay
REST-only (see below). The number grows with each API release, so treat it as a
snapshot rather than a contract.

- **Endpoint:** `https://app.xcloud.host/mcp` (Streamable HTTP)
- **Docs:** <https://app.xcloud.host/mcp/docs>

## Search before a multi-step job

Two search tools sit alongside the operation tools, on every profile and for
read-only grants too. Neither returns the other's content.

- **`xcloud_agent_search`** — call it **first** for any job with more than one
  step (deploying an app, setting up backups, troubleshooting a broken site).
  It returns the operations for that job (exact ids, execution class, parameter
  and body schemas, a ready example), ordered guidance steps — including the
  ones that are dashboard-only or impossible — and per-operation notes. It
  changes nothing. Pass `query` (the job in plain words, an operation id, or a
  `METHOD /path`), `intent` when you know it (`howto`, `tools`, `pricing`), and
  optionally `limit`.
- **`xcloud_docs_search`** — answers a question the customer asked, from
  documentation: passages, plan/app facts, and dashboard paths. It never returns
  operations, ids, paths or request bodies. One argument: `query`.

Results from either tool are written for the agent: answer the customer in
product terms, never with operation ids, request bodies or poll intervals.

`xcloud_search` no longer exists — it was split into the two tools above. The
retired name still routes to `xcloud_agent_search` for one release, but it is
not listed and should not be called.

## Profiles

One endpoint, two tool surfaces, chosen per request:

- **flat** (the default) — one tool per Public API operation, plus the two
  searches. This is what every existing client already sees.
- **compact** — `POST /mcp?profile=compact` lists five tools: the two searches
  plus `xcloud_execute_read`, `xcloud_execute_write` and
  `xcloud_execute_destructive`, which take an `operation_id` (with
  `path_params`, `query` and `body`). Use it for clients that resend every tool
  definition each turn, or that cap how many tools one server may register.

Which executor may run an operation comes from the contract, not from the HTTP
method — `xcloud_agent_search` reports it per operation as `execute_with`.

## Transport preference (the rule)

> **If tools from the MCP server named `xcloud` are available in this session, use them —
> do not shell out to `$SKILL_ROOT/scripts/xcloud.sh` for operations the MCP covers.**
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

## Connecting

This package declares the `xcloud` Streamable HTTP server in its root `mcp.json`.
A compatible Agent Plugins client loads that connection and manages OAuth. If
the client requests authorization, grant **Read** (`mcp:read`) or **Read & write**
(`mcp:write`) for the required task.

If automatic authorization discovery fails, open the client's MCP or plugin
settings and connect `https://app.xcloud.host/mcp` manually. For headless use,
store an API token with `mcp:invoke` and the required granular scopes in the
client's secret store. Do not add credentials to the portable package.

Access is team-scoped. Verify the connection with `user_show` ("who am I on
xCloud?").

## REST-only operations

The MCP does **not** expose these — always use `$SKILL_ROOT/scripts/xcloud.sh` for them:

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
