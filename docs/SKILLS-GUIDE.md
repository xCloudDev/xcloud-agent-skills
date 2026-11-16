# xCloud Skills — Install & Usage Guide

A step-by-step guide to installing and using the **xCloud Public API skills**
(plugin `xcloud`) inside Claude Code.

The plugin ships **nine skills**, each owning one capability area of the API.
You don't call them directly — you describe what you want in plain language and
Claude picks the right skill automatically.

| Skill | Owns | Typical asks |
|---|---|---|
| `xcloud:deploy` | Deploy a Git repo, Docker Compose app, one-click app, Git staging environment or WordPress site end to end; diagnose and retry failed deploys; redeploys | "deploy github.com/acme/shop", "install Uptime Kuma", "my last deploy failed", "deploy latest commit" |
| `xcloud:troubleshoot` | A site that errors: status, recent events, nginx access and error log, WordPress health, WP_DEBUG, services, temporary shell access | "example.com shows a 500", "my site has a critical error", "why is my site down" |
| `xcloud:performance` | A slow site: site and server monitoring, cache layers, PageSpeed, traffic, the site's PHP version | "my site is slow", "is Redis on for shop.example.com", "why is TTFB so high" |
| `xcloud:servers` | Servers: buy a server, services, Node/PHP versions, verified reboots, cron, firewall/fail2ban, sudo users, DNS checks | "reboot server X", "install Redis", "switch Node to 22", "ban this IP" |
| `xcloud:sites` | Site lifecycle: status, backups (incl. Docker apps), staging, domains, cache, SSH, site cron, monitoring, deletion | "back up example.com", "show site events", "purge the cache" |
| `xcloud:wordpress` | WP plugins/themes/updates, WP_DEBUG, magic login, site/team vulnerabilities, PageSpeed, broken links | "update WooCommerce", "show team vulnerabilities", "find broken links" |
| `xcloud:ssl` | SSL certificates: view, install, renew, status, delete | "renew SSL for example.com", "install a Let's Encrypt cert" |
| `xcloud:billing` | Plan, invoices, bills, prices, paying an invoice, mailboxes and mail delivery | "what plan am I on", "last month's invoice", "buy a mailbox" |
| `xcloud:account` | Current user, teams, incident alerts, API tokens, Git/Cloudflare integrations, blueprints, health | "who am I", "switch to the Acme team", "any unread alerts?" |

---

## 1. Install

### 1.1 Add the marketplace and install the plugin

In Claude Code:

```
/plugin marketplace add xCloudDev/xcloud-agent-skills
/plugin install xcloud
/reload-plugins
```

After reload, confirm the nine skills are present:

```
/plugin
```

You should see `xcloud:deploy`, `xcloud:troubleshoot`, `xcloud:performance`,
`xcloud:servers`, `xcloud:sites`, `xcloud:wordpress`, `xcloud:ssl`,
`xcloud:billing`, and `xcloud:account`.

> Installing v3.0.0 renames the plugin to `xcloud` and shortens the skill IDs to
> `xcloud:servers`, `xcloud:sites`, `xcloud:wordpress`, `xcloud:ssl`, and
> `xcloud:account`. If you previously installed `xcloud-public-api`, reinstall.
> The v1 single skill remains available at the `v1.2.0` git tag if you need it.

---

## 2. Connect your xCloud account

### 2.0 Recommended — the xCloud MCP connector (no token needed)

The fastest, safest connection is the **xCloud MCP server** — browser OAuth, no
secret to store, per-action confirmation on every destructive operation, and
one native tool per authenticated API operation plus two search tools
(`xcloud_agent_search` for jobs, `xcloud_docs_search` for questions) that the
skills use automatically. Clients that cap tool counts (Cursor: 40) use the
compact profile, `https://app.xcloud.host/mcp?profile=compact`:

```bash
claude mcp add xcloud --transport http https://app.xcloud.host/mcp
```

Then run `/mcp` → **Authenticate** and grant **Read** or **Read & write**.
Other clients (Claude Desktop, claude.ai, Cursor): add a custom connector with
URL `https://app.xcloud.host/mcp`. Full instructions:
<https://app.xcloud.host/mcp/docs>.

With the MCP connected you can **skip the token setup below** — it's only
needed for agents without MCP support, and for API-token list/revoke (which is
intentionally REST-only).

### 2.1 REST fallback — API token

Without MCP, every skill needs a Sanctum personal access token. Generate one in
the xCloud dashboard → **Account → Developers → API Tokens → Generate New Token**, choosing
the scopes you need (for example `read:sites` and `read:servers`). Copy it immediately — it's shown only once.

Keep the token out of shell profiles and the chat. Put it in a file only you
can read and load it for the session:

```bash
umask 077; mkdir -p ~/.config/xcloud
${EDITOR:-nano} ~/.config/xcloud/token   # paste the token, save
chmod 600 ~/.config/xcloud/token
XCLOUD_API_TOKEN="$(cat ~/.config/xcloud/token)" claude
```

A secret store works too. Choose the narrowest abilities, not `*`.

If the token is missing, the xCloud skills should proactively guide you through
this setup and then verify with `/health` and `/user`. Do not paste long-lived
production tokens into chat by default; use a runtime env var, settings file, or
secret store whenever possible.

---

## 3. Choose live or local

The skills default to the live host. Switch environments with **one env var** —
no code change:

