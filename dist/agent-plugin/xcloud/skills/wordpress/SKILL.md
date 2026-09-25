---
name: wordpress
description: Manage WordPress on xCloud sites — list/update/activate plugins and themes, check WordPress health and update summaries, toggle WP_DEBUG, generate magic-login URLs, run vulnerability scans and manage findings (per site and team-wide), run PageSpeed Insights scans, and scan for broken links. Use for WordPress app management, "which sites need updates", security scans, PageSpeed scores, or broken links. Why a site is slow → performance; a site throwing errors → troubleshoot. For SSL see ssl; for site backups/domains/cache see sites; for server infra see servers.
---

# xCloud WordPress

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Owns WordPress app management plus site vulnerability scanning, PageSpeed, and
broken-link scans.
Read the shared layer first for auth, base URL, and conventions:

- `references/shared/auth.md`
- `references/shared/conventions.md`
- `references/shared/mcp.md` — **prefer the MCP tools when
  connected**: `sites_wordpress_*` (plugins/themes/updates/status/update/
  activate/refresh), `sites_vulnerabilities_*`, `vulnerabilities_index`
  (team-wide), `sites_pagespeed_*`, `sites_broken-links_*`, `sites_wp-debug`,
  `sites_magic-login`;
  the `$XC` calls below are the REST fallback.

Resolve the absolute directory that contains this `SKILL.md` before running
shell commands. Do not resolve scripts from the user's current working directory:

```bash
SKILL_ROOT="/absolute/path/to/this/skill"
XC="$SKILL_ROOT/scripts/xcloud.sh"
```

Scopes: reads need `read:sites`, writes need `write:sites`.

## Response format

Brand every user-facing reply (see `references/shared/conventions.md` →
**Response format**): open with `☁️ **xCloud · WordPress** — <site domain>`, give
the trimmed result, and close with a `_via xCloud/wordpress_` line.

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
| Broken links (scan, poll, findings) | `references/domain/broken-links.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| WP health status | `GET /sites/{uuid}/wordpress/status` |
| Updates summary | `GET /sites/{uuid}/wordpress/updates` |
| Toggle WP_DEBUG | `POST /sites/{uuid}/wp-debug` |
| Magic login URL | `POST /sites/{uuid}/magic-login` |

**Not here:** SSL → the `ssl` skill; backups/domains/cache/SSH → the `sites` skill;
server infra → the `servers` skill.

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

## Fleet questions

"Which of my sites have pending core, plugin or theme updates?" → list sites
(the `sites` skill), keep the WordPress ones, read each one's updates summary, and
answer grouped by site with counts; offer to update the ones the user picks
(back up first — `references/domain/plugins-themes.md`). For vulnerabilities across the
team, `GET /vulnerabilities` answers in one call — sort worst first.

## Cross-domain note

`vulnerabilities` and `pagespeed` are addressed at `/sites/{uuid}/…` and work on
any site, but are owned here because they are predominantly WordPress concerns.
A non-WordPress "scan my site" request still routes here via the `sites` skill
cross-link.

## Pitfalls

- Plugin/theme updates and activations are async and can optionally back up
  first — see `references/domain/plugins-themes.md`.
- Magic-login URLs are single-use and expire after about ten minutes; treat them
  like passwords, never log them. The first call on a site installs the
  magic-login plugin over SSH, which is why it is confirm-gated on MCP.
