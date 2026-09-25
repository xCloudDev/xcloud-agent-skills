# What the API cannot do (shared)

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Shared by every xCloud domain skill. Before promising a job, check it here.
Most of xCloud is on the API; the rows below are the exceptions, in one place,
so an agent can say "that is a dashboard step: **Site → WordPress → Caching**"
instead of guessing an operation or reporting a 404 as an outage. Verified
against the xCloud v2.8.8 release (routes, controllers and dashboard
navigation).

Every job falls into one of five kinds:

| Kind | Meaning | What the agent does |
|---|---|---|
| **api** | An operation does the whole job | Do it (with confirmation where the class needs it) |
| **api_read** | The API reads it; changing it is dashboard-only | Read it, report it, then hand off with the dashboard path |
| **rest** | Public REST only, no MCP tool | Use the REST wrapper, or send the human to the dashboard path |
| **ui** | Dashboard only, nothing on the API | Give the dashboard path and the site's or server's `dashboard_url` |
| **impossible** | xCloud refuses it outright | Say so plainly, with the reason, and offer the alternative |

Always give the `dashboard_url` from the server or site read (`servers.show`,
`sites.show`) next to the path — never construct one. On MCP,
`xcloud_agent_search` returns the same `ui` and impossible steps inside a job's
guidance.

## Not on this list: these are API jobs

Older notes called some of these dashboard-only. They are not:

- **Staging for a Git site** (Laravel, Node.js, custom PHP, Lovable):
  `sites.stagingSites.create`. Only WordPress staging stays in the dashboard.
- **The 7G and 8G firewall logs** and the site's web server **error log**:
  `sites.access-logs` with `type=nginx` reads every `{site}*.log` file (access,
  error, 7G, 8G), on nginx and OpenLiteSpeed alike.
- **Correct a failed Git deploy and retry it on the same site**:
  `sites.deploy-diagnosis`, `sites.deploy-config`, `sites.deploy-config.update`,
  `sites.provision-retry`.
- **Server PHP and Node versions** (install, uninstall, default, patch,
  OPcache): `servers.php-versions.*`, `servers.node-versions.*`.
- **Docker site backup settings**: `sites.docker.backupSettings.update`.
- **Firewall rules, fail2ban, sudo users, cron jobs, services, deploy keys,
  SSL certificates, verified reboots, vulnerability ignore, WordPress magic
  login, mailboxes**: all on the API.

## Dashboard-only jobs

