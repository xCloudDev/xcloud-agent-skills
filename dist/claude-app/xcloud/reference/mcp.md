# xCloud MCP (shared)

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Shared by every `xcloud:*` domain skill. The **xCloud MCP server** exposes every
authenticated Public API operation as a native MCP tool, plus two search tools.
On 2026-09-24 the default profile listed **190 tools: 188 operation tools and
the two searches**, against 199 operations in the live OpenAPI. The count grows
with each API release — treat it as a snapshot, never as a contract. The 11
operations without a tool are `/health`, API-token management, and the xCloud
mobile app's own sign-in and push-notification endpoints (see below).

- **Endpoint:** `https://app.xcloud.host/mcp` (Streamable HTTP)
- **Docs:** <https://app.xcloud.host/mcp/docs>

## Search before a multi-step job

Two search tools sit alongside the operation tools, on every profile and for
read-only grants too. Neither returns the other's content.

- **`xcloud_agent_search`** — call it **first** for any job with more than one
  step (deploying an app, setting up backups, a broken site, buying or
  connecting a server), whenever you do not know the exact operation id, and
  when a call returns a 403 or 422 you cannot explain. It returns the
  operations for that job (ids, execution class, `execute_with`, parameter and
  body schemas, a ready example), ordered `guidance` steps — including the ones
  that are dashboard-only (`ui`) or impossible — and per-operation `notes`. It
  changes nothing. Arguments: `query` (the job in plain words, an operation id,
  or a `METHOD /path`), optional `intent` (`howto`, `tools`, `pricing`) and
  `limit`.
- **`xcloud_docs_search`** — answers a question the customer asked, from
  documentation: passages, plan and app facts, dashboard paths. It never
  returns operations, ids, paths or request bodies. One argument: `query`.

One search answers a whole job: every operation a guidance card's steps name
comes back in the same response with its request body, so do not search again
per step. `notes` are constraints (what the platform refuses, what a field
really means on that call) — read them before sending the request; most
describe a 422 you can avoid.

Results from either tool are written for the agent. Answer the customer in
product terms, never with operation ids, request bodies or poll intervals.

`xcloud_search` no longer exists — it was split into the two tools above. The
retired name still routes to `xcloud_agent_search` for one release, but it is
not listed and must not be called.

## Profiles: one endpoint, two tool surfaces

There is no "v2 product". `/mcp` is the address; a *profile* decides which
tool surface answers on it:

- **flat** (default) — one tool per Public API operation, plus the two
  searches. Tool names mirror the endpoint path (below). What every existing
  client already sees.
- **compact** — `POST /mcp?profile=compact` lists five tools: the two searches
  plus `xcloud_execute_read`, `xcloud_execute_write` and
  `xcloud_execute_destructive`. Each takes an `operation_id` (canonical, dotted:
  `sites.status`, `servers.sites.git.auto`) with `path_params`, `query` and
  `body`; the write and destructive executors also take `idempotency_key`, and
  the destructive one `confirm`. Use it for clients that resend every tool
  definition each turn, or that cap how many tools one server may register
  (Cursor stops at 40).

Which executor may run an operation comes from the contract, not the HTTP
method — `xcloud_agent_search` reports it per operation as `execute_with`.
The wrong executor refuses and names the right one. Arguments are validated
against the contract before anything runs: an unknown field, a value outside an
enum, or a missing required field is refused before the confirm step, with the
allowed values named.

A misspelled profile is refused with `400 unknown_profile` rather than served
the default. A token can be pinned to the compact profile with the
`mcp:profile:compact` ability; the request wins over the token. `/mcp/v2`
remains registered as an alias for the compact profile — a client configured
against it keeps working.

### Toolsets: narrowing the flat list

