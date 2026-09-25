---
name: servers
description: Manage xCloud servers — list/inspect servers, buy a new xCloud-managed server (plans, prices, regions, provisioning progress), monitoring, services (install, enable, restart, disable), Node.js and PHP versions, verified reboots, tasks, snapshots, sudo users, server cron jobs, firewall rules, fail2ban, IP whitelisting, and checking whether a domain's DNS points at a server. Use for any server-level infrastructure, capacity, or server security request. Deploying apps and creating sites on a server → xcloud:deploy. NOT site-level config (see xcloud:sites), NOT SSL certs (see xcloud:ssl), NOT WordPress app management (see xcloud:wordpress).
---

# xCloud Servers

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Owns server infrastructure and server-level security. Read the shared layer
first for auth, base URL, envelope, pagination, and rate limits:

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/mcp.md` — **prefer `mcp__xcloud__servers_*`
  tools when connected** (e.g. `servers_index`, `servers_show`,
  `servers_plans`, `servers_store`, `servers_reboots_store`,
  `servers_services_install`, `servers_dns_check`); the `$XC` calls below are
  the REST fallback.

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
```

Scopes: reads need `read:servers`, writes need `write:servers`.

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · Servers** — <server>`, give the
trimmed result, and close with a `_via xcloud:servers_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching server \`<name>\`…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Creating…" or "Provisioning…". Say `xCloud is creating…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

Big domain — detailed per-sub-resource guidance lives in `reference/`:

| Sub-resource | Reference file |
|---|---|
| Buying a server: plans, prices, regions, provisioning progress | `reference/provisioning.md` |
| PHP versions (install, default, opcache, patch) | `reference/php-versions.md` |
| Server cron jobs (CRUD, execute, output) | `reference/cron-jobs.md` |
| Databases & database users ⚠️ _(404 on the current API — see file)_ | `reference/databases.md` |
| Firewall rules, fail2ban, IP whitelisting | `reference/firewall.md` |
| Sudo users | `reference/sudo-users.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| List servers | `GET /servers` |
| Get server | `GET /servers/{uuid}` |
| **Buy a new server** (billable) | `POST /servers` — see `reference/provisioning.md` |
| Plans this team can buy | `GET /servers/plans` |
| Provisioning progress | `GET /servers/{uuid}/provisioning-progress` |
| List sites on server | `GET /servers/{uuid}/sites` |
| Monitoring (+ history) | `GET /servers/{uuid}/monitoring[/history]` |
| Services | `GET /servers/{uuid}/services` |
| Install / enable / restart / disable a service | `POST /servers/{uuid}/services/{install,enable,restart,disable}` |
| Node.js versions (read, change default) | `GET /servers/{uuid}/node-versions` · `POST /servers/{uuid}/node-versions/{version}/default` |
| Recent tasks | `GET /servers/{uuid}/tasks` |
| Snapshots | `GET /servers/{uuid}/snapshots` |
| Supervisor processes | `GET /servers/{uuid}/supervisor-processes` |
| **Verified reboot** (preferred) | `POST /servers/{uuid}/reboots` → `GET /servers/{uuid}/reboots/{operationUuid}` |
| Recheck an unconfirmed reboot | `POST /servers/{uuid}/reboots/{operationUuid}/check` |
| Reboot (legacy, fire-and-forget) | `POST /servers/{uuid}/reboot` |
| Does a domain resolve to this server? | `POST /servers/{server}/dns/check` |
| Create sites on this server (WordPress, Git, Docker, one-click) | owned by `xcloud:deploy` |
| Staging hostname a create would mint | `GET /servers/{uuid}/staging-hostname?label=…` |
| Deploy keys for private repositories | `GET /servers/{uuid}/git/deploy-keys` · `POST /servers/{uuid}/git/deploy-keys` |

**Not here:** creating and deploying sites → `xcloud:deploy`; site settings →
`xcloud:sites`; SSL → `xcloud:ssl`; WordPress plugins/themes/updates →
`xcloud:wordpress`; invoices and prices → `xcloud:billing`.

## Common reads

List servers:

```bash
"$XC" GET "/servers?per_page=100" \
  | jq '(.data.items // .data.data // []) | map({uuid, name, status, status_readable, stack, ip: (.ip_address // .ip)})'
