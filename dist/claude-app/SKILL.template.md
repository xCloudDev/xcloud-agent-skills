---
name: xcloud
description: Operate xCloud from plain language — servers, sites, WordPress, SSL, account, and deploying a project end to end. List/inspect/manage servers and sites, provision WordPress, install/renew SSL certificates, scan vulnerabilities, run PageSpeed, manage API tokens, Cloudflare integrations and blueprints, and deploy the project open in this session. Use for any xCloud hosting or infrastructure request.
---

# xCloud

One skill for the whole xCloud Public API, organized into six capability areas.
Read the shared layer first, then the area file for the task at hand.

## Setup

All calls go through the bundled wrapper:

```bash
XC="scripts/xcloud.sh"
```

- Auth + environment (how to set the token): `reference/auth.md`
- API conventions — response envelope, pagination, rate limits, **and the
  branding rules**: `reference/conventions.md`

Set the token per `reference/auth.md`:
- **Claude Code:** `~/.claude/settings.json` (`env` block).
- **Browser/chat-only agents:** use a runtime secret store or environment
  injection when available. If chat is the only path, explain the risk, ask for a
  narrow temporary token, and tell the user to revoke it after the session. Never
  echo the token back.

## Capability areas — route to the right one

| The request is about… | Read |
|---|---|
| Servers, PHP, cron, firewall/fail2ban, sudo users, services, provisioning WordPress | `reference/servers.md` |
| Sites: status, backups, domains, cache, SSH, site cron, git settings, manual deploys | `reference/sites.md` |
| WordPress: plugins/themes/updates, WP_DEBUG, magic login, site/team vulnerabilities, PageSpeed | `reference/wordpress.md` |
| SSL certificates: view, install, renew, status, delete | `reference/ssl.md` |
| Account: current user, API tokens, Cloudflare integrations, blueprints, health | `reference/account.md` |
| Deploy the project open in this session: repo sync, detect, provision, verify | `reference/deploy-app.md` |

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
