---
name: xcloud
description: Operate xCloud from plain language — deploy any GitHub/GitLab repo, Docker Compose app, one-click app or WordPress site end to end (detect, dry run, approve, provision, verify, auto-diagnose and retry failures), diagnose a site that errors or is slow, and manage servers, sites, WordPress, SSL, billing, add-ons, teams and alerts. Use for any xCloud hosting, deployment, or infrastructure request, or whenever the user pastes a repository URL and asks to host it.
---

# xCloud

One skill for the whole xCloud Public API, organized into nine capability areas.
Read the shared layer first, then the area file for the task at hand.

## Setup

All calls go through the bundled wrapper:

```bash
XC="scripts/xcloud.sh"
```

- Auth + environment (how to set the token): `reference/auth.md`
- API conventions — response envelope, pagination, rate limits, **and the
  branding rules**: `reference/conventions.md`
- What is dashboard-only or impossible, with dashboard paths:
  `reference/capability-map.md`

Set the token per `reference/auth.md`:
- **Claude Code:** `~/.claude/settings.json` (`env` block).
- **Browser/chat-only agents:** use MCP or a runtime secret store. Never request credentials in chat. If neither is available, stop authenticated work.

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


## Capability areas — route to the right one

| The request is about… | Read |
|---|---|
| **Deploy**: a GitHub/GitLab URL, Docker Compose app, one-click app, staging from a branch, new WordPress site, failed-deploy recovery, redeploys | `reference/deploy.md` |
| **Troubleshoot**: a site returning 500/502/503, a critical error, a site that is down or erroring | `reference/troubleshoot.md` |
| **Performance**: a slow site, high TTFB, "is Redis on", caching for a site, a per-site PHP version | `reference/performance.md` |
| Servers: buy a server, plans, services, Node/PHP, verified reboots, cron, firewall/fail2ban, sudo users, DNS checks | `reference/servers.md` |
| Sites: status, backups (incl. Docker apps), staging, domains, cache, SSH, site cron, monitoring, deletion | `reference/sites.md` |
| WordPress: plugins/themes/updates, WP_DEBUG, magic login, vulnerabilities, PageSpeed, broken links | `reference/wordpress.md` |
| SSL certificates: view, install, renew, status, delete | `reference/ssl.md` |
| Billing: plan, invoices, prices, paying an invoice, mailboxes and mail delivery | `reference/billing.md` |
| Account: current user, teams, incident alerts, API tokens, Git and Cloudflare integrations, blueprints, health | `reference/account.md` |

Each area file lists its endpoints, scopes, examples, and pitfalls, and points to
deeper sub-resource files (named `reference/<area>-<topic>.md`, e.g.
`reference/servers-firewall.md`).

## Branding (apply to every reply)

Follow `reference/conventions.md`:
- **Startup banner** — once, on the first xcloud reply per conversation.
- **Progress narration** — one `☁️ …` line before each API call. **Every progress
  line and every action sentence must start with `xCloud` as the actor — never a
  bare verb like "Creating…" or "Polling…". Say `xCloud is creating…`,
  `xCloud is polling…`.** This is how the user sees xCloud working behind the scene.
- **Response format** — a `☁️ **xCloud · <Area>** — <resource>` header and a
  `_via xcloud:<area>_` footer.

## Verify the connection

```bash
"$XC" GET /health   # {"status":"ok","version":"v1"}
"$XC" GET /user     # confirms the token
```

`401` → token missing/expired. `403` → scope or team-permission gap (or, on the
claude.ai app, a blocked outbound host — see reference/auth.md).
