# xCloud MCP (shared)

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Shared by every `xcloud:*` domain skill. The **xCloud MCP server** exposes the
authenticated Public API operations as MCP tools, plus the search tools and
`report_friction`. Never hard-code a tool count or a tool name: use the names
your session lists.

<!-- facts:mcp-counts:start -->
xCloud v2.9.18 has 323 public API operations. 12 of them have no MCP tool (health, API-token management, native-app sign-in, notifications, one CSV download).
<!-- facts:mcp-counts:end -->

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

## Profiles: one endpoint, two tool surfaces

`/mcp` is the address; a *profile* decides which tool surface answers on it.
The default profile today is the **flat** one; the **unified** surface is
becoming the default in a coming release. Write instructions so they hold on
either: name **operation ids** (`sites.ssl.renew`), never flat tool names
(`sites_ssl_renew`), and run an operation with the tool your connection offers,
which is the per-operation tool on the flat profile and `execute` on the
unified one.

<!-- facts:mcp-profiles:start -->
| Profile | What it lists |
|---|---|
| `/mcp` (flat, default) | One tool per operation (about 310), the dashboard-action tools (about 227) and `xcloud_agent_search`, `xcloud_docs_search`, `report_friction`. A read-only grant lists far fewer (about 159 operation tools) and hides write tools. |
| `/mcp?profile=unified` (unified; aliases `compact`, `/mcp/v2`) | 3 tools: `search`, `execute`, `docs`. Every operation runs through `execute`. |
| `/mcp/openai` (read-only) | 39 read tools for chat clients that only look. |
<!-- facts:mcp-profiles:end -->

**Unified surface (`search`, `execute`, `docs`).** `search` finds the operation
and returns the guidance for the job; `docs` reads xCloud's documentation;
`execute {operation, params}` runs it. A write or delete is a two-step call:
the first `execute` returns a **preview** (what would change, with a
`fingerprint`); show it to the user, and only after their yes call `execute`
again with `confirm: true` and that `fingerprint`. A call that returns
`accepted: true` has only been queued, so poll the status operation until it
finishes. On the flat profile the same rule is `confirm: true` on the
destructive tools.

**Read-only connections.** A connection granted Read only lists read tools;
write tools are hidden, not refused. When a write tool is missing, say "this
connection is read-only; reconnect with Read & write", not "that is not
possible".

**Rate limits.** <!-- facts:mcp-limits:start -->
MCP calls are limited to 120 per minute and 1,200 per hour for each credential.
<!-- facts:mcp-limits:end --> A looping client runs out of its own budget, so
batch reads and do not poll faster than the job's poll interval.

**Feedback.** `report_friction` (listed on every profile) sends a short note to
the xCloud team when a tool or an answer got in the way. Use it for a
confusing refusal, a missing operation or a wrong tool description; never put
secrets or customer data in it.

A misspelled profile is refused with `400 unknown_profile`. A token can be
pinned to a profile with the `mcp:profile:unified` (or `mcp:profile:compact`)
ability; the request wins over the token.

### Toolsets: narrowing the flat list

The flat profile can be narrowed to parts of xCloud. A toolset is the
operation's first OpenAPI tag, lower-kebab-cased:
<!-- facts:mcp-toolsets:start -->
`addons-mail-delivery`, `addons-mailbox`, `alerts`, `billing`, `blueprints`, `broken-links`, `catalog`, `database-cleanup`, `email-logs`, `integrations`, `oneclick-apps`, `pagespeed`, `payments`, `servers`, `sites`, `sites-wordpress`, `ssl-certificates`, `team`, `user`, `vulnerabilities`, `wordpress`, `wordpress-actions`
<!-- facts:mcp-toolsets:end -->
Two inputs, both optional: a token carrying `mcp:toolset:<name>` abilities is
limited to those toolsets, and `POST /mcp?toolsets=sites,servers` narrows one
session. When both are set they intersect. The search tools are always listed.
An unknown toolset name is ignored, not refused. Narrowing changes what is
*advertised*, not what is authorized: every call is still checked against the
token's abilities and team.

Every tool description embeds its REST path and operation id, so the endpoint
tables in each skill map 1:1 to tool names on the flat profile and to
the operation id on the unified one.

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
  `idempotency_key` argument on the unified surface). Send one so a retry
  after a timeout cannot do the work twice.

## Which team a call runs against

A token or OAuth grant is created with a default team and may be granted more.
Every call runs against exactly one team: the default when nothing is selected,
or the team uuid passed as the `team` argument (every flat tool except
`teams_index` carries it; `execute` takes it next to the other params).
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
**Read & write** (`mcp:write`). For the unified surface add
`?profile=unified` to the URL.

**Claude Desktop / claude.ai:** Settings → **Connectors** → **Add custom
connector** → name `xcloud`, URL `https://app.xcloud.host/mcp` → sign in.

**Cursor** (`~/.cursor/mcp.json`) — Cursor caps a server at 40 tools, so use
the unified profile or a toolset:

```json
{ "mcpServers": { "xcloud": { "url": "https://app.xcloud.host/mcp?profile=unified" } } }
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

Some operations have no MCP tool:

<!-- facts:mcp-excluded:start -->
`health.check`, `user.tokens.index`, `user.tokens.revoke`, `auth.config`, `auth.token`, `auth.session`, `notifications.config`, `notifications.installations.show`, `notifications.installations.store`, `notifications.installations.destroy`, `notifications.installations.alerts.show`, `email-logs.exports.download`
<!-- facts:mcp-excluded:end -->

API-token listing and revoking (`user.tokens.index`, `user.tokens.revoke`) stay
on REST and need the `read:tokens` / `write:tokens` abilities, not a full
access token. The native-app sign-in and push endpoints are not for agents.
Incident alerts are available through `alerts.index`, `alerts.show` and
`alerts.read`.

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
