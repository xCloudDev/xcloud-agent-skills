# xCloud Skills — Install & Usage Guide

A step-by-step guide to installing and using the **xCloud Public API skills**
(plugin `xcloud` v4.2.0) inside Claude Code.

The plugin ships **six skills**, each owning one capability area of the API.
You don't call them directly — you describe what you want in plain language and
Claude picks the right skill automatically.

| Skill | Owns | Typical asks |
|---|---|---|
| `xcloud:servers` | Servers, PHP, databases, cron, firewall/fail2ban, sudo users, services, WordPress provisioning | "reboot server X", "install PHP 8.3", "disable Redis", "ban this IP" |
| `xcloud:sites` | Site lifecycle: status, backups, domains, cache, SSH, site cron, git settings, manual deploys | "back up example.com", "deploy latest commit", "show site events" |
| `xcloud:wordpress` | WP plugins/themes/updates, WP_DEBUG, magic login, site/team vulnerabilities, PageSpeed | "update WooCommerce", "show team vulnerabilities", "PageSpeed score" |
| `xcloud:ssl` | SSL certificates: view, install, renew, status, delete | "renew SSL for example.com", "install a Let's Encrypt cert" |
| `xcloud:account` | Current user, API tokens, Cloudflare integrations, blueprints, health | "who am I", "list my API tokens", "list blueprints" |
| `xcloud:deploy-app` | Deploy the project open in this session end to end: repo sync, detection, provisioning, verification | "deploy this project to xCloud", "deploy my app" |

---

## 1. Install

### 1.1 Add the marketplace and install the plugin

In Claude Code:

```
/plugin marketplace add xCloudDev/xcloud-agent-skills
/plugin install xcloud
/reload-plugins
```

After reload, confirm the six skills are present:

```
/plugin
```

You should see `xcloud:servers`, `xcloud:sites`, `xcloud:wordpress`,
`xcloud:ssl`, `xcloud:account`, and `xcloud:deploy-app`.

> Installing v3.0.0 renames the plugin to `xcloud` and shortens the skill IDs to
> `xcloud:servers`, `xcloud:sites`, `xcloud:wordpress`, `xcloud:ssl`, and
> `xcloud:account`. If you previously installed `xcloud-public-api`, reinstall.
> The v1 single skill remains available at the `v1.2.0` git tag if you need it.
> v4.1.0 adds the sixth skill, `xcloud:deploy-app`.

---

## 2. Connect your xCloud account

### 2.0 Recommended — the xCloud MCP connector (no token needed)

The fastest, safest connection is the **xCloud MCP server** — browser OAuth, no
secret to store, per-action confirmation on every destructive operation, and
110 native tools the skills use automatically:

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
the xCloud dashboard → **Profile → API Tokens → Generate New Token**, choosing
the scopes you need (`read:sites`, `write:sites`, `read:servers`,
`write:servers`, or `*`). Copy it immediately — it's shown only once.

Pick **one** persistent option:

**Option A — Claude Code settings (recommended):**
```json
// ~/.claude/settings.json
{ "env": { "XCLOUD_API_TOKEN": "your-token-here" } }
```

**Option B — shell profile:**
```bash
echo "export XCLOUD_API_TOKEN='your-token-here'" >> ~/.zshrc && source ~/.zshrc
```

**Option C — inline, one session only (not persistent):**
```bash
XCLOUD_API_TOKEN=... <command>
```

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

## 5. Use cases per skill (with small examples)

Each example shows the **prompt** you'd give Claude and the **call** the skill
makes under the hood (`$XC` = the shared wrapper, `$SITE`/`$SRV` = a resolved UUID).

### 5.1 `xcloud:servers`

Server infrastructure and server-level security.

**Reboot a server**
> "Reboot my Hermes server."
```bash
"$XC" POST "/servers/$SRV/reboot"
# then poll: "$XC" GET "/servers/$SRV/tasks"
```

**Install and default a PHP version**
> "Install PHP 8.3 on that server and make it the default."
```bash
"$XC" POST "/servers/$SRV/php-versions" '{"php_version":"8.3"}'
"$XC" POST "/servers/$SRV/php-versions/8.3/default"
```

**Ban an abusive IP (fail2ban)**
> "Ban 203.0.113.7 on server X."
```bash
"$XC" POST "/servers/$SRV/fail2ban/banned-ips" '{"ip_addresses":["203.0.113.7"]}'
```