The flat profile can also be narrowed to parts of xCloud. A toolset is the
operation's first OpenAPI tag, lower-kebab-cased: `servers`, `sites`,
`sites-wordpress`, `wordpress-actions`, `ssl-certificates`, `vulnerabilities`,
`pagespeed`, `broken-links`, `oneclick-apps`, `billing`, `payments`, `alerts`,
`integrations`, `user`, `catalog`, `blueprints`, `addons-mailbox`,
`addons-mail-delivery`. Two inputs, both optional: a token carrying
`mcp:toolset:<name>` abilities is limited to those toolsets, and
`POST /mcp?toolsets=sites,servers` narrows one session. When both are set they
intersect. The two searches are always listed. An unknown toolset name is
ignored, not refused — check the tool count. Narrowing changes what is
*advertised*, not what is authorized: every call is still checked against the
token's abilities and team.

## Transport preference (the rule)

> **If `mcp__xcloud__*` tools are available in this session, use them —
> do not shell out to `scripts/xcloud.sh` for operations the MCP covers.**
> Fall back to the REST wrapper only when (a) the MCP server is not connected,
> or (b) the operation is REST-only (`/health`, `GET /user/tokens`,
> `DELETE /user/tokens/{tokenUuid}`).

Why MCP first: typed parameters, contract validation before the call, a
built-in confirm-before-destructive gate, team-scoped OAuth instead of a raw
token in the environment, `dashboard_url` links on every server and site, and
the two searches.

## Tool naming (flat profile)

Tool names mirror the endpoint path — segments joined by `_`, CRUD verbs as
suffixes (`_create`, `_update`, `_destroy`, `_show`, `_index`):

| REST operation | Operation id | MCP tool |
|---|---|---|
| `GET /servers` | `servers.index` | `servers_index` |
| `POST /servers/{uuid}/reboot` | `servers.reboot` | `servers_reboot` |
| `POST /servers/{uuid}/sites/git/auto` | `servers.sites.git.auto` | `servers_sites_git_auto` |
| `POST /git/detect` | `git.detect` | `git_detect` |
| `GET /sites/{uuid}/status` | `sites.status` | `sites_status` |
| `GET /sites/{uuid}/deploy-diagnosis` | `sites.deploy-diagnosis` | `sites_deploy-diagnosis` |
| `POST /sites/{uuid}/provision-retry` | `sites.provision-retry` | `sites_provision-retry` |
| `POST /sites/{uuid}/ssl/renew` | `sites.ssl.renew` | `sites_ssl_renew` |
| `DELETE /sites/{uuid}` | `sites.destroy` | `sites_destroy` |

Every tool description embeds its REST path and operation id, so the endpoint
tables in each skill map 1:1 to tool names on the flat profile and to
`operation_id` on the compact one.

## Execution classes and the destructive contract

Every operation is **read**, **write** or **destructive**, derived from the
specification rather than the HTTP method: a `GET` is never destructive, a
side-effect-free `POST` the spec scopes as read (`git.detect`,
`git.compose-scan`, `servers.dns.check`) is read, a mutating operation the spec
marks `x-destructive: false` (`sites.backup`, `sites.cache.purge`, the
deploy-key preparation calls, `sites.deploy-config.update`, …) is write, and
everything else is destructive.

Every destructive tool requires `confirm: true`, to be set **only after the
human has explicitly approved that specific action**, immediately before the
call, naming the resource and the effect. `confirm` is a server-side gate, not
evidence of approval. Describe what will happen (target by name, effect, cost
when it provisions something billable), get the yes, then call. A batch the
human pre-authorised covers exactly the scope they named.

Two more habits the server rewards:

- **Preview before provisioning.** The four site-creation operations
  (`servers.sites.git.auto`, `servers.sites.git.create`,
  `servers.sites.git.docker`, `servers.sites.wordpress.create`) accept
  `dry_run: true`: every check the real call runs, then a stop before persist —
  `200` with `data.dry_run: true`, `data.would_create` and `warnings`, or the
  exact 4xx the real call would give. It needs no `confirm`. Show
  `would_create`, get the yes on that, then send the **same** body without
  `dry_run` and with `confirm: true`.