```

One server + its monitoring:

```bash
SERVER_UUID='replace-me'
"$XC" GET "/servers/$SERVER_UUID" | jq '.data'
"$XC" GET "/servers/$SERVER_UUID/monitoring" | jq '.data'
```

Fleet check ("flag any server above 80% disk"): list servers, read each one's
monitoring, and report one line per server. `status_readable` values such as
*Low disk space* or *Reboot Required* are worth surfacing on their own.

Recent tasks (use after any async write to confirm progress):

```bash
"$XC" GET "/servers/$SERVER_UUID/tasks" | jq '(.data.items // .data) | map({uuid, type, status, created_at})'
```

Is `shop.example.com` pointing at this server yet?

```bash
jq -n --arg d "shop.example.com" '{domain:$d}' \
  | "$XC" POST "/servers/$SERVER_UUID/dns/check" - | jq '.data'
```

It makes one lookup per call — poll while a record propagates. A record behind
Cloudflare's proxy is reported separately (`cloudflare_proxy: true`); relay
`next_actions`. On a site xCloud manages through Cloudflare
(`cloudflare_managed: true`) the proxied record is the finished state — never
tell the user to turn the proxy off there.

## Common writes

Verified reboot — records one reboot operation, then confirms the machine came
back with a new boot identity (a repeat while one is unresolved returns the same
operation instead of rebooting twice):

```bash
OP=$("$XC" POST "/servers/$SERVER_UUID/reboots" | jq -r '.data.uuid')
"$XC" GET "/servers/$SERVER_UUID/reboots/$OP" | jq '.data'
```

Install and enable a service (e.g. Redis), then restart one:

```bash
"$XC" POST "/servers/$SERVER_UUID/services/install" '{"service":"redis"}' | jq '.message'
"$XC" POST "/servers/$SERVER_UUID/services/enable"  '{"service":"redis"}' | jq '.message'
"$XC" POST "/servers/$SERVER_UUID/services/restart" '{"service":"nginx"}' | jq '.message'
```

Disable a service (synchronous; can take a service offline):

```bash
"$XC" POST "/servers/$SERVER_UUID/services/disable" '{"service":"redis"}' | jq '.message'
```

Before any service change, xCloud must confirm the exact server, service name,
and impact with the user. Accepted `service` values include `mysql`, `mariadb`,
`postgresql`, `nginx`, `redis`, `php`, `ssh`, `supervisor`, `docker`, `lsws`,
`nodejs`, `openclaw`, `paperclip`, `hermes`, and `deepseek_harness`. For PHP
services, pass `version` when the server has multiple PHP versions.

Change the server's default Node.js (affects **every** Node site on the server —
say so before asking):

```bash
"$XC" GET  "/servers/$SERVER_UUID/node-versions" | jq '.data'
"$XC" POST "/servers/$SERVER_UUID/node-versions/22/default" | jq '.message'
```

Sites are created on a server through `xcloud:deploy` (Git repositories, Docker
Compose apps, WordPress, one-click apps): it runs the detection, dry-run preview,
approval, polling, and failure recovery.

## Pitfalls

- Server writes are async; success is returned before work completes — poll
  `GET /servers/{uuid}/tasks` (or the reboot operation / provisioning progress).
- Disabling `ssh`, `nginx`, database, runtime, agent, or queue services can cause
  lockout or downtime. Require explicit confirmation immediately before calling
  `POST /servers/{uuid}/services/disable`.
- `POST /servers` buys a server and charges the team's default card — never
  without an approved plan, region and price (`reference/provisioning.md`).
  Connecting a server from the user's own cloud account is dashboard-only.
- Agentic servers (OpenClaw, Paperclip, Hermes, DeepSeek Harness) host only the
  site created with them; Docker servers cannot host WordPress.
- `setting default PHP` and `patching PHP` do not enforce a `write:servers`
  scope line in the docs but still require server write permission in practice.