**Disable a service**
> "Disable Redis on server X."
```bash
"$XC" POST "/servers/$SRV/services/disable" '{"service":"redis"}'
```
Require explicit confirmation first; disabling services can cause downtime or
lockout.

**Create a database + user** ⚠️ *not available on the current public API — these
endpoints return 404 today (see `docs/API-COVERAGE.md`); shown as a
forward-looking example only*
> "Create a database app_prod with a user on server X."
```bash
"$XC" POST "/servers/$SRV/databases" '{"database_name":"app_prod"}'
jq -n --arg pw "$DB_PASSWORD" '{username:"app_user",password:$pw,databases:["app_prod"]}' \
  | "$XC" POST "/servers/$SRV/database-users" -
```

### 5.2 `xcloud:sites`

Site lifecycle and delivery.

**Back up a site**
> "Back up example.com before I deploy."
```bash
"$XC" POST "/sites/$SITE/backup" '{"label":"pre-deploy"}'
"$XC" GET  "/sites/$SITE/backup-status"
```

**Triage a down site**
> "example.com is throwing 502 — what's going on?"
```bash
"$XC" GET "/sites/$SITE/status"
"$XC" GET "/sites/$SITE/events"
"$XC" GET "/sites/$SITE/ssh"     # check site_user for a missing OS user
```

**Purge cache**
> "Clear the cache on example.com."
```bash
"$XC" POST "/sites/$SITE/cache/purge-all"
```

**Trigger a Git deployment**
> "Deploy the latest Git commit for example.com."
```bash
"$XC" POST "/sites/$SITE/git/deploy"
# then poll deployment logs/events
```

**Update Git deployment settings**
> "Set example.com to deploy from the main branch and enable push deploy."
```bash
"$XC" PUT "/sites/$SITE/git" '{"git_branch":"main","enable_push_deploy":true}'
```

**Switch SSH to key auth**
> "Set example.com SSH to public-key auth with my key."
```bash
"$XC" PUT "/sites/$SITE/ssh" '{"authentication_mode":"public_key","ssh_public_keys":["ssh-ed25519 AAAA..."]}'
```

### 5.3 `xcloud:wordpress`

WordPress app management, vulnerabilities, PageSpeed.

**Update specific plugins, with a backup first**
> "Update WooCommerce and Akismet on example.com, back up first."
```bash
"$XC" POST "/sites/$SITE/wordpress/update" '{"type":"plugin","slugs":["woocommerce","akismet"],"backup_before_update":true}'
```

**Run a vulnerability scan and review**
> "Scan example.com for vulnerabilities and show me the critical ones."
```bash
"$XC" POST "/sites/$SITE/vulnerability-scan"
"$XC" GET  "/sites/$SITE/vulnerabilities/count"
"$XC" GET  "/sites/$SITE/vulnerabilities"
```

**Check performance**
> "What's the PageSpeed score for example.com?"
```bash
"$XC" POST "/sites/$SITE/pagespeed/scan"
"$XC" GET  "/sites/$SITE/pagespeed"
```

**One-time admin login**
> "Give me a magic login link for example.com."
```bash
"$XC" POST "/sites/$SITE/magic-login" '{"login_as":"admin"}'
```

### 5.4 `xcloud:ssl`

SSL certificates and HTTPS.

**Install a Let's Encrypt certificate**
> "Set up HTTPS for newsite.example.com with Let's Encrypt."
```bash
"$XC" POST "/sites/$SITE/ssl-certificates" '{"provider":"xcloud"}'
```

**Renew before expiry**
> "Renew the SSL cert for example.com."
```bash
"$XC" POST "/sites/$SITE/ssl/renew" '{}'            # only fires if within 7 days
"$XC" POST "/sites/$SITE/ssl/renew" '{"force":true}' # force now
```

**Check cert status**
> "Is example.com's certificate valid?"
```bash
"$XC" GET "/sites/$SITE/ssl"
```

### 5.5 `xcloud:account`

Identity and org-level reads.

**Who am I / which team**
> "Who am I on xCloud?"
```bash
"$XC" GET /user
```

**List and revoke tokens** (needs `*` scope)
> "List my API tokens and revoke token 123."
```bash
"$XC" GET /user/tokens
"$XC" DELETE /user/tokens/123
```

