# What xCloud can do, and what it cannot (shared)

> **Packaged REST boundary:** `xcloud.sh` sends GET requests only, with no body, and has no write override. Non-GET examples describe upstream API operations, not commands for this fallback. For changes, use the connected xCloud MCP tools after the user's approval and the server's confirmation. If those are not available, stop and send the user to the dashboard; do not bypass this boundary with direct curl, SDKs or by editing the wrapper. Configure REST credentials with read-only scopes.

<!-- facts:version:start -->
Verified against xCloud v3.0.2 (master ccb4b9c159) on 2026-11-23. If the server reports a newer version, trust `xcloud_agent_search` over this file.
<!-- facts:version:end -->

Shared by every xCloud domain skill. Before telling a customer that xCloud
cannot do something, ask `xcloud_agent_search` (or `search` on the unified
profile) with the job in plain words. Its answer is current for the customer's
account and wins over this file. Most of xCloud is on the API; the tables below
are the exceptions and the jobs that have a guide, generated from the facts of
the release named above.

Every job falls into one of four kinds:

| Kind | Meaning | What the agent does |
|---|---|---|
| **api** | Operations do the whole job | Do it, with a preview and the user's confirmation where the operation changes or deletes something |
| **read-only** | The API reads it; changing it happens elsewhere | Read it, report it, then hand off with the dashboard path |
| **dashboard-only** | Nothing on the API or MCP does it | Give the dashboard path and the site's or server's `dashboard_url` |
| **refused** | xCloud refuses it outright | Say so plainly, with the reason, and offer the alternative |

Always give the `dashboard_url` from the server or site read (`servers.show`,
`sites.show`) or from a refusal's `errors.dashboard_url`; never construct one.
Domain changes, a site's PHP version, redirects and site rules, backup
restores, databases, clones and WordPress staging are API jobs; do not send
the customer to the dashboard for them.

Some jobs the dashboard offers (cache switches, log viewers, supervisor
processes) also have dashboard-action tools on the MCP connection. Look before
you hand off: search first, and only then give the dashboard path.

## Jobs with API operations