- **Idempotency.** `servers.store`, the four site creates, `oneclickApps.install`
  and `sites.provision-retry` accept an `Idempotency-Key` header (the
  `idempotency_key` argument on the compact executors). Send one so a retry
  after a timeout cannot do the work twice.

## Which team a call runs against

A token or OAuth grant is created with a default team and may be granted more.
Every call runs against exactly one team: the default when nothing is selected,
or the team uuid passed as the `team` argument (every flat tool except
`teams_index` carries it; the compact executors take it next to `path_params`).
Call `teams_index` first — a team the token was not granted is refused with
`403 "Team not found or not granted to this token"`, never silently replaced by
the default. On REST the same selector is the `X-Team-Id` header, which the
wrapper sends when `XCLOUD_TEAM_ID` is set.

**Turning on multi-team for an existing connection.** Grants are chosen when the
connection is authorized, so an older single-team connection keeps working
unchanged but only ever sees its one team. To manage several teams from one
connection, the user re-authorizes it (disconnect and connect again, or remove
and re-add it) and ticks every team on the xCloud approval screen; API tokens
get the same team picker when they are created. If `teams_index` returns one
team while the user talks about another, say this once, then continue with the
connection that has the team. Docs:
<https://xcloud.host/docs/multi-team-api-tokens-and-mcp-access/>

## Connecting (tell the user, per client)

**Claude Code:**

```bash
claude mcp add xcloud --transport http https://app.xcloud.host/mcp
```

Then `/mcp` → **Authenticate** (browser OAuth). Grant **Read** (`mcp:read`) or
**Read & write** (`mcp:write`). For the compact profile add
`?profile=compact` to the URL.

**Claude Desktop / claude.ai:** Settings → **Connectors** → **Add custom
connector** → name `xcloud`, URL `https://app.xcloud.host/mcp` → sign in.

**Cursor** (`~/.cursor/mcp.json`) — Cursor caps a server at 40 tools, so use
the compact profile or a toolset:

```json
{ "mcpServers": { "xcloud": { "url": "https://app.xcloud.host/mcp?profile=compact" } } }
```

**No browser / headless:** use an API token that carries the literal
`mcp:invoke` ability plus the granular `read:`/`write:` scopes it will need (a
wildcard token does **not** imply `mcp:invoke`):

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

Eight more operations have no tool and are **not for agents at all**: the xCloud
mobile app's sign-in (`/auth/config`, `/auth/token`, `/auth/session`) and its
push-notification registration (`/notifications/…`). Incident alerts themselves
are available to agents through `alerts_index`, `alerts_show` and `alerts_read`.

## Accepted is not finished

Most writes are asynchronous: a success response means xCloud accepted the
work. Poll the read endpoint the operation names (`sites.status`,
`servers.tasks`, `oneclickApps.status`) every ten seconds, or after
`poll_after_seconds` when the response carries one, until `terminal` is true —
then branch on `deploy_state`, never on prose status fields. A percentage that
sits still for a minute during a package install is not a stall. If you must
stop before the terminal state, say the work is still running and hand over the
`poll_url`; do not call it done.

## Errors

- `401` → OAuth session expired or invalid API key → reconnect/authenticate.
- `403` at connection time → the credential lacks an MCP permission; on one
  tool → the token lacks that ability or the team policy permission (e.g.
  `site:manage-ssl`), or the team was not granted.
- `409` → work already running on that resource (a second deploy or retry);
  poll instead of retrying.
- `422` → the body failed validation; the message names the field and, for a
  closed set, the allowed values. Fix the body — do not retry it unchanged.
- "Lacks the … ability" → the API-key connection is missing a scope.
- "Tool … not found" on the compact profile → wrong executor for that
  operation's class; the error names the right one.

## dashboard_url

Servers and sites returned by MCP tools carry a `dashboard_url` that opens that
exact resource in the xCloud dashboard. Surface it in replies when useful —
never construct dashboard URLs by hand.
