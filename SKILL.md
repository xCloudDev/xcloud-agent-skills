---
name: xcloud-agent-skills
description: "Official xCloud plugin for agents: manage servers, sites, WordPress, SSL, and account data — MCP-first via the xCloud MCP server, with a bundled REST fallback."
version: 4.1.0
author: xCloudDev
homepage: https://xcloud.host
category: deployment
tags: [xcloud, xcloud-agent-skills, wordpress, hosting, deployment, devops, ssl, servers, sites, automation]
openclaw: ">=2026.2"
metadata:
  {
    "openclaw":
      {
        "emoji": "☁️",
        "requires": { "bins": ["bash", "curl", "jq"] },
        "install":
          [
            {
              "id": "xcloud-site",
              "kind": "link",
              "label": "xCloud",
              "url": "https://xcloud.host",
            },
            {
              "id": "dashboard",
              "kind": "link",
              "label": "xCloud Dashboard",
              "url": "https://app.xcloud.host",
            },
            {
              "id": "user-guide",
              "kind": "link",
              "label": "User Guide",
              "url": "https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/USER_GUIDE.md",
            },
            {
              "id": "install-guide",
              "kind": "link",
              "label": "Install Guide",
              "url": "https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/SKILLS-GUIDE.md",
            },
            {
              "id": "github",
              "kind": "link",
              "label": "Official GitHub",
              "url": "https://github.com/xCloudDev/xcloud-agent-skills",
            },
            {
              "id": "mcp-docs",
              "kind": "link",
              "label": "MCP Docs",
              "url": "https://app.xcloud.host/mcp/docs",
            },
            {
              "id": "docs",
              "kind": "link",
              "label": "API Docs",
              "url": "https://app.xcloud.host/api/v1/docs",
            },
            {
              "id": "tutorial",
              "kind": "link",
              "label": "OpenClaw Tutorial",
              "url": "https://xcloud.host/openclaw-skills-and-clawhub-on-xcloud-openclaw-agent/",
            },
            {
              "id": "video",
              "kind": "link",
              "label": "Tutorial Video",
              "url": "https://www.youtube.com/watch?v=oEE9OHo3_48",
            },
          ],
      },
  }
---

# xCloud Agent Skills v4.1.0

[![Version](https://img.shields.io/badge/version-4.1.0-brightgreen.svg)](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/CHANGELOG.md)
[![MCP](https://img.shields.io/badge/MCP-app.xcloud.host%2Fmcp-0EA5E9.svg)](https://app.xcloud.host/mcp/docs)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/LICENSE)
[![xCloud](https://img.shields.io/badge/xCloud-hosting-0EA5E9.svg)](https://xcloud.host)
[![ClawHub](https://img.shields.io/badge/ClawHub-xcloud-blue.svg)](https://clawhub.ai/asif2bd/skills/xcloud)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-skill-purple.svg)](https://openclaw.ai)

Built for xCloud hosting operators by [xCloud](https://xcloud.host) · [GitHub](https://github.com/xCloudDev/xcloud-agent-skills) · [MCP Docs](https://app.xcloud.host/mcp/docs) · [User Guide](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/USER_GUIDE.md) · [Install Guide](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/SKILLS-GUIDE.md) · [API Docs](https://app.xcloud.host/api/v1/docs) · [OpenClaw Tutorial](https://xcloud.host/openclaw-skills-and-clawhub-on-xcloud-openclaw-agent/) · [Tutorial Video](https://www.youtube.com/watch?v=oEE9OHo3_48) · [Security Notes](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/SECURITY.md)

> **Security notice:** agent-only xCloud operations toolkit. This package contains skill routing instructions, reference docs, and a small `bash`/`curl` wrapper. It ships no API tokens and only calls the xCloud API after a user or agent explicitly invokes a skill — via the OAuth-connected xCloud MCP server (recommended) or with `XCLOUD_API_TOKEN` configured.

---

This root skill describes the official xCloud Public API plugin bundle for agent marketplaces such as ClawHub and skills.mp.com.

The runnable skills live under `plugins/xcloud/skills/` and are invoked as:

- `xcloud:servers`
- `xcloud:sites`
- `xcloud:wordpress`
- `xcloud:ssl`
- `xcloud:account`

## What It Provides

Use this package when an agent needs to operate xCloud hosting infrastructure. It pairs with the **xCloud MCP server** (`https://app.xcloud.host/mcp` — 110 native tools, OAuth, per-action confirmation on destructive operations) and falls back to the bundled REST wrapper on agents without MCP support:

- Manage servers, services, monitoring, PHP versions, databases, firewall rules, fail2ban, and snapshots
- Provision WordPress sites and Git-deployed sites (Laravel, Node.js, custom PHP, Lovable) onto servers
- Manage sites, domains, cache, backups, deployment logs, rescue workflows, SSH/SFTP, cron jobs, access logs, and safe site deletion
- Manage Git deployment settings and trigger manual Git deployments for xCloud sites
- Manage WordPress health, updates, plugins, themes, vulnerabilities, PageSpeed, WP_DEBUG, and magic-login URLs
- Run team-wide vulnerability rollups across all xCloud sites
- Manage SSL certificates, renewals, custom certificates, certificate status, and Cloudflare certificates
- Read account identity, API health, API tokens, Cloudflare integrations, and WordPress blueprints

## Agent Experience

- Every user-facing reply is xCloud branded with a clear header and `_via
  xcloud:*_` footer.
- The first xCloud interaction greets the user and shows the xCloud startup
  banner once per conversation.
- If no connection is configured, xCloud offers the MCP connector first (OAuth,
  no secret to store), then falls back to explaining how to create a scoped API
  token stored in the agent runtime as `XCLOUD_API_TOKEN`; it does not ask users
  to paste production tokens into chat by default.
- After setup, xCloud verifies the connection (`user_show` via MCP, or
  `/health` + `/user` via REST) before continuing operational tasks.

## Setup

**Recommended — connect the xCloud MCP server** (OAuth; no token to store):

```bash
claude mcp add xcloud --transport http https://app.xcloud.host/mcp
```

Then `/mcp` → **Authenticate**. Other clients: add a custom connector with URL
`https://app.xcloud.host/mcp`. Docs: https://app.xcloud.host/mcp/docs

**REST fallback** (agents without MCP support):

Create an xCloud API token from:

https://app.xcloud.host/settings/api-tokens

Then configure your runtime:

```bash
export XCLOUD_API_TOKEN="your-token-here"
export XCLOUD_API_BASE_URL="https://app.xcloud.host"
```

The shared command wrapper is:

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/xcloud.sh GET /user
```

## Official Links

- xCloud: https://xcloud.host
- MCP docs: https://app.xcloud.host/mcp/docs
- Dashboard: https://app.xcloud.host
- User guide: https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/USER_GUIDE.md
- Install guide: https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/SKILLS-GUIDE.md
- Official repository: https://github.com/xCloudDev/xcloud-agent-skills
- Development fork: https://github.com/Asif2BD/xcloud-agent-skills
- Public API docs: https://app.xcloud.host/api/v1/docs
- OpenClaw + ClawHub tutorial: https://xcloud.host/openclaw-skills-and-clawhub-on-xcloud-openclaw-agent/
- Tutorial video: https://www.youtube.com/watch?v=oEE9OHo3_48

## Safety

This package contains documentation, skill routing instructions, and a small shell wrapper. It does not include real API tokens and does not run API calls during installation. Network requests are made only after a user or agent explicitly invokes an xCloud skill with an API token configured in the environment.