<!-- facts:capability-api:start -->
| Job | Operations | Kind |
|---|---|---|
| deploy a Node.js app from a Git repository | `servers.index`, `git.detect`, `integrations.git.index`, `integrations.git.repositories`, `servers.git.deploy-keys.store`, `servers.git.deploy-keys.verify`, `servers.staging-hostname.suggest`, `integrations.cloudflare.index`, `servers.sites.git.auto`, `servers.sites.git.create`, `servers.sites.git.docker`, `sites.status`, `servers.dns.check`, `sites.deploy-diagnosis`, `sites.deploy-config`, `sites.deploy-config.update`, `sites.provision-retry`, `sites.git.deploy`, `sites.git.update`, `sites.rescue`, `sites.events.show` | read and change |
| create a WordPress site on an xCloud server | `servers.index`, `servers.show`, `blueprints.index`, `integrations.cloudflare.index`, `servers.sites.wordpress.create`, `sites.status`, `sites.events`, `sites.ssl`, `sites.magic-login`, `sites.wordpress.status`, `servers.dns.check` | read and change |
| install a one-click app (Vaultwarden, Uptime Kuma, PostgreSQL, …) on a server | `oneclickApps.index`, `oneclickApps.show`, `servers.index`, `oneclickApps.compatibility`, `oneclickApps.install`, `oneclickApps.status`, `oneclickApps.credentials`, `oneclickApps.lifecycle`, `sites.index`, `sites.show` | read and change |
| connect backup storage, set up a site's backups, take a backup, restore one, download one | `storage-providers.index`, `storage-providers.show`, `storage-providers.store`, `storage-providers.update`, `storage-providers.checkConnection`, `storage-providers.destroy`, `sites.backupSettings`, `sites.backupSettings.update`, `sites.backupSettings.destroy`, `sites.backup`, `sites.backups`, `sites.backupCount`, `sites.backupStatus`, `sites.backups.update`, `sites.backups.restore`, `sites.backups.restore-to-site`, `sites.events`, `sites.status`, `sites.snapshots`, `servers.snapshots`, `sites.docker.backup`, `sites.docker.backups`, `sites.docker.backup.show`, `sites.docker.backupCount`, `sites.docker.backupSettings`, `sites.docker.backupSettings.update`, `sites.docker.backup.destroy`, `sites.docker.backups.restore`, `servers.sites.wordpress.create` | read and change |
| find out why a site is returning a 500 error | `sites.show`, `sites.status`, `sites.events`, `sites.events.show`, `sites.access-logs`, `sites.deployment-logs`, `sites.wp-debug`, `sites.monitoring`, `sites.cacheSettings`, `sites.wordpress.status`, `sites.rescue`, `sites.cache.purge`, `sites.cache.purge-all`, `servers.services`, `servers.sudoUsers.store`, `servers.sudoUsers.destroy`, `sites.ssh.show`, `sites.ssh.update` | read and change |
| create a new xCloud-managed Vultr server through the API (servers.store), follow its provisioning, and quote what it costs | `servers.plans`, `servers.store`, `servers.provisioning-progress`, `servers.show`, `catalog.pricing.index`, `catalog.apps.index`, `servers.index`, `billing.plan`, `billing.overview`, `billing.payment-methods.index`, `billing.products.index`, `billing.packages.index`, `billing.subscriptions.index`, `payments.pay` | read and change |
| work out whether a server can host the site the human wants | `servers.index`, `servers.show`, `servers.sites`, `catalog.apps.index`, `oneclickApps.compatibility`, `servers.sites.wordpress.create`, `servers.sites.git.auto`, `servers.sites.git.docker` | read and change |
| work with a site's staging environment | `sites.stagingSites`, `sites.stagingSites.create`, `sites.show`, `sites.index`, `sites.status`, `sites.events`, `sites.siteScripts`, `sites.deployment-logs` | read and change |
| give a human (or yourself) shell access to debug, then take it away again | `servers.sudoUsers.index`, `servers.sudoUsers.store`, `servers.sudoUsers.destroy`, `sites.ssh.show`, `sites.ssh.update`, `sites.sshKeys`, `servers.firewall.ssh-restriction-status`, `servers.firewall.whitelist-caller-ip`, `servers.firewall.whitelist-xcloud-ips`, `servers.services` | read and change |
| connect to xCloud over MCP and call operations safely | `user.show`, `teams.index`, `auth.config`, `auth.token`, `auth.session`, `notifications.config`, `notifications.installations.show`, `notifications.installations.store`, `notifications.installations.destroy`, `notifications.installations.alerts.show`, `servers.index`, `sites.index`, `sites.status`, `sites.events`, `servers.tasks`, `user.tokens.index`, `user.tokens.revoke`, `health.check` | read and change |
| deploy a Docker Compose or Dockerfile app from a Git repository | `servers.index`, `git.detect`, `git.compose-scan`, `servers.staging-hostname.suggest`, `integrations.cloudflare.index`, `servers.sites.git.docker`, `servers.sites.git.auto`, `sites.status`, `servers.dns.check`, `sites.deploy-diagnosis`, `sites.deploy-config`, `sites.deploy-config.update`, `sites.provision-retry`, `sites.git.deploy`, `sites.rescue`, `sites.events.show` | read and change |
| find out why a site is slow, from data, and hand off the switches that are dashboard-only | `sites.show`, `sites.status`, `sites.monitoring`, `sites.monitoring.history`, `servers.monitoring`, `servers.monitoringHistory`, `sites.cacheSettings`, `sites.pagespeed.latest`, `sites.pagespeed.scan`, `sites.pagespeed.history`, `sites.access-logs`, `servers.services`, `sites.wordpress.status`, `sites.cache.purge-all`, `sites.cache.purge`, `sites.events`, `sites.events.show`, `servers.php-versions`, `servers.php-versions.available`, `servers.php-versions.install`, `servers.php-versions.default`, `servers.php-versions.opcache` | read and change |
| run the routine maintenance jobs on a site — cron jobs, WP_DEBUG, magic login, plugin and theme updates, vulnerability and broken-link scans | `sites.show`, `sites.broken-links.scans.show`, `sites.cronJobs`, `sites.cron-jobs.create`, `sites.cron-jobs.update`, `sites.cron-jobs.destroy`, `sites.cron-jobs.execute`, `sites.cron-jobs.output`, `servers.cron-jobs`, `servers.cron-jobs.create`, `servers.cron-jobs.update`, `servers.cron-jobs.destroy`, `servers.cron-jobs.execute`, `servers.cron-jobs.output`, `sites.deploy-config`, `sites.wp-debug`, `sites.magic-login`, `sites.wordpress.status`, `sites.wordpress.updates`, `sites.wordpress.update`, `sites.wordpress.refresh`, `sites.wordpress.plugins`, `sites.wordpress.themes`, `sites.wordpress.activate`, `vulnerabilities.index`, `sites.vulnerabilities.list`, `sites.vulnerabilities.count`, `sites.vulnerability-scan`, `sites.broken-links.scan`, `sites.broken-links.index`, `sites.broken-links.show`, `sites.customNginx`, `sites.webRules`, `sites.redirections` | read and change |
| answer what a team is on, what it owes and what it was invoiced, and hand off payment history and plan changes | `billing.plan`, `billing.overview`, `billing.invoices.index`, `billing.invoices.show`, `billing.bills.index`, `billing.bills.show`, `billing.packages.index`, `billing.products.index`, `billing.payment-methods.index`, `billing.subscriptions.index`, `payments.pay`, `catalog.pricing.index`, `user.show` | read and change |
| buy a branded mailbox or a mail delivery (xCloud Managed Email) plan, finish DNS verification, and give the human the connection settings | `addons.mailbox.plans`, `addons.mailbox.index`, `addons.mailbox.purchase`, `addons.mailbox.show`, `addons.mailbox.verify-dns`, `addons.mailbox.imap`, `addons.mailbox.pop`, `addons.mailbox.smtp`, `addons.mailbox.destroy`, `addons.mail-delivery.plans`, `addons.mail-delivery.index`, `addons.mail-delivery.purchase`, `addons.mail-delivery.show`, `payments.pay`, `billing.payment-methods.index` | read and change |
| change a server's firewall rules, unblock or ban an address, or restart, start, stop or install a server service such as nginx, MySQL, Redis or PHP-FPM | `servers.show`, `servers.firewall.ssh-restriction-status`, `servers.firewallRules`, `servers.firewall.whitelist-xcloud-ips`, `servers.firewallRules.create`, `servers.firewallRules.disable`, `servers.firewallRules.enable`, `servers.firewallRules.destroy`, `servers.firewall.whitelist-caller-ip`, `servers.fail2ban.banned-ips`, `servers.fail2ban.unban`, `servers.fail2ban.ban`, `servers.services`, `servers.services.restart`, `servers.services.enable`, `servers.services.disable`, `servers.services.install` | read and change |
| check a server's health, reboot it and prove it came back, change its Node.js or PHP runtime, or resize or delete it | `servers.index`, `servers.show`, `servers.monitoring`, `servers.monitoringHistory`, `servers.tasks`, `servers.services`, `servers.supervisorProcesses`, `servers.sites`, `servers.reboots.store`, `servers.reboots.show`, `servers.reboots.check`, `servers.reboot`, `servers.node-versions.index`, `servers.node-versions.default`, `servers.php-versions.available`, `servers.php-versions`, `servers.php-versions.install`, `servers.php-versions.default`, `servers.php-versions.patch-info`, `servers.php-versions.patch`, `servers.php-versions.uninstall` | read and change |
| optimise the caching on a site — read which cache layers are on, recommend the right ones for its stack, hand off the dashboard switches, purge, and re-measure | `sites.show`, `sites.cacheSettings`, `sites.pagespeed.latest`, `sites.wordpress.plugins`, `servers.services`, `servers.php-versions.available`, `servers.php-versions.opcache`, `sites.cache.purge-all`, `sites.cache.purge`, `sites.events.show`, `sites.pagespeed.scan`, `servers.sites.wordpress.create` | read and change |
| find a site, see its details, or delete it | `sites.index`, `sites.show`, `sites.destroy`, `servers.index`, `servers.show` | read and change |
| check a site's SSL certificate, install one, renew it, or remove one | `sites.ssl`, `sites.sslCertificates`, `sites.sslCertificates.create`, `sites.ssl.renew`, `ssl-certificates.show`, `ssl-certificates.status`, `ssl-certificates.destroy`, `sites.dnsCheck` | read and change |
| add or remove a domain or www alias, go live on a new primary domain, or check its DNS | `sites.domain`, `sites.domains`, `sites.domains.update`, `sites.domain.update`, `sites.domainUpdateStatus`, `sites.dnsCheck` | read and change |
| list or update plugins and themes, deactivate a plugin that breaks the site, or check WordPress health | `sites.wordpress.status`, `sites.wordpress.updates`, `sites.wordpress.plugins`, `sites.wordpress.themes`, `sites.wordpress.update`, `sites.wordpress.deactivate`, `sites.wordpress.activate`, `sites.wordpress.refresh`, `sites.wordpress.operations.show`, `sites.wordpress.cron`, `sites.wordpress.indexing`, `sites.backup` | read and change |
| change a site's PHP version, FPM pool or OPcache settings | `sites.php-version`, `sites.php-version.update`, `sites.php-fpm-settings`, `sites.php-fpm-settings.update`, `sites.php-opcache-settings`, `sites.php-opcache-settings.update`, `servers.php-versions.available`, `sites.events.show` | read and change |
| create or delete a database or database user, or list what a server has | `servers.databases`, `servers.databases.search`, `servers.databases.create`, `servers.databases.destroy`, `servers.database-users.index`, `servers.database-users.search`, `servers.database-users.create`, `servers.database-users.update`, `servers.database-users.destroy` | read and change |
| add, change, run, remove or check the output of a server cron job | `servers.cron-jobs`, `servers.cron-jobs.create`, `servers.cron-jobs.update`, `servers.cron-jobs.execute`, `servers.cron-jobs.output`, `servers.cron-jobs.destroy` | read and change |
| add, change or remove a redirect or web rule, or see which IPs are allowed or blocked | `sites.redirections`, `sites.redirections.store`, `sites.redirections.update`, `sites.redirections.destroy`, `sites.webRules`, `sites.webRules.store`, `sites.webRules.update`, `sites.webRules.destroy`, `sites.ipAccess` | read and change |
| see or change a site's repository, branch and deploy settings, rotate the push-to-deploy URL, or disconnect Git | `sites.git`, `sites.git.update`, `sites.git.deploy`, `sites.git.push-deploy-url.regenerate`, `sites.git.disconnect`, `servers.git.deploy-keys.index` | read and change |
| see which security patches or vulnerabilities apply, apply a patch, or set automatic security updates | `vulnerabilities.index`, `servers.securityPatches.index`, `servers.securityPatches.apply`, `servers.securityUpdate.show`, `servers.securityUpdate.update`, `servers.vulnerability-settings.show`, `vulnerabilities.fix` | read and change |
| turn on Release Mode (zero-downtime, atomic releases) for a Git site, keep its uploads and data across releases, deploy, check the switch and roll back | `servers.sites.git.create`, `sites.release-mode.enable`, `sites.release-mode.show`, `sites.release-mode.update`, `sites.git.deploy`, `sites.status`, `sites.release-mode.rollback`, `sites.release-mode.disable` | read and change |
| put a folder of files (a static site, a PWA build) or a single file on an xCloud site | `servers.sites.git.auto`, `servers.sites.blank.create`, `sites.files.index`, `sites.files.content.update`, `sites.files.content.show`, `sites.git.deploy`, `sites.files.destroy`, `sites.ssh.update`, `sites.ssh.show` | read and change |
| diagnose a legitimate web request blocked by a site's 7G or 8G web application firewall and apply a narrow tested exception | `sites.show`, `sites.access-logs` | read only |
<!-- facts:capability-api:end -->