**List blueprints** (before creating a WordPress site)
> "Show me my WordPress blueprints."
```bash
"$XC" GET "/blueprints?per_page=100"
```

### 5.6 `xcloud:deploy-app`

Deploys the project open in the current session, end to end. See
`plugins/xcloud/skills/deploy-app/SKILL.md` for the full flow (repo sync gate →
secrets check → detect → confirm → provision → poll → verify).

**Deploy the current project**
> "Deploy this project to xCloud."
```bash
# 1. repo sync gate (see reference/repo-sync.md) — commits/pushes with approval
# 2. preview, no mutation:
"$XC" POST "/git/detect" '{"repository_url": "https://github.com/acme/app.git", "server_uuid": "'"$SRV"'"}'
# 3. after confirmation:
"$XC" POST "/servers/$SRV/sites/git/auto" '{
  "repository": {"url": "https://github.com/acme/app.git", "branch": "main"},
  "confirm": true
}'
# then poll: "$XC" GET "/sites/$NEW_SITE_UUID/status"
```

---

## 6. Real-world workflows (how users actually use it)

The examples above are single calls. In practice a user drives Claude through a
whole task in plain language, and Claude chains the skills for them. Three common
end-to-end flows:

### 6.1 Monday-morning health audit

> "Audit example.com: is it up, is SSL healthy, any vulnerabilities, and how's
> performance?"

Claude resolves the site UUID once, then fans out across **three** skills:

```bash
# xcloud:sites  — is it alive?
"$XC" GET "/sites/$SITE/status"
# xcloud:ssl    — cert valid / expiring?
"$XC" GET "/sites/$SITE/ssl"
# xcloud:wordpress — security + speed
"$XC" POST "/sites/$SITE/vulnerability-scan"
"$XC" GET  "/sites/$SITE/vulnerabilities/count"
"$XC" POST "/sites/$SITE/pagespeed/scan"
"$XC" GET  "/sites/$SITE/pagespeed"
```

You get one consolidated summary: uptime, days-to-cert-expiry, critical CVE
count, PageSpeed score — without naming a single endpoint.

### 6.2 Safe WordPress update

> "WooCommerce has an update — apply it to example.com but back up first and
> tell me if anything looks off."

```bash
# 1. snapshot first (xcloud:sites)
"$XC" POST "/sites/$SITE/backup" '{"label":"pre-woo-update"}'
"$XC" GET  "/sites/$SITE/backup-status"          # wait for "completed"
# 2. update with built-in pre-update backup (xcloud:wordpress)
"$XC" POST "/sites/$SITE/wordpress/update" \
  '{"type":"plugin","slugs":["woocommerce"],"backup_before_update":true}'
# 3. confirm the site still serves (xcloud:sites)
"$XC" GET "/sites/$SITE/status"
```

If status comes back unhealthy, Claude surfaces it immediately and you can ask
it to restore the snapshot — one prompt, two skills, a rollback path.

### 6.3 New site go-live

> "I just provisioned shop.example.com — set up HTTPS and confirm it's serving."

```bash
# 1. install Let's Encrypt cert (xcloud:ssl)
"$XC" POST "/sites/$SITE/ssl-certificates" '{"provider":"xcloud"}'
"$XC" GET  "/sites/$SITE/ssl"                    # wait for issued/active
# 2. verify delivery (xcloud:sites)
"$XC" GET "/sites/$SITE/status"
# 3. baseline performance (xcloud:wordpress)
"$XC" POST "/sites/$SITE/pagespeed/scan"
```

The point: users think in **tasks** ("go live", "audit", "update safely"), not
endpoints. The skills are sliced so one task maps cleanly onto one short
conversation.

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
- **"Deploy this project"** (an uncommitted/local app, not yet a live xCloud
  site) is `xcloud:deploy-app`. **"Deploy the latest commit"** for a site that
  already exists on xCloud is `xcloud:sites` (`POST /sites/{uuid}/git/deploy`).

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

The tests never mutate anything. Every suite but one only performs `GET`
requests; `xcloud:deploy-app`'s suite also calls `POST /git/detect`, which is
side-effect-free repository analysis (it creates nothing), so it's safe to run
the same way:

```bash
bash plugins/xcloud/skills/deploy-app/tests/smoke.sh
```

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
