# What xCloud can do over the API, in the dashboard, or not at all

Shared by every `xcloud:*` domain skill. Read this **before planning a
multi-step job** — it is the map from a job to the tool that does it, the
dashboard page that does it when no tool exists, and the short list of jobs
xCloud cannot do at all. Those last two are different: a dashboard-only job
still gets done, it just needs the human for one step. Guessing here wastes a
human's time and produces confident wrong answers.

Each row names the **tool alias** (the tool name on `/mcp`) and the
**canonical operation id** (the spec `operationId`, which the `/mcp/v2`
executors also accept). See `reference/mcp.md` for the alias rule.

Dashboard paths are written the way a human navigates them. Send the user
there; never claim an API call exists for a UI-only step.

_Verified against the xCloud Public API spec and application routes on
2026-09-08 (xCloud `master` `9ab59ef`)._

## Servers and provisioning

| Job | Tool (alias · canonical id) | Dashboard-only | Refused |
|---|---|---|---|
| Buy an xCloud-managed server, or connect your own provider | — | **Servers → Create Server** (managed plan, own provider, or a custom host) | — |
| See plans, prices and what a plan allows | `catalog_pricing_index` · `catalog.pricing.index` | | |
| See which apps and stacks a site can be created from | `catalog_apps_index` · `catalog.apps.index` | | |
| List / inspect servers after they exist | `servers_index` · `servers.index`, `servers_show` · `servers.show` | | |
| Reboot, restart or disable a service | `servers_reboot`, `servers_services_restart`, `servers_services_disable` | | |
| Run an arbitrary shell command on a server | — | **Server → Command Runner** | |
| Create a temporary privileged OS user | `servers_sudoUsers_store` · `servers.sudoUsers.store` (`is_temporary`) | | |
| Databases and database users | — | **Server → Database** — withheld from the public API: the routes exist upstream but are commented out, so every `databases` / `database-users` path returns **404** and no MCP tool exists | |

## Creating sites

| Job | Tool (alias · canonical id) | Notes |
|---|---|---|
| WordPress site | `servers_sites_wordpress_create` · `servers.sites.wordpress.create` | **422** on a Docker server ("WordPress is not supported on Docker servers") |
| Git site, explicit app type | `servers_sites_git_create` · `servers.sites.git.create` | nginx / OpenLiteSpeed servers only |
| Git site, auto-detected | `servers_sites_git_auto` · `servers.sites.git.auto` | any non-agentic server, Docker included |
| Git site on Docker with pinned container config | `servers_sites_git_docker` · `servers.sites.git.docker` | **422** on a non-Docker server, pointing at the nginx endpoint |
| Preview what a repository would deploy as | `git_detect` · `git.detect` | creates nothing |
| Install a one-click app | `oneclickApps_install` · `oneclickApps.install` | |

**Refused: a second site on an agentic server.** OpenClaw, Paperclip, Hermes
and DeepSeek Harness servers host only the site created for them during
provisioning — `ServerPolicy::addSite` returns false for those stacks. Each
endpoint refuses in its own way: the WordPress and native/auto Git endpoints
return **403** — WordPress says "Agentic servers support only the site created
automatically during provisioning" (and an OpenClaw-specific wording on
OpenClaw), the Git endpoints say "Agentic servers support only the site created
during provisioning"; the Docker
endpoint returns **422**, because an agentic server is not a Docker server; a
one-click install is stopped by the compatibility gate with a **422** stack
failure. There is no dashboard workaround — the user needs another server.

## Domains and DNS

| Job | Tool (alias · canonical id) | Dashboard-only |
|---|---|---|
| Read the primary domain, all domains, redirections, web rules | `sites_domain` · `sites.domain`, `sites_domains` · `sites.domains`, `sites_redirections` · `sites.redirections`, `sites_webRules` · `sites.webRules` | |
| Watch a domain change land | `sites_domainUpdateStatus` · `sites.domainUpdateStatus` | |
| Check whether a domain resolves to the server yet | `servers_dns_check` · `servers.dns.check` | |
| Add, change or remove a domain; add redirections or web rules | — | **Site → Domain** |

Domain management is **read-only on the API**. A live-domain deploy that
returns a `domain_setup` block is telling the human to add a DNS record; poll
`servers_dns_check` while they do.

## Backups, snapshots and restore

| Job | Tool (alias · canonical id) | Dashboard-only |
|---|---|---|
| Back up a site now | `sites_backup` · `sites.backup` (Docker sites: `sites_docker_backup` · `sites.docker.backup`) | |
| List backups, count them, read schedule and status | `sites_backups`, `sites_backupCount`, `sites_backupSettings`, `sites_backupStatus` | |
| Change a native site's backup schedule, retention or destination | — | **Site → Backup Settings** |
| Change a **Docker** site's backup schedule or retention | `sites_docker_backupSettings_update` · `sites.docker.backupSettings.update` | |
| Restore a backup, download a backup file | — | **Site → Backups** (restore to this site, to a new site, or to another site) |
| Apply backup settings to many sites at once | — | **Team settings → Global backup settings** |
| Add or verify a backup storage provider | — | **User → Storage Providers** |
| List snapshots | `sites_snapshots` · `sites.snapshots`, `servers_snapshots` · `servers.snapshots` | |
| Create a snapshot from a site, or restore one into an existing site | — | **Site → Snapshots** |
| Create a **new** WordPress site from a ready snapshot | `servers_sites_wordpress_create` · `servers.sites.wordpress.create` with `snapshot_uuid` | |
| Enable provider (server-image) backups, or sync them from the provider | — | **Server → Backup** |