## Dashboard-only jobs

<!-- facts:capability-dashboard:start -->
| Job | Where in the dashboard |
|---|---|
| Installing n8n, Supabase, Nextcloud, Mautic, LibreChat, Open WebUI, Ollama, Umami, WireGuard, phpMyAdmin and Site.pro | **Server → Sites → Create → One-Click Apps — these are native site types with no API installer, although catalog.apps.index lists them** |
| Turning on or syncing a server's provider backup (billed) | **Server → Backup** |
| Restoring an archived server (billed) | **Account → Archived Servers** |
| Applying backup settings to many sites at once | **Account → Global Settings → Site Backup** |
| Finishing a Google Drive or pCloud connection (browser sign-in) | **Account → Integrations → Storage Provider** |
| Connecting a server from your own cloud provider | **Servers → Create server → Bring and Manage Your Own Server** |
| Enrolling a self-managed server | **Servers → Create server → Bring and Manage Your Own Server** |
| Changing or cancelling a subscription | **Account → Subscriptions** |
| Pushing staging to production or pulling production to staging | **Site → Manage Staging (on the staging site)** |
| Staging hook scripts | **Site → Manage Staging → Hook Scripts** |
| Payment history and refunds | **Account → Billing → Bills & Payment** |
| Adding, replacing or removing a payment method | **Account → Billing → Bills & Payment** |
| Changing, upgrading, downgrading or cancelling a plan | **Account → Billing → Bills & Payment** |
| Downloading a printable invoice PDF | **Account → Billing → Invoices** |
| Adding the mailbox DNS records | **the domain's own DNS host or registrar, not xCloud** |
| Refunding a mailbox or mail delivery purchase | **Account → Billing → Bills & Payment** |
| Adding or replacing the card these purchases charge | **Account → Billing → Bills & Payment (Payment Methods)** |
| Resizing a server | **Server → Management → Settings → Upgrade Server** |
| Approving a server delete | **Server → Management → Settings → Delete your Server (over MCP the delete is only requested; approve it in the browser)** |
| Creating, editing or deleting supervisor processes | **Server → Management → Supervisor** |
| 7G/8G exceptions | **Site → Tools → Nginx Customization** |
| Uploading a whole folder from the browser | **Site → File Manager** |
| Create an API token, or grant more teams to a token or connection | **Account → Developers → API Tokens** |
<!-- facts:capability-dashboard:end -->

