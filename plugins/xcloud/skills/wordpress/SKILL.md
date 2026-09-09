---
name: wordpress
description: Manage WordPress on xCloud sites — list/update/activate plugins and themes, check WordPress health and update summaries, toggle WP_DEBUG, generate magic-login URLs, run vulnerability scans and manage findings, run broken-link scans, and run PageSpeed Insights scans. Use for WordPress app management, security scans, or site performance. For SSL see xcloud:ssl; for site backups/domains/cache see xcloud:sites; for server infra see xcloud:servers.
---

# xCloud WordPress

Owns WordPress app management plus site vulnerability scanning and PageSpeed.
Read the shared layer first for auth, base URL, and conventions:

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/capabilities.md` — **what is API-covered,
  what is dashboard-only, and what xCloud refuses outright**; read it before
  planning a multi-step job.
- `${CLAUDE_PLUGIN_ROOT}/reference/mcp.md` — **prefer the MCP tools when
  connected**: `sites_wordpress_*` (plugins/themes/updates/status/update/
  activate/refresh), `sites_vulnerabilities_*`, `vulnerabilities_index`
  (team-wide), `sites_pagespeed_*`, `sites_wp-debug`, `sites_magic-login`;
  the `$XC` calls below are the REST fallback.

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
```

Scopes: reads need `read:sites`, writes need `write:sites`.

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · WordPress** — <site domain>`, give
the trimmed result, and close with a `_via xcloud:wordpress_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is scanning \`<domain>\` for
vulnerabilities…`; the first call of a task opens with
`☁️ xCloud is starting a session…`. **Every progress line and every action
sentence must start with `xCloud` as the actor — never a bare verb like
"Scanning…" or "Updating…". Say `xCloud is scanning…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

| Sub-resource | Reference file |
|---|---|
| Plugins, themes, updates, activate, refresh | `reference/plugins-themes.md` |
| Vulnerabilities (scan, list, ignore) | `reference/vulnerabilities.md` |
| PageSpeed Insights | `reference/pagespeed.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| WP health status | `GET /sites/{uuid}/wordpress/status` |
| Updates summary | `GET /sites/{uuid}/wordpress/updates` |
| Toggle WP_DEBUG | `POST /sites/{uuid}/wp-debug` |
| Magic login URL | `POST /sites/{uuid}/magic-login` |
| Broken-link scan status + open findings | `GET /sites/{uuid}/broken-links` |
| One broken-link finding | `GET /sites/{uuid}/broken-links/{brokenLinkFindingUuid}` |
| Start a broken-link scan | `POST /sites/{uuid}/broken-links/scan` |

**Not here:** SSL → `xcloud:ssl`; backups/domains/cache/SSH → `xcloud:sites`;
server infra → `xcloud:servers`.

## Examples

WordPress health + pending updates:

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/wordpress/status"  | jq '.data'
"$XC" GET "/sites/$SITE_UUID/wordpress/updates" | jq '.data'
```

Toggle WP_DEBUG (`enabled` required):

```bash
"$XC" POST "/sites/$SITE_UUID/wp-debug" '{"enabled":true}' | jq '.message'
```

Generate a one-time admin magic-login URL:

```bash
"$XC" POST "/sites/$SITE_UUID/magic-login" '{"login_as":"admin"}' | jq -r '.data.url // .data'
```

## Broken links

`sites_broken-links_*` scans a WordPress site for dead links. Reads need
`read:sites` plus the `site:manage-broken-links` team permission. Read the
message on a failure before concluding anything: a `403` is either that missing
permission **or** "Broken link monitoring is not available on the free plan",
and a `422` means the site type cannot be scanned.

```bash
"$XC" POST "/sites/$SITE_UUID/broken-links/scan" '{}' | jq '.message'
"$XC" GET  "/sites/$SITE_UUID/broken-links" | jq '.data | {status, enabled, frequency, last_scan_at, broken_links_count, findings: (.findings | map({uuid, source_url, destination_url, http_status, severity}))}'
```

The scan is async. `status` is one of `idle`, `queued`, `running`, `completed`,
`failed`, `cancelled` — keep polling through `queued` **and** `running`, stop on
`completed`, `failed` or `cancelled`, and report which one. A site that has
never been scanned reports `idle`. Triggering a scan
auto-creates broken-link monitoring for the site (frequency `manual`) the first
time it is accepted, so say so before running one.

## Cross-domain note

`vulnerabilities` and `pagespeed` are addressed at `/sites/{uuid}/…` and work on
any site, but are owned here because they are predominantly WordPress concerns.
A non-WordPress "scan my site" request still routes here via the `xcloud:sites`
cross-link.

## Pitfalls

- Plugin/theme updates and activations are async and can optionally back up
  first — see `reference/plugins-themes.md`.
- Magic-login URLs are single-use and short-lived; never log them.
