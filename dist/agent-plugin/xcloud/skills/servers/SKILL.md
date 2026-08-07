---
name: servers
description: Manage xCloud servers — list/inspect servers, monitoring, services, tasks, reboot, snapshots, sudo users, PHP versions, databases & database users, server cron jobs, firewall rules, fail2ban, and provisioning new sites onto a server (WordPress or Git-deployed PHP/Node apps). Use for any server-level infrastructure or server security (firewall/fail2ban) request. NOT site-level config (see xcloud:sites), NOT SSL certs (see xcloud:ssl), NOT WordPress app management (see xcloud:wordpress).
---

# xCloud Servers

Owns server infrastructure and server-level security. Read the shared layer
first for auth, base URL, envelope, pagination, and rate limits:

- `references/shared/auth.md`
- `references/shared/conventions.md`
- `references/shared/mcp.md` — **prefer `mcp__xcloud__servers_*`
  tools when connected** (e.g. `servers_index`, `servers_show`, `servers_reboot`,
  `servers_sites_wordpress_create`, `servers_sites_git_create`); the `$XC` calls
  below are the REST fallback.

```bash
XC="scripts/xcloud.sh"
```

Scopes: reads need `read:servers`, writes need `write:servers`.

## Response format

Brand every user-facing reply (see `references/shared/conventions.md` →
**Response format**): open with `☁️ **xCloud · Servers** — <server>`, give the
trimmed result, and close with a `_via xcloud:servers_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching server \`<name>\`…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Creating…" or "Provisioning…". Say `xCloud is creating…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `references/shared/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

Big domain — detailed per-sub-resource guidance lives in `reference/`:

| Sub-resource | Reference file |
|---|---|
| PHP versions (install, default, opcache, patch) | `references/domain/php-versions.md` |
| Server cron jobs (CRUD, execute, output) | `references/domain/cron-jobs.md` |
| Databases & database users ⚠️ _(404 on the current API — see file)_ | `references/domain/databases.md` |
| Firewall rules, fail2ban, IP whitelisting | `references/domain/firewall.md` |
| Sudo users | `references/domain/sudo-users.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| List servers | `GET /servers` |
| Get server | `GET /servers/{uuid}` |
| List sites on server | `GET /servers/{uuid}/sites` |
| Monitoring (+ history) | `GET /servers/{uuid}/monitoring[/history]` |
| Services | `GET /servers/{uuid}/services` |
| Restart a service | `POST /servers/{uuid}/services/restart` |
| Disable a service | `POST /servers/{uuid}/services/disable` |
| Recent tasks | `GET /servers/{uuid}/tasks` |
| Snapshots | `GET /servers/{uuid}/snapshots` |
| Supervisor processes | `GET /servers/{uuid}/supervisor-processes` |
| Reboot server | `POST /servers/{uuid}/reboot` |
| Create WordPress site on server | `POST /servers/{uuid}/sites/wordpress` |
| **Create Git-deployed site on server** | `POST /servers/{uuid}/sites/git` |

**Not here:** site settings → `xcloud:sites`; SSL → `xcloud:ssl`; WordPress
plugins/themes/updates → `xcloud:wordpress`.

## Common reads

List servers:

```bash
"$XC" GET "/servers?per_page=100" \
  | jq '(.data.items // .data.data // []) | map({uuid, name, status, ip: (.ip_address // .ip)})'
```

One server + its monitoring:

```bash
SERVER_UUID='replace-me'
"$XC" GET "/servers/$SERVER_UUID" | jq '.data'
"$XC" GET "/servers/$SERVER_UUID/monitoring" | jq '.data'
```

Recent tasks (use after any async write to confirm progress):

```bash
"$XC" GET "/servers/$SERVER_UUID/tasks" | jq '(.data.items // .data) | map({uuid, type, status, created_at})'
```

## Common writes

Reboot (async — poll tasks afterward):

```bash
"$XC" POST "/servers/$SERVER_UUID/reboot" | jq '.message'
```

Restart a service:

```bash
"$XC" POST "/servers/$SERVER_UUID/services/restart" '{"service":"nginx"}' | jq '.message'
```

Disable a service (synchronous; can take a service offline):

```bash
"$XC" POST "/servers/$SERVER_UUID/services/disable" '{"service":"redis"}' | jq '.message'
```

Before disabling, xCloud must confirm the exact server, service name, and impact
with the user. Accepted `service` values include `mysql`, `mariadb`,
`postgresql`, `nginx`, `redis`, `php`, `ssh`, `supervisor`, `docker`, `lsws`,
`nodejs`, `openclaw`, `paperclip`, and `hermes`. For PHP services, pass
`version` when the server has multiple PHP versions.

Create a WordPress site on the server (live mode needs `domain` + `ssl`; omit
`domain` for demo). `blueprint_uuid` and `snapshot_uuid` are mutually exclusive;
auto-generated credentials are returned only once.

```bash
"$XC" POST "/servers/$SERVER_UUID/sites/wordpress" '{
  "mode": "live",
  "domain": "example.com",
  "title": "My Site",
  "php_version": "8.2",
  "ssl": {"provider": "letsencrypt"},
  "cache": {"full_page": true, "object_cache": true}
}' | jq '.data'
# then poll site provisioning:  GET /sites/{new_uuid}/status   (xcloud:sites)
```

Create a **Git-deployed site** — `site_type` is one of `laravel`, `nodejs`,
`custom-php`, `wordpress`, `lovable`. Atomic: if any step fails, no partial site
is left behind. Repository source is EITHER a connected provider
(`repository.provider_uuid` + `repository.full_name` — required for private
repos) OR a public HTTPS `repository.url`; private `git@…` SSH URLs are
rejected. `domain.mode` is `live` or `staging`; Node `ssr`/`hybrid` apps also
need `start_command` + `port`:

```bash
"$XC" POST "/servers/$SERVER_UUID/sites/git" '{
  "site_type": "custom-php",
  "repository": {"url": "https://github.com/acme/app.git", "branch": "main"},
  "domain": {"mode": "live", "name": "app.example.com", "ssl_provider": "xcloud"},
  "enable_push_deploy": false
}' | jq '.data'
# then manage deploys via xcloud:sites (reference/git.md):
#   PUT /sites/{uuid}/git · POST /sites/{uuid}/git/deploy
```

## Pitfalls

- Server writes are async; success is returned before work completes — poll
  `GET /servers/{uuid}/tasks`.
- Disabling `ssh`, `nginx`, database, runtime, agent, or queue services can cause
  lockout or downtime. Require explicit confirmation immediately before calling
  `POST /servers/{uuid}/services/disable`.
- Site creation (WordPress and Git) lives here (the URL is `/servers/...`), but
  the resulting site is then managed via `xcloud:sites` / `xcloud:wordpress`.
- `setting default PHP` and `patching PHP` do not enforce a `write:servers`
  scope line in the docs but still require server write permission in practice.