```bash
# Live (default — you can leave this unset)
export XCLOUD_API_BASE_URL="https://app.xcloud.host"

# Local development (plaintext http needs the explicit override)
export XCLOUD_API_BASE_URL="http://xcloud.test"
export XCLOUD_ALLOW_INSECURE_HTTP=1
```

---

## 4. How to use the skills

Just talk to Claude. The skill descriptions are written so Claude routes your
request to the right one. Examples of what to type:

- "List my xCloud servers."
- "Renew the SSL certificate for shop.example.com."
- "Update all plugins on example.com, backing up first."
- "Scan example.com for vulnerabilities and show critical findings."
- "Purge the cache on example.com."

Claude resolves UUIDs for you (it lists sites/servers first), runs the call
through the shared wrapper, and returns a trimmed summary.

### Verify everything works

Ask Claude: **"Check my xCloud API connection."** It will run the equivalent of:

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
"$XC" GET /health   # {"status":"ok","version":"v1"}
"$XC" GET /user     # confirms the token
```

`401` → token missing/expired. `403` → token lacks a scope or team permission.

---

## 5. What each skill covers

Each skill lives in `plugins/xcloud/skills/<name>/SKILL.md`, with its own
`reference/` pages for the long topics. Ask in plain words; the router picks
the skill. Every change shows a preview or a confirmation first, naming the
site or server it will touch, and nothing is changed until you say yes.

| Skill | Ask it to |
|---|---|
| `xcloud:servers` | List servers, check services, firewall, PHP, cron, databases, sudo users, reboot |
| `xcloud:sites` | Inspect sites, backups and restores, cache, domains, redirects, SSH/SFTP, cron |
| `xcloud:wordpress` | Plugins, themes, vulnerabilities, PageSpeed, broken links, debug mode |
| `xcloud:ssl` | Check, install and renew certificates |
| `xcloud:account` | Teams, token hygiene, and what a connection may do |
| `xcloud:deploy` | Deploy a Git repository or one-click app, staging, WordPress sites |
| `xcloud:billing` | Plan, invoices, mailboxes and mail delivery |
| `xcloud:troubleshoot` | Find out why a site shows a 500 or is down, evidence first |
| `xcloud:performance` | Find out why a site is slow |

What xCloud can and cannot do changes with each release, so the skills ask
`xcloud_agent_search` instead of repeating a list. The generated tables in
[the capability map](../plugins/xcloud/reference/capability-map.md) show what
was checked, and against which xCloud version.

Task-first examples (health audit, safe WordPress update, go-live) are in the
[user guide](./USER_GUIDE.md).

---

## 7. How requests get routed (and avoiding surprises)

Skills are organized by **capability**, which sometimes differs from where the
endpoint lives in the URL. A few rules to keep in mind:

- **SSL** is always `xcloud:ssl`, even though certs hang off `/sites/...`.
- **WordPress updates, vulnerabilities, and PageSpeed** are `xcloud:wordpress`,
  even for the site-level paths.
- **Firewall and fail2ban** are `xcloud:servers` (server security), not a
  separate security skill.
- **Cron** exists on both servers and sites — say "server cron" or "site cron"
  if it's ambiguous.
- **Creating anything that runs code** — a Git site, Docker app, one-click app,
  staging environment or WordPress site — and fixing a failed deploy is
  `xcloud:deploy`, even though the create URLs live under `/servers/...`.
- **Money** (plans, invoices, add-on purchases) is `xcloud:billing`; buying a
  server itself is `xcloud:servers`.

If Claude picks the wrong skill, name it explicitly: *"Using xcloud:ssl, renew
the cert for example.com."*

---

## 8. Running the smoke tests (optional)

Each skill ships a read-only smoke test. To run one against your local
environment:

```bash
export CLAUDE_PLUGIN_ROOT="$PWD/plugins/xcloud"
export XCLOUD_API_BASE_URL="http://xcloud.test"
export XCLOUD_ALLOW_INSECURE_HTTP=1   # plaintext http is refused without this
export XCLOUD_API_TOKEN="your-token"
export XCLOUD_TEST_SITE_UUID="<a-real-site-uuid>"
export XCLOUD_TEST_SERVER_UUID="<a-real-server-uuid>"

bash plugins/xcloud/skills/sites/tests/smoke.sh
```

The tests never mutate anything: they perform `GET` requests, plus the deploy
suite's side-effect-free repository detection (`POST /git/detect`).

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `XCLOUD_API_TOKEN is not set` | No token in env | Set it (section 2) |
| `401` on any call | Token missing/expired/revoked | Regenerate the token |
| `403` with a valid token | Missing scope or team permission (e.g. `site:manage-ssl`) | Grant the scope/permission |
| `429` | Rate limit (60/min auth) | Wait for `Retry-After` |
| Wrong skill triggered | Ambiguous phrasing | Name the skill explicitly |
| Calls hit the wrong host | `XCLOUD_API_BASE_URL` set unexpectedly | Unset for live, or point at `xcloud.test` for local |

---

## Reference

- Shared auth details: `plugins/xcloud/reference/auth.md`
- Shared API conventions: `plugins/xcloud/reference/conventions.md`
- Architecture rationale: `docs/adr/0001-capability-domain-skills.md`
- Glossary: `CONTEXT.md`
- Full API docs: `https://app.xcloud.host/api/v1/docs`
