Manage WordPress sites and hosting with **xCloud agent skills**. Ask a compatible
agent to investigate a slow site, review plugin updates, check HTTPS or plan a
new deployment. It uses the relevant skill, checks the selected team and
resource, and explains what it can do with your connection.

Installing the skills does not connect your account or grant access. Changes
need the corresponding connected xCloud MCP tool, the required concrete user
approval and server confirmation. Availability depends on your client, granted
access, plan and server type.

[Skills repository](https://github.com/xCloudDev/xcloud-agent-skills) ·
[ClawHub package](https://clawhub.ai/asif2bd/xcloud) ·
[User guide](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/USER_GUIDE.md) ·
[Installation guide](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/docs/SKILLS-GUIDE.md)

## Start with a read-only WordPress check

After installation and authentication, use this first request:

```text
Check my xCloud identity and available teams. On the team I select, review example.com: site status, WordPress health, SSL, available plugin updates, existing vulnerability findings and existing PageSpeed results. Do not change anything or start new scans. Summarize the evidence and anything you could not check.
```

An existing result may be old or missing. Ask the agent to show its timestamp
when available. A new scan is a separate operation; a read-only check does not
implicitly authorize it.

## Nine capabilities

Describe the outcome you want; the agent selects the relevant capability. The
areas below include reads and changes; they do not imply that every operation
is available through every connection.

{{CAPABILITIES}}

## WordPress workflows: inspect, approve, verify

### Investigate a slow site

**Inspect:** read monitoring, cache settings, existing PageSpeed results,
traffic and the site's PHP version. Free-plan history may be unavailable.

```text
Why is example.com slow? Inspect available monitoring, cache state and existing PageSpeed results. Show the evidence and propose the smallest useful next step before making a change or starting a new scan.
```

**Approve:** if a supported MCP action would help, review its target and impact
before authorizing it. A pending PageSpeed scan should be polled instead of
starting another. Cache-layer activation and changing a site's PHP version
require the dashboard paths below.

**Verify:** compare available results and check the public site. A cache purge
or scan finishing does not by itself prove that the original issue is fixed.

### Update a specific WordPress plugin

**Inspect:** identify the site, installed plugin version, available update and
backup status. Agree on the exact plugin and recovery plan. For WooCommerce,
first create or refresh WordPress staging through the dashboard. Apply the
proposed update there with approval, then complete manual cart, checkout,
sandbox-payment, account and email tests using test data and test recipients.
Confirm that checkpoint before approving a production update.

```text
Review the WooCommerce update for example.com. Show the current and target versions, impact, backup and data-preserving recovery plan. Guide me through the dashboard WordPress staging step and an approved staging update. Wait for confirmation that cart, checkout, sandbox-payment, account and email tests passed before asking for production approval. After approval, back up production and confirm completion, update only WooCommerce through connected MCP tools, then verify its version, WordPress health and the public site. Report remaining manual checks.
```

**Approve:** changes run through the corresponding MCP tools with the required
approval and server confirmation. If those tools or confirmation are
unavailable, use the dashboard. Stop if the backup fails.

**Verify:** check the plugin version, WordPress health and HTTP/HTTPS delivery.
Report incomplete checks honestly. Restoring a backup is a dashboard step;
the agent can provide the backup details and the site's returned dashboard URL.
A restore can discard newer orders and other writes made after the backup.
Before any recovery, confirm a plan that preserves that newer data and obtain
approval for its exact impact; do not promise an automatic rollback.

### Diagnose an error or an expiring certificate

```text
example.com returns 502. Read its status, recent events, bounded web-server error logs, WordPress health and relevant service status. Explain the likely cause and propose a fix before restarting services, enabling debug or granting temporary access.
```

```text
Check example.com's certificate and HTTPS response. If renewal is needed, show the exact site and proposed change for approval. After an approved MCP renewal, wait for its result and verify HTTPS before calling it complete.
```

Web-server access/error logs are available through the documented operations.
WordPress debug.log, Laravel, PM2, container and server logs require the
appropriate dashboard view. Debug toggles and temporary access need approval
and cleanup; they are not automatic diagnosis steps.

## Deploy beyond WordPress

Create a WordPress site on a compatible Nginx or OpenLiteSpeed server, deploy a
supported Git repository, use a suitable Docker/Compose setup, or create Git
branch staging. Repository access, installed runtimes and server compatibility
must be checked first.

```text
Plan a new WordPress site for shop.example.com on my selected server. Check compatibility and DNS, show the proposed settings, and get my approval before creating anything. After creation, verify site status and HTTPS and report any remaining dashboard steps.
```

```text
Inspect https://github.com/acme/shop for deployment to my selected server. Check repository access, runtime and Compose port requirements where relevant. Show a deployment preview for approval before creating resources; then wait for completion and verify the public URL.
```

WordPress cannot be created on Docker servers. Agentic servers accept only the
site created during provisioning. Some one-click apps require dashboard
installation. A deployed status alone does not prove the application works;
unsupported builds, missing secrets and application bugs may need developer
changes. See the
[capability map](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/plugins/xcloud/reference/capability-map.md).

## Choose one installation path

### OpenClaw / ClawHub

```bash
clawhub install xcloud
```

For an existing install, use your client's supported update flow or
`clawhub update xcloud`; review local modifications before replacing them.
The package includes the root router, nine capability skills, shared references
and REST wrapper. It does not configure MCP or provide credentials. Connect
MCP in your client's settings if supported, otherwise use the read-only REST
fallback described below.

### Claude Code

Run inside Claude Code:

```text
/plugin marketplace add xCloudDev/xcloud-agent-skills
/plugin install xcloud@xcloud-agent-skills
/reload-plugins
```

Add the MCP connection from a terminal:

```bash
claude mcp add xcloud --transport http https://app.xcloud.host/mcp
```

Complete browser authorization through `/mcp` → **Authenticate**, then check
the granted scopes and team before the first request.

### Other compatible agents

Import the portable **Agent Plugins** package from
[GitHub Releases](https://github.com/xCloudDev/xcloud-agent-skills/releases), or
use [dist/agent-plugin/xcloud](https://github.com/xCloudDev/xcloud-agent-skills/tree/main/dist/agent-plugin/xcloud).
It includes `plugin.json`, `mcp.json` and nine self-contained skills. For hosts
that accept individual skills, keep each skill directory's references and
wrapper; copying only SKILL.md is insufficient. Import and OAuth support depend
on the client.

Claude's web app has a separate
[consolidated package](https://github.com/xCloudDev/xcloud-agent-skills/tree/main/dist/claude-app).
Chat-only clients still need connected tools or an execution environment to
perform operations.

## Connect your xCloud account

### MCP: reads and approved changes

Use `https://app.xcloud.host/mcp` with client-managed OAuth. Request Read
(`mcp:read`) or Read & write (`mcp:write`) as appropriate; a completed login
does not guarantee write access. A supported bearer-token connection requires
`mcp:invoke` plus the relevant granular scopes. A wildcard token alone does not
imply `mcp:invoke`.

The compact profile is `https://app.xcloud.host/mcp?profile=compact`. Confirm
client compatibility and connection limitations in the
[MCP setup guide](https://app.xcloud.host/mcp/docs) and
[connection notes](https://github.com/xCloudDev/xcloud-agent-skills/blob/main/plugins/xcloud/reference/mcp.md).

### REST fallback: GET-only, no write override

The packaged `xcloud.sh` permits **GET-only requests with no body** and has
**no write override**. Store `XCLOUD_API_TOKEN` in the runtime environment or a
secret store with read-only scopes, such as `read:sites`, `read:servers`,
`read:billing` or `read:addons`, limited to the access you need. Never paste
production tokens into chat or commit them. The wrapper requires `bash`,
`curl` and `jq`; MCP-only use does not require it.

For a mutation, use the corresponding connected MCP tool only after the
required concrete user approval and server confirmation. If that tool or
confirmation is unavailable, stop and use the dashboard. Do not bypass this
boundary with direct curl, SDKs, alternate scripts or edits to the wrapper.
Older upstream non-GET API examples are not executable fallback commands.
API-token listing and `/health` are REST-only; token revocation is unavailable
through the GET-only wrapper, so revoke tokens in the dashboard.

Use the [API reference](https://app.xcloud.host/api/v1/docs) for endpoint and
scope details. This page is a guide and intentionally contains no API operations.

## Know when to use the dashboard

The agent should report the documented path alongside the `dashboard_url`
returned by a site or server read; it should not invent a dashboard URL.

| Task | Dashboard path and boundary |
|---|---|
| Enable or disable page, object or edge cache | **Site → WordPress → Caching**. Reading settings and an approved MCP purge are separate supported operations. |
| Change an existing site's PHP version | **Site → Site Settings**. Changing the server PHP default does not move existing sites. |
| Restore a native or Docker backup | **Site → Site Backup → Previous Backups → Restore Backup**. The agent can list backups; restore needs the dashboard. |
| Create WordPress staging | **Site overview → Add Staging**. API staging creation supports Git sites only. |
| Push WordPress staging to production or pull production to staging | **Site → Manage Staging**, on the staging site (paid plan). Deployment history can be read. |
| Change a live site's domain | **Site → Domain → Domain**; staging go-live uses **Site → Domain → Go Live**. Domain inspection remains available. |
| Read application or server logs beyond web-server access/error logs | **Site → Site Monitoring → Logs** or **Server → Monitoring → Logs**. |
| Change or cancel a subscription or change the payment card | **Account → Billing → Bills & Payment** / **Account → Subscriptions**. |
| Revoke an API token | **Account → Developers → API Tokens**. No MCP revocation tool or packaged REST write path. |

Purchases and invoice payments can spend money. Before an approved action,
review the exact item, price, renewal period and payment method. A timeout is
not permission to charge again. Skills help carry out supported steps; they do
not promise universal automation or automatic recovery.
