---
name: sites
description: Manage xCloud sites — list/inspect sites, status, events, deployment logs, monitoring, backups, rescue, snapshots, domains & redirections, cache purge, SSH/SFTP config, site cron jobs, git, access logs, and site deletion. Use for any site lifecycle or delivery request. For SSL/certs see xcloud:ssl; for WordPress plugins/updates/vulnerabilities/PageSpeed see xcloud:wordpress; for server-level infra see xcloud:servers.
---

# xCloud Sites

Owns site lifecycle and delivery. Read the shared layer first for auth, base
URL, envelope, pagination, and rate limits:

- `references/shared/auth.md`
- `references/shared/conventions.md`
- `references/shared/mcp.md` — **prefer `mcp__xcloud__sites_*`
  tools when connected** (e.g. `sites_index`, `sites_show`, `sites_status`,
  `sites_rescue`, `sites_destroy`); the `$XC` calls below are the REST fallback.

```bash
XC="scripts/xcloud.sh"
```

Scopes: reads need `read:sites`, writes need `write:sites`.

## Response format

Brand every user-facing reply (see `references/shared/conventions.md` →
**Response format**): open with `☁️ **xCloud · Sites** — <site domain>`, give the
trimmed result, and close with a `_via xcloud:sites_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching site \`<domain>\`…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Creating…" or "Polling…". Say `xCloud is creating…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `references/shared/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

| Sub-resource | Reference file |
|---|---|
| Backups (trigger, list, settings, status, count) | `references/domain/backups.md` |
| Domains, redirections, web rules | `references/domain/domains.md` |
| Cache (purge, purge-all, settings) | `references/domain/cache.md` |
| SSH/SFTP config & keys | `references/domain/ssh.md` |
| Site cron jobs | `references/domain/cron-jobs.md` |
| Git deployment settings and manual deploys | `references/domain/git.md` |

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
| Git deployment info | `GET /sites/{uuid}/git` |
| Update Git deployment settings | `PUT /sites/{uuid}/git` |
| Trigger Git deployment | `POST /sites/{uuid}/git/deploy` |
| Snapshots | `GET /sites/{uuid}/snapshots` |
| Staging sites | `GET /sites/{uuid}/staging-sites` |
| Custom nginx / site scripts / IP access | `GET /sites/{uuid}/{custom-nginx,site-scripts,ip-access}` |
| Domain update status | `GET /sites/{uuid}/domain/status` |
| Rescue site | `POST /sites/{uuid}/rescue` |
| **Delete site** | `DELETE /sites/{uuid}` |

**Not here:** SSL → `xcloud:ssl`; WordPress/vulns/pagespeed → `xcloud:wordpress`;
servers → `xcloud:servers`.

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
- Monitoring history is a paid feature — expect `403` on free plans.
