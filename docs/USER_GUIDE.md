# xCloud Skills — User Guide

A friendly, task-first guide to using the **xCloud skills** in Claude Code. You
won't write any code or remember any endpoints — you describe what you want, and
Claude does it.

> Looking for full install options, per-skill call reference, smoke tests, and
> the routing rules? See [SKILLS-GUIDE.md](./SKILLS-GUIDE.md). This page is the
> short, practical "how do I actually use it" version.

---

## What you get

Six skills, each owning one area. You never name them — Claude picks the right
one from what you ask.

| If you want to… | Just say something like | Skill |
|---|---|---|
| Manage servers, PHP, databases, services, firewall | "reboot my Hermes server" | `xcloud:servers` |
| Work with a site: backups, cache, domains, SSH, Git deploys | "deploy the latest commit for example.com" | `xcloud:sites` |
| Update WordPress, scan vulnerabilities, check speed | "show team-wide critical vulnerabilities" | `xcloud:wordpress` |
| Set up or renew HTTPS | "renew SSL for example.com" | `xcloud:ssl` |
| Check who you are, tokens, blueprints | "list my API tokens" | `xcloud:account` |
| Deploy the project open in this session, end to end | "deploy this project to xCloud" | `xcloud:deploy-app` |

---

## Quick start (one time)

1. **Connect your account** — the xCloud MCP connector (recommended; browser
   sign-in, no token to copy):
   ```
   claude mcp add xcloud --transport http https://app.xcloud.host/mcp
   ```
   Then run `/mcp` → **Authenticate** and sign in. (On Claude Desktop or
   claude.ai: Settings → Connectors → Add custom connector →
   `https://app.xcloud.host/mcp`.)

2. **Install the skills** in Claude Code:
   ```
   /plugin marketplace add xCloudDev/xcloud-agent-skills
   /plugin install xcloud
   /reload-plugins
   ```

3. **Check it works.** Ask Claude: **"Check my xCloud API connection."**
   Green light = you're ready.

**No MCP support in your agent?** Use an API token instead: xCloud dashboard →
**Profile → API Tokens → Generate New Token** (copy it once), then add to
`~/.claude/settings.json`:
```json
{ "env": { "XCLOUD_API_TOKEN": "your-token-here" } }
```
Restart Claude Code so it picks up the token. If Claude says no connection is
configured, it should offer the MCP connector first, then guide you through
token setup. Avoid pasting long-lived production tokens directly into chat; use
a temporary, scoped token if chat is the only available path.

That's it. Everything below is just talking to Claude.

---

## How to talk to it

Use plain language. Name the site or server by its domain or name — Claude looks
up the IDs for you.

- "List my xCloud servers."
- "Is example.com up right now?"
- "Renew the SSL certificate for shop.example.com."
- "Update all plugins on example.com, but back up first."
- "Scan example.com for vulnerabilities and show me the critical ones."
- "Show me critical vulnerabilities across all xCloud sites."
- "Deploy the latest Git commit for example.com."

If Claude ever reaches for the wrong area, just name it:
*"Using xcloud:ssl, renew the cert for example.com."*

---

## Real-world workflows

These are the things people actually do day to day. Each is **one request** —
Claude chains the steps across whatever skills it needs.

### 1. Monday-morning health audit

> **You:** "Audit example.com — is it up, is SSL healthy, any vulnerabilities,
> and how's performance?"

**What Claude does:** checks the site is serving, inspects the SSL certificate's
expiry, runs a vulnerability scan, and runs a PageSpeed scan — then hands you one
summary:

- ✅ Up, responding normally
- 🔒 SSL valid, 58 days to expiry
- ⚠️ 2 critical vulnerabilities found
- ⚡ PageSpeed 74 / 100

No endpoints, no dashboards — one question, one answer.

### 2. Safe WordPress update

> **You:** "WooCommerce has an update — apply it to example.com, but back up
> first and tell me if anything looks off."

**What Claude does:** takes a labelled backup and waits for it to finish, applies
the update (with its own pre-update snapshot too), then confirms the site is
still healthy. If something breaks, Claude tells you immediately and you can
follow up with *"restore the backup you just took"* — a built-in rollback path.

### 3. New site go-live

> **You:** "I just provisioned shop.example.com — set up HTTPS and confirm it's
> serving."

**What Claude does:** installs a free Let's Encrypt certificate, waits for it to
issue, verifies the site is serving over HTTPS, and runs a baseline PageSpeed
scan so you know where you're starting from.

### 4. Triage a site that's down

> **You:** "example.com is throwing 502 errors — what's going on?"

**What Claude does:** pulls the site status, recent events, and SSH/user config
to spot the usual culprits (stopped service, missing OS user, failed deploy), and
reports back what it found.

### 5. Lock down an abusive IP

> **You:** "Something's hammering my server from 203.0.113.7 — block it."

**What Claude does:** adds the IP to fail2ban on that server and confirms the
ban.

---

## The mental model

Think in **tasks**, not endpoints:

> "go live" · "audit it" · "update safely" · "why is it down" · "block that IP"

Each task maps to one short conversation. You bring the intent; the skills bring
the API.

---

## When something's off

| You see… | What it means | What to do |
|---|---|---|
| "token is not set" | No API token configured | Add it to settings.json (Quick start, step 2) |
| A `401` error | Token expired or revoked | Generate a new token |
| A `403` error | Token is missing a permission/scope | Add the scope (e.g. SSL needs SSL permission) |
| A `429` error | Too many requests (limit 60/min) | Wait a moment and retry |
| Wrong area answered | Ambiguous phrasing | Name the skill: "Using xcloud:sites, …" |
| Hitting the wrong server | Pointed at local vs live | Check `XCLOUD_API_BASE_URL` (unset = live) |

---

## More detail

- **Full install & reference:** [SKILLS-GUIDE.md](./SKILLS-GUIDE.md)
- **Live API docs:** <https://app.xcloud.host/api/v1/docs>
