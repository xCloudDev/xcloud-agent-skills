---
name: sites
description: Manage existing xCloud sites — list/inspect sites, status, events, deployment logs, monitoring and uptime history, backups (including Docker app backups and schedules), rescue, snapshots, staging environments, domains & redirections, cache purge, SSH/SFTP config, site cron jobs, access logs, and site deletion. Use for any day-2 site request. A site that errors (500/502, critical error) → xcloud:troubleshoot; a slow site or "is caching on" → xcloud:performance; deploying, redeploying, Git settings and failed-deploy recovery → xcloud:deploy; SSL/certs → xcloud:ssl; WordPress plugins/updates/vulnerabilities/PageSpeed/broken links → xcloud:wordpress; server-level infra → xcloud:servers.
---

# xCloud Sites

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Owns site lifecycle and delivery. Read the shared layer first for auth, base
URL, envelope, pagination, and rate limits:

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/mcp.md` — **prefer `mcp__xcloud__sites_*`
  tools when connected** (e.g. `sites_index`, `sites_show`, `sites_status`,
  `sites_backup`, `sites_docker_backup`, `sites_stagingSites`, `sites_rescue`,
  `sites_destroy`); the `$XC` calls below are the REST fallback.

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
```

Scopes: reads need `read:sites`, writes need `write:sites`.

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · Sites** — <site domain>`, give the
trimmed result, and close with a `_via xcloud:sites_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching site \`<domain>\`…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Creating…" or "Polling…". Say `xCloud is creating…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

| Sub-resource | Reference file |
|---|---|
| Backups (trigger, list, settings, status, count) | `reference/backups.md` |
| Docker app backups (back up now, notes, schedule, retention) | `reference/docker-backups.md` |
| Domains, redirections, web rules | `reference/domains.md` |
| Cache (purge, purge-all, settings) | `reference/cache.md` |
| SSH/SFTP config & keys | `reference/ssh.md` |
| Site cron jobs | `reference/cron-jobs.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| List sites | `GET /sites` |
| Get site | `GET /sites/{uuid}` |
| Status | `GET /sites/{uuid}/status` |
| Events | `GET /sites/{uuid}/events` |
| Deployment logs | `GET /sites/{uuid}/deployment-logs` |
| Monitoring (+ history) | `GET /sites/{uuid}/monitoring[/history]` |
| Access logs | `GET /sites/{uuid}/access-logs` |
| One event's full output | `GET /sites/{uuid}/events/{task_uuid}` |
| Git settings, deploys, diagnosis, retry | owned by `xcloud:deploy` |
| Snapshots | `GET /sites/{uuid}/snapshots` |
| Staging environments (list / create for Git sites) | `GET\|POST /sites/{uuid}/staging-sites` — creating is a deploy (`xcloud:deploy`) |
| Custom nginx / site scripts / IP access | `GET /sites/{uuid}/{custom-nginx,site-scripts,ip-access}` |
| Domain update status | `GET /sites/{uuid}/domain/status` |
| Rescue site | `POST /sites/{uuid}/rescue` |
| **Delete site** | `DELETE /sites/{uuid}` |

**Not here:** a site that errors → `xcloud:troubleshoot`; a slow site →
`xcloud:performance`; deploys → `xcloud:deploy`; SSL → `xcloud:ssl`;
WordPress/vulns/pagespeed/broken links → `xcloud:wordpress`; servers →
`xcloud:servers`.

## Common reads

Find a site by domain (resolve its UUID first):

```bash
"$XC" GET "/sites?search=example.com&per_page=20" \
  | jq '(.data.items // .data.data // []) | map({uuid, name, domain: .domain_name, status, type})'
```

Status + recent events (the go-to triage pair):

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/status" | jq '.data'
"$XC" GET "/sites/$SITE_UUID/events" | jq '(.data.items // .data) | .[0:10]'
```

## Writes

Rescue a broken site (all flags optional booleans; pick the repairs you need —
supported options depend on site type: `repair_node`, `repair_pm2`, and
`repair_openclaw` exist for Node/OpenClaw sites, `reinstall_php` for PHP sites):

```bash
"$XC" POST "/sites/$SITE_UUID/rescue" '{
  "isolate_user": true,
  "regenerate_nginx": true,
  "restart_nginx": true,
  "directory_permissions": true,
  "reinstall_php": false
}' | jq '.message'
```

Delete a site — **destructive and irreversible; never call without explicit
user confirmation naming the exact domain**. The `delete_*` flags choose what
is removed alongside the record; deletion is async (`status` → `deleting`,
staging sites are removed too):

```bash
"$XC" DELETE "/sites/$SITE_UUID" '{
  "delete_files": true,
  "delete_database": true,
  "delete_user": true,
  "delete_local_backups": false,
  "delete_dns_record": false
}' | jq '.message'
# poll: GET /sites/{uuid}/status until the site is gone
```

## Pitfalls

- Many list endpoints differ in pagination shape — use
  `(.data.items // .data.data // [])`.
- Writes are async; confirm via `GET /sites/{uuid}/events`.
- A 502 with status still `provisioned` is usually a missing site OS user — pull
  `/sites/{uuid}/ssh` (`site_user`) and the server tasks to confirm.
- Site deletion requires the `site:delete` team permission; sites tied to their
  server's lifecycle (e.g. OpenClaw) cannot be deleted independently.
- Monitoring history is a paid feature — expect `403` on free plans. It takes a
  `range` query parameter.
- A site whose status looks wrong after a deploy → hand over to `xcloud:deploy`
  (diagnosis and retry on the same site), never delete and recreate it.