| Job | Kind | Dashboard path | What the API does instead |
|---|---|---|---|
| Turn page cache, object cache (Redis, Object Cache Pro) or Cloudflare edge cache on or off | api_read | **Site → WordPress → Caching** | `sites.cacheSettings` reads every layer; `sites.cache.purge` / `sites.cache.purge-all` purge. The one write is at creation: `cache.full_page`, `cache.object_cache`, `cache.xspeed` on `servers.sites.wordpress.create` |
| Change page-cache duration, URL or cookie exclusions, or ignored query parameters | ui | **Site → WordPress → Caching** (Page Caching) | — `sites.cacheSettings` does not return them. On OpenLiteSpeed they live in the LiteSpeed Cache plugin in wp-admin |
| Change **one site's** PHP version | api_read | **Site → Site Settings** (PHP version) | `sites.show` and `sites.wordpress.status` read `php_version`; it is chosen at creation (`php_version` on `servers.sites.wordpress.create` / `servers.sites.git.create`). `servers.php-versions.default` is **not** a substitute: it changes the server's command-line `php` and the version new sites get, and moves no existing site |
| Change PHP settings (memory limit, upload size, execution time) or PHP extensions | ui | **Server → Management → Manage PHP** / **PHP Extensions**; per site under **Site → Site Settings** | `servers.php-versions.*` installs, removes, patches and toggles OPcache; nothing writes `php.ini` values |
| Read the WordPress `debug.log`, the Laravel log, PM2 or docker-compose logs, an agentic stack's journal, or server logs (fail2ban, auth.log) | ui | **Site → Site Monitoring → Logs**; server logs at **Server → Monitoring → Logs** | `sites.access-logs` (`type=nginx`: access, error, 7G and 8G logs), `sites.events`; `sites.wp-debug` only toggles the flag |
| Add, change or remove a domain on an existing site | api_read | **Site → Domain → Domain** (a staging site: **Site → Domain → Go Live**) | `sites.domain`, `sites.domains`, `sites.domainUpdateStatus`, `servers.dns.check`; a live domain is chosen at creation |
| Create or edit redirects, site rules or custom nginx | api_read | **Site → Domain → Redirection**; **Site → Tools → Site Rules**; **Site → Tools → Nginx Customization** | `sites.redirections`, `sites.webRules`, `sites.customNginx` list them |
| Allow or block IP addresses for one site | api_read | **Site → Tools → IP Management** | `sites.ipAccess` lists them; server-wide blocks are on the API (`servers.firewallRules.*`, `servers.fail2ban.*`) |
| Password-protect a site (HTTP basic authentication) | ui | **Site → Tools → Basic Authentication** | — |
| Restore a site from a backup (native or Docker) | ui | **Site → Site Backup → Previous Backups → Restore Backup** (or **Restore to Another Site**) | `sites.backups`, `sites.docker.backups` list them; `sites.backup`, `sites.docker.backup` take one |
| Change a native site's backup schedule, retention or destination | api_read | **Site → Site Backup → Backup Settings** | `sites.backupSettings` reads; Docker sites are the exception — `sites.docker.backupSettings.update` writes |
| Apply backup settings to many sites at once | ui | **Account → Global Settings → Site Backup** | — |
| Add or change a backup storage provider | ui | **Account → Integrations → Storage Provider** | Backup settings return the provider's uuid and status, never its credentials |
| Take or restore a site snapshot | api_read | **Site → Site Snapshots** (Take Snapshot in the site's menu) | `sites.snapshots` lists one site's snapshots; `servers.snapshots` lists the **site** snapshots across a server — it is not a server image |
| Turn on, schedule or restore a server's provider backup (a whole-server image) | ui | **Server → Backup** | — nothing on the API reads or writes it |
| Push staging to production, pull production to staging | api_read | On the staging site: **Site → Manage Staging** (WordPress staging, paid plan) | `sites.deployment-logs` is the push/pull history |
| Create a **WordPress** staging environment | ui | **Site overview → Add Staging** | `sites.stagingSites.create` covers Git sites only (Laravel, Node.js, custom PHP, Lovable); WordPress answers `422` |
| Clone a site, or migrate a WordPress site or a whole server into xCloud | ui | Site menu → **Clone Site**; **Add site → Migrate An Existing WordPress Website** / **Migrate Full Server** | — |
| Databases and database users | ui | **Server → Management → Database**; **Site → Access Data → Database** | — (withheld from the public API) |
| Create, edit or remove supervisor (queue worker) processes | api_read | **Server → Management → Supervisor** | `servers.supervisorProcesses` lists them |
| Resize or delete a server | ui | **Server → Management → Settings** | — no operation; `servers.store` only buys |
| Connect a server from the customer's own cloud account, or a self-managed server | ui | **Servers → Create server → Bring and Manage Your Own Server** | `servers.store` buys xCloud-managed servers only |
| Install n8n, Supabase, Nextcloud, Mautic, LibreChat, Open WebUI, Ollama, Umami, WireGuard, phpMyAdmin or Site.pro | ui | **Add site → One-Click Apps** | `catalog.apps.index` lists them; `oneclickApps.install` answers `404` "OneClick app not found" for these eleven |
| Change or cancel a subscription, change the card, see payment history or refunds | ui | **Account → Billing → Bills & Payment**, **Account → Subscriptions** | `billing.*` reads plan, invoices and subscriptions; `payments.pay` settles an outstanding invoice |
| Grant more teams to an API token or MCP connection | ui | **Account → Developers → API Tokens**, or the OAuth consent screen when reconnecting | `teams.index` lists the teams already granted |
| List or revoke API tokens | rest | **Account → Developers → API Tokens** | `user.tokens.index`, `user.tokens.revoke` on REST only — no MCP tool |

## Impossible jobs

| Job | Why | Offer instead |
|---|---|---|
| Add a second site (WordPress, Git or one-click) to an **agentic** server — OpenClaw, Paperclip, Hermes, DeepSeek Harness | These stacks host only the one site created while the server was provisioned. The dashboard refuses it too; it is not a permission support can grant. | A new server for the second site |
| Create a WordPress site on a **Docker** server | `422` "WordPress is not supported on Docker servers" | An Nginx or OpenLiteSpeed server, or deploy the repository as a Docker site |
| Deploy a compose file **as-is** when it binds ports 80/443, publishes no port, or pulls an image from a private registry | A Docker site is proxied by xCloud's nginx (which owns 80/443) to one host port ≥1024 on `127.0.0.1`; a file that publishes no port is accepted and then answers 502; the deploy runs `docker compose pull` and never `docker login` | Rewrite the file: publish `127.0.0.1:<high port>:<app port>`, drop its own proxy and certbot, build the image from source. `git.compose-scan` shows services and ports first. A Node or PHP app can use the native path instead |

## Status codes are not uniform — match on the message

The same kind of refusal can come back as `403` on one endpoint and `422` on
another, and a `403` is not always a missing permission. Branch on the
`message` (and `errors.code` where the response carries one), never on the
status code alone:

| Situation | Status | What the response says |
|---|---|---|
| WordPress create on an agentic server | `403` | "OpenClaw servers support only one site, created automatically during provisioning" (OpenClaw) or "Agentic servers support only the site created automatically during provisioning" |
| Git create or auto-deploy on an agentic server | `403` | "Agentic servers support only the site created during provisioning" |
| Docker deploy (`servers.sites.git.docker`) on any non-Docker server, agentic included | `422` | `errors.code: incompatible_server` |
| One-click install on a server of the wrong stack | `422` | "This app requires a … server. This server is on the … stack." |
| WordPress create on a Docker server | `422` | "WordPress is not supported on Docker servers" |
| Staging create for a WordPress site | `422` | "WordPress staging is not available via the API…" (checked before the plan) |
| Staging create for a Git site on a free plan | `403` | "Staging environments are not available on the free plan." — a plan limit, not a permission |
| Monitoring history on a free plan | `403` | "Monitoring history is not available on the free plan." — a plan limit, not a permission |
| PageSpeed scan while one is running | `409` | A scan for this site is still pending or scanning — poll it; it is not a cooldown |
| The caller's team role or team permissions do not allow it | `403` | "Your team permissions do not allow: site:manage-monitoring" (the permission is named), or "Your team role does not permit access to site resources" |
| The token lacks the scope (ability) | `403` | "This action is unauthorized." |

So: an agentic refusal is final whatever its code — do not retry it on another
endpoint and do not ask for more permissions. A plan-limit `403` is answered
with the plan, not with "you lack access". Only a `403` that names a team
permission or role, or the bare "This action is unauthorized." of a missing
token scope, is fixed by changing the role or the token.
