---
name: wordpress
description: Manage WordPress on xCloud sites — list/update/activate plugins and themes, check WordPress health and update summaries, toggle WP_DEBUG, generate magic-login URLs, run vulnerability scans and manage findings, and run PageSpeed Insights scans. Use for WordPress app management, security scans, or site performance. For SSL see xcloud:ssl; for site backups/domains/cache see xcloud:sites; for server infra see xcloud:servers.
---

# xCloud WordPress

Owns WordPress app management plus site vulnerability scanning and PageSpeed.
Read the shared layer first for auth, base URL, and conventions:

- `references/shared/auth.md`
- `references/shared/conventions.md`
- `references/shared/mcp.md` — **prefer the MCP tools when
  connected**: `sites_wordpress_*` (plugins/themes/updates/status/update/
  activate/refresh), `sites_vulnerabilities_*`, `vulnerabilities_index`
  (team-wide), `sites_pagespeed_*`, `sites_wp-debug`, `sites_magic-login`;
  the `$XC` calls below are the REST fallback.

```bash
XC="scripts/xcloud.sh"
```

Scopes: reads need `read:sites`, writes need `write:sites`.

## Response format

Brand every user-facing reply (see `references/shared/conventions.md` →
**Response format**): open with `☁️ **xCloud · WordPress** — <site domain>`, give
the trimmed result, and close with a `_via xcloud:wordpress_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is scanning \`<domain>\` for
vulnerabilities…`; the first call of a task opens with
`☁️ xCloud is starting a session…`. **Every progress line and every action
sentence must start with `xCloud` as the actor — never a bare verb like
"Scanning…" or "Updating…". Say `xCloud is scanning…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `references/shared/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

| Sub-resource | Reference file |
|---|---|
| Plugins, themes, updates, activate, refresh | `references/domain/plugins-themes.md` |
| Vulnerabilities (scan, list, ignore) | `references/domain/vulnerabilities.md` |
| PageSpeed Insights | `references/domain/pagespeed.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| WP health status | `GET /sites/{uuid}/wordpress/status` |
| Updates summary | `GET /sites/{uuid}/wordpress/updates` |
| Toggle WP_DEBUG | `POST /sites/{uuid}/wp-debug` |
| Magic login URL | `POST /sites/{uuid}/magic-login` |

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

## Cross-domain note

`vulnerabilities` and `pagespeed` are addressed at `/sites/{uuid}/…` and work on
any site, but are owned here because they are predominantly WordPress concerns.
A non-WordPress "scan my site" request still routes here via the `xcloud:sites`
cross-link.

## Pitfalls

- Plugin/theme updates and activations are async and can optionally back up
  first — see `references/domain/plugins-themes.md`.
- Magic-login URLs are single-use and short-lived; never log them.