## Jobs xCloud refuses

<!-- facts:capability-refused:start -->
| Job xCloud refuses | Why |
|---|---|
| deploy a second site onto an OpenClaw, Paperclip, Hermes or DeepSeek Harness server | agentic stacks host only the site created during provisioning (adding another site is refused) |
| install a one-click app on an agentic server (OpenClaw, Paperclip, Hermes, DeepSeek Harness) | those servers host only the site created during provisioning |
| restore a PostgreSQL site into another or a new site | PostgreSQL sites are restored in place only, from their own backups |
| connect a customer's own cloud provider account, or adopt a server they already own, through the API | provider connection and self-managed enrolment are dashboard flows. servers.store provisions a NEW xCloud-managed Vultr server and has no adopt path |
| add any second site to an OpenClaw, Paperclip, Hermes or DeepSeek Harness server | those are the agentic (AI agent) stacks, and they host only the site created automatically during provisioning. Adding a site is refused for every agentic stack, in the dashboard as well as the API — this is not a permission that can be granted. The status code varies by endpoint (WordPress create answers 403, others 422), so match on the message rather than the code. |
| clone an agentic server | cloning copies sites onto another server, which the agentic stacks do not allow |
| publish a compose service on host port 80 or 443 | xCloud's own nginx owns 80/443 on an Nginx server and terminates TLS; `port` below 1024 is a 422. Remap to a free high host port |
| pull an image from a private container registry | the Docker deploy never runs `docker login` and the API has no registry-credential field; build the image from source in the repository or make it public |
| change a plan or add, replace or remove a payment method through the API | those are still dashboard actions. Billing is no longer read-only, though: payments.pay settles an outstanding invoice against the card already on file |
| block a CIDR range through fail2ban | the ban call accepts single IPv4/IPv6 addresses only; a range is a deny firewall rule |
| take a full server image snapshot through the API | servers.snapshots lists site snapshots from the server's sites; it is not a server image |
<!-- facts:capability-refused:end -->

Migration of an existing WordPress site or a whole server is a dashboard
wizard or the migration plugin, run after the destination site exists.

## Status codes are not uniform — match on `errors.code`

The same kind of refusal can come back as `403` on one endpoint and `422` on
another, and a `403` is not always a missing permission. Branch on `errors.code`
where the response carries one (it is the stable field), then on the `message`,
never on the status code alone. A refusal can also carry `errors.next_actions`
and `errors.dashboard_url`: use those instead of guessing:

| Situation | Status | What the response says |
|---|---|---|
| WordPress create on an agentic server | `403` | "OpenClaw servers support only one site, created automatically during provisioning" (OpenClaw) or "Agentic servers support only the site created automatically during provisioning" |
| Git create or auto-deploy on an agentic server | `403` | "Agentic servers support only the site created during provisioning" |
| Docker deploy (`servers.sites.git.docker`) on any non-Docker server, agentic included | `422` | `errors.code: incompatible_server` |
| One-click install on a server of the wrong stack | `422` | "This app requires a … server. This server is on the … stack." |
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