`servers_snapshots` returns the **site** snapshots taken from sites on that
server — it is not a server-image list. Provider server-image backups have no
public API at all; they are enabled and synced from **Server → Backup**.

## Logs and troubleshooting

| Job | Tool (alias · canonical id) | Dashboard-only |
|---|---|---|
| Site state, and whether an async job finished | `sites_status` · `sites.status` | |
| Recent site events; a window of one step's output | `sites_events` · `sites.events`, `sites_events_show` · `sites.events.show` | |
| Web-server access and error lines | `sites_access-logs` · `sites.access-logs` (`type` = `access`, `nginx`, `lsws`) | |
| Deployment records between sites (staging push/pull) | `sites_deployment-logs` · `sites.deployment-logs` | |
| Turn `WP_DEBUG` on or off | `sites_wp-debug` · `sites.wp-debug` | |
| Server-level task history | `servers_tasks` · `servers.tasks` | |
| PHP error log, `WP_DEBUG` log **contents**, Laravel log, PM2 log, 7G/8G firewall logs, docker-compose logs, OpenClaw / DeepSeek Harness journals | — | **Site → Logs** (and **Server → Logs**); these can also be cleared and emailed from there |

The API's `type=nginx` reads a glob over the site's nginx log directory, so it
returns access **and** error lines. `type=access` is the access log alone. The
toggle for `WP_DEBUG` is on the API; the resulting debug **file** is not.

## Shell and staging

| Job | Tool (alias · canonical id) | Dashboard-only |
|---|---|---|
| Create / list / delete sudo users | `servers_sudoUsers_store`, `servers_sudoUsers_index`, `servers_sudoUsers_destroy` | |
| Read or change a site's SSH/SFTP settings and keys | `sites_ssh_show` · `sites.ssh.show`, `sites_ssh_update` · `sites.ssh.update`, `sites_sshKeys` · `sites.sshKeys` | |
| List staging sites | `sites_stagingSites` · `sites.stagingSites` | |
| Create a staging site, push or pull between staging and live | — | **Site → Staging** |

## Account, billing and tokens

| Job | Tool (alias · canonical id) | Dashboard-only | Refused |
|---|---|---|---|
| Who am I, blueprints, Cloudflare and Git integrations | `user_show`, `blueprints_index`, `integrations_cloudflare_index`, `integrations_git_index` | | |
| Plan, invoices, bills, packages, subscriptions, payment methods (read) | `billing_*` · `billing.*` (needs the `read:billing` scope) | | |
| Change plan, add a payment method, pay an invoice | — | **User → Bills & Payment** / **User → Wallet** | |
| Connect a Git or Cloudflare provider | — | **User → Git Providers**, **User → Integrations → Cloudflare** | |
| List or revoke API tokens | — | **User → Profile → API Tokens** | Never exposed on either MCP surface; over REST it works only with a full-access (`*`) token |

## The two short lists

Keep them apart. A dashboard-only job is *doable* — the human does one step in
the UI and the agent picks the work back up over the API. A not-possible job
has no path at all, and offering a workaround wastes the human's time.

### Dashboard only — do it in the UI, then continue via API

1. **Buying an xCloud-managed server, or connecting a cloud provider** —
   **Servers → Create Server**. Read prices with `catalog_pricing_index`
   beforehand; once the server exists, `servers_index` picks it up and
   everything else in this file applies.
2. **Database and database-user management** — **Server → Database**. The
   public-API routes exist but are commented out upstream, so every
   `databases` / `database-users` path returns `404` and no MCP tool exists.
3. **Adding or changing a domain, redirection or web rule** — **Site →
   Domain**. The API reads them; it does not write them.
4. **Backup schedule and retention for a native site, restore, backup
   download** — **Site → Backup Settings** and **Site → Backups**. Bulk
   settings live in **Team settings → Global backup settings**, storage
   providers in **User → Storage Providers**. Docker sites are the exception:
   their schedule is writable over the API.
5. **Creating or restoring a site snapshot** — **Site → Snapshots**; provider
   server-image backups are **Server → Backup**. Creating a *new* WordPress
   site from a ready snapshot is the one API-side exception
   (`servers_sites_wordpress_create` with `snapshot_uuid`).
6. **Reading a PHP error log, a `WP_DEBUG` log, a Laravel or PM2 log, the 7G/8G
   firewall logs, docker-compose logs or an agent journal** — **Site → Logs**.
   The API can toggle `WP_DEBUG`, not read the file it writes.
7. **Creating a staging site, pushing or pulling between staging and live** —
   **Site → Staging**. The API lists staging sites only.
8. **Running an arbitrary shell command** — **Server → Command Runner**. The
   API's route to a shell is a temporary sudo user or the site's SSH settings.
9. **Changing a plan, adding a payment method, paying an invoice** — **User →
   Bills & Payment** / **User → Wallet**. Billing is read-only on the API.
10. **Listing or revoking API tokens from an MCP session** — **User → Profile →
    API Tokens**. Both operations are excluded from tool generation on purpose;
    over the REST fallback they still work, but only with a full-access (`*`)
    token.

### Not possible on any surface

1. **A second site on an agentic server** (OpenClaw, Paperclip, Hermes,
   DeepSeek Harness) — the stack hosts only the site created for it during
   provisioning. There is no dashboard workaround; the user needs another
   server.
2. **WordPress on a Docker server** — refused with `422`. Deploy it as a Git or
   one-click site instead, or use a different server.

When a job lands in the first list, name the dashboard page and say what you
will do once the human is back. When it lands in the second, say so plainly and
do not attempt a substitute call.
