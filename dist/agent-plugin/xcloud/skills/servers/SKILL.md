---
name: servers
description: Manage xCloud servers — list/inspect servers, monitoring, services, tasks, reboot, snapshots, sudo users, PHP versions, server cron jobs, firewall rules, fail2ban, DNS checks, Git deploy keys, and provisioning new sites onto a server (WordPress, Git-deployed PHP/Node/Docker apps, one-click apps). Also covers how to buy or connect a server and which server stacks allow what. Use for any server-level infrastructure or server security (firewall/fail2ban) request. NOT site-level config (see sites), NOT SSL certs (see ssl), NOT WordPress app management (see wordpress).
---

# xCloud Servers

Owns server infrastructure and server-level security. Read the shared layer
first for auth, base URL, envelope, pagination, and rate limits:

- `references/shared/auth.md`
- `references/shared/conventions.md`
- `references/shared/capabilities.md` — **what is API-covered,
  what is dashboard-only, and what xCloud refuses outright**; read it before
  planning a multi-step job.
- `references/shared/mcp.md` — **prefer `servers_*` MCP
  tools when connected** (e.g. `servers_index`, `servers_show`, `servers_reboot`,
  `servers_sites_wordpress_create`, `servers_sites_git_auto`); on the compact
  `/mcp/v2` surface the same operations run through `xcloud_execute_*` by
  operation id. The `$XC` calls below are the REST fallback.

Resolve the absolute directory that contains this `SKILL.md` before running
shell commands. Do not resolve scripts from the user's current working directory:

```bash
SKILL_ROOT="/absolute/path/to/this/skill"
XC="$SKILL_ROOT/scripts/xcloud.sh"
```

Scopes: reads need `read:servers`, writes need `write:servers`.

## Response format

Brand every user-facing reply (see `references/shared/conventions.md` →
**Response format**): open with `☁️ **xCloud · Servers** — <server>`, give the
trimmed result, and close with a `_via xCloud/servers_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching server \`<name>\`…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Creating…" or "Provisioning…". Say `xCloud is creating…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `references/shared/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

Big domain — detailed per-sub-resource guidance lives in `references/domain/`:

| Sub-resource | Reference file |
|---|---|
| Buying/connecting a server, stacks, catalog & pricing | `references/domain/provisioning.md` |
| PHP versions (install, default, opcache, patch) | `references/domain/php-versions.md` |
| Server cron jobs (CRUD, execute, output) | `references/domain/cron-jobs.md` |
| Databases & database users ⚠️ _(deprecated — withheld from the API, see file)_ | `references/domain/databases.md` |
| Firewall rules, fail2ban, IP whitelisting | `references/domain/firewall.md` |
| Sudo users | `references/domain/sudo-users.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| List servers | `GET /servers` |
| Get server | `GET /servers/{uuid}` |
| List sites on server | `GET /servers/{uuid}/sites` |
| Monitoring | `GET /servers/{uuid}/monitoring` |
| Monitoring history | `GET /servers/{uuid}/monitoring/history` |
| Services | `GET /servers/{uuid}/services` |
| Restart a service | `POST /servers/{uuid}/services/restart` |
| Disable a service | `POST /servers/{uuid}/services/disable` |
| Recent tasks | `GET /servers/{uuid}/tasks` |
| Snapshots | `GET /servers/{uuid}/snapshots` |
| Supervisor processes | `GET /servers/{uuid}/supervisor-processes` |
| Reboot server | `POST /servers/{uuid}/reboot` |
| Check a domain's DNS against the server | `POST /servers/{server}/dns/check` |
| Create WordPress site on server | `POST /servers/{uuid}/sites/wordpress` |
| **Create Git-deployed site (auto-detect)** | `POST /servers/{uuid}/sites/git/auto` |
| Create Git-deployed site (explicit, nginx/OLS) | `POST /servers/{uuid}/sites/git` |
| Create Git-deployed site (Docker, pinned config) | `POST /servers/{uuid}/sites/git/docker` |
| Analyse a repository before deploying | `POST /git/detect` |
| Prepare / verify / delete a deploy key | `POST /servers/{uuid}/git/deploy-keys` · `POST /servers/{uuid}/git/deploy-keys/{key_uuid}/verify` · `DELETE /servers/{uuid}/git/deploy-keys/{key_uuid}` |
| Check a one-click app against this server | `GET /servers/{uuid}/oneclick-apps/{slug}/compatibility` |
| Install a one-click app | `POST /servers/{uuid}/sites/oneclick/{slug}` |

**Not here:** site settings → the `sites` skill; SSL → the `ssl` skill; WordPress
plugins/themes/updates → the `wordpress` skill.

## Common reads

List servers:

```bash
"$XC" GET "/servers?per_page=100" \
  | jq '(.data.items // .data.data // []) | map({uuid, name, status, ip: (.ip_address // .ip)})'
```

One server + its monitoring:

```bash
SERVER_UUID='replace-me'
"$XC" GET "/servers/$SERVER_UUID" | jq '.data'
"$XC" GET "/servers/$SERVER_UUID/monitoring" | jq '.data'
```

Recent tasks (use after any async write to confirm progress):

```bash
"$XC" GET "/servers/$SERVER_UUID/tasks" | jq '(.data.items // .data) | map({uuid, type, status, created_at})'
```

## Common writes

Reboot (async — poll tasks afterward):

```bash
"$XC" POST "/servers/$SERVER_UUID/reboot" | jq '.message'
```

Restart a service:

```bash
"$XC" POST "/servers/$SERVER_UUID/services/restart" '{"service":"nginx"}' | jq '.message'
```

Disable a service (synchronous; can take a service offline):

```bash
"$XC" POST "/servers/$SERVER_UUID/services/disable" '{"service":"redis"}' | jq '.message'
```

Before disabling, xCloud must confirm the exact server, service name, and impact
with the user. Accepted `service` values include `mysql`, `mariadb`,
`postgresql`, `nginx`, `redis`, `php`, `ssh`, `supervisor`, `docker`, `lsws`,
`nodejs`, `openclaw`, `paperclip`, and `hermes`. For PHP services, pass
`version` when the server has multiple PHP versions.

Create a WordPress site on the server (live mode needs `domain` + `ssl`; omit
`domain` for demo). `blueprint_uuid` and `snapshot_uuid` are mutually exclusive;
auto-generated credentials are returned only once.

```bash
"$XC" POST "/servers/$SERVER_UUID/sites/wordpress" '{
  "mode": "live",
  "domain": "example.com",
  "title": "My Site",
  "php_version": "8.2",
  "ssl": {"provider": "letsencrypt"},
  "cache": {"full_page": true, "object_cache": true}
}' | jq '.data'
# then poll site provisioning:  GET /sites/{new_uuid}/status   (sites)
```

## Deploy an app from Git

The whole flow lives on this skill because every call is server-scoped (plus
the global `git_detect`). Prefer `servers_sites_git_auto` — it works on
nginx/OpenLiteSpeed **and** Docker servers and fills in anything you omit.

**1. Pick the server.** If the user named one, use it. Otherwise list servers
and let them choose — never pick silently.

```bash
"$XC" GET "/servers?per_page=100" | jq '(.data.items // []) | map({uuid, name, stack, status})'
```

**2. Analyse the repository** (`git_detect` — side-effect-free, creates
nothing). Pass `server_uuid` so compatibility is judged against that exact
target; a Docker server answers with `compatibility.docker_deployable: true`.

```bash
"$XC" POST /git/detect '{
  "repository_url": "https://github.com/acme/app",
  "server_uuid": "'"$SERVER_UUID"'",
  "include_deploy_script": true
}' | jq '.data | {reachable, default_branch, site_type: .detection.site_type, serving_mode: .detection.serving_mode, compatibility, access: .repository_access.status, access_code: .repository_access.code, next_actions: .repository_access.next_actions}'
```

Branch on `repository_access.code`, never on prose. Show the human the detected
`detection.site_type` and the target domain, and clear every entry in
`repository_access.next_actions` before deploying. On a Docker server
`compatibility.compatible` is false for the native Git endpoints while
`compatibility.docker_deployable` is true — that is not a dead end, it means
the Docker path (`deploy_via: docker_compose`).

**3. Private repository?** Two supported paths — a **connected provider** or a
**deploy key**. A private `git@…` SSH URL with neither is rejected.

- *Connected provider*: resolve `provider_uuid` and `full_name` through
  the `account` skill (`integrations_git_index`, then
  `integrations_git_repositories`), and pass them as
  `repository.provider_uuid` + `repository.full_name`.
- *Deploy key*: `POST /servers/{uuid}/git/deploy-keys` mints a team key and
  returns **only the public half** (the private key never leaves xCloud). The
  human adds that public key to the repository as a read-only deploy key, then
  `POST /servers/{uuid}/git/deploy-keys/{key_uuid}/verify` clone-probes it —
  that call **requires** a `repository_url` body (and takes an optional
  `branch`). On success pass `repository.deploy_key_uuid` to the deploy call.
  A failed verify returns `errors.code = deploy_key_not_verified`.

```bash
"$XC" POST "/servers/$SERVER_UUID/git/deploy-keys" | jq '.data | {uuid, public_key, status, instructions}'
# human pastes the public key into the repo as a read-only deploy key, then:
KEY_UUID='replace-me'
"$XC" POST "/servers/$SERVER_UUID/git/deploy-keys/$KEY_UUID/verify" '{
  "repository_url": "git@github.com:acme/app.git"
}' | jq '.data | {verified, default_branch}'
```

Keys create persistent team key material, so a prepare is a write, not a read.
`DELETE /servers/{uuid}/git/deploy-keys/{key_uuid}` drops an **unadopted** key
(it is refused with `422` once a site uses it) and is destructive — confirm it.

**4. Deploy.** This **provisions a real, billable site** — get approval first,
and on MCP set `confirm: true`. Make the call idempotent so a retry never
creates a second site — this is one of the four operations that accept a key
(the three Git creates and the one-click install). On MCP pass
`idempotency_key`; over REST send an `Idempotency-Key` header. The bundled
wrapper cannot set headers, so use `curl` for the REST form, and reuse the
same key on every retry of the same request:

```bash
IDEMPOTENCY_KEY="$(cat /proc/sys/kernel/random/uuid)"
BASE="${XCLOUD_API_BASE_URL:-https://app.xcloud.host}"
printf '%s' '{"repository":{"url":"https://github.com/acme/app","branch":"main"},
  "domain":{"mode":"live","name":"app.example.com","ssl_provider":"xcloud"}}' \
| curl -fsS -X POST "$BASE/api/v1/servers/$SERVER_UUID/sites/git/auto" \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H "Idempotency-Key: $IDEMPOTENCY_KEY" --data-binary @- | jq '.data'
```

Without a key, the wrapper form is fine for a one-shot deploy:

```bash
"$XC" POST "/servers/$SERVER_UUID/sites/git/auto" '{
  "repository": {"url": "https://github.com/acme/app", "branch": "main"},
  "domain": {"mode": "live", "name": "app.example.com", "ssl_provider": "xcloud"}
}' | jq '.data'
```

Only `repository` is required; omit `domain` to get a staging hostname. Reach
for the explicit endpoints when the human gave you exact values:

- `POST /servers/{uuid}/sites/git` — nginx/OpenLiteSpeed, explicit `site_type`
  (`laravel`, `nodejs`, `custom-php`, `wordpress`, `lovable`). Node `ssr`/
  `hybrid` apps also need `start_command` + `port`. Atomic: a failure leaves no
  partial site.
- `POST /servers/{uuid}/sites/git/docker` — Docker servers, to pin the compose
  file, Dockerfile path, host port or container port yourself.

**5. Confirm the deploy.** The **initial** deploy is not a redeploy, so it does
not appear in the deployment log — poll site status instead, and stop when
`terminal` is true:

```bash
SITE_UUID='replace-me'   # from the deploy response
"$XC" GET "/sites/$SITE_UUID/status" | jq '.data | {status, deploy_state, terminal, failed_steps, error_message}'
```

`sites_deployment-logs` (`GET /sites/{uuid}/deployment-logs`) lists the site's
deployment records (status, action, source and destination site, who started
it) — in practice the staging↔production push/pull deployments, not the git
pull of a first provision. Track a later manual git deploy with `sites_events`.

**6. Live domain not resolving yet?** A live-domain deploy returns a
`domain_setup` block. Poll `POST /servers/{server}/dns/check` with
`{"domain": "app.example.com"}` while the human updates DNS — one propagation
attempt per call, so poll rather than expecting a retry inside it:

```bash
"$XC" POST "/servers/$SERVER_UUID/dns/check" '{"domain":"app.example.com"}' \
  | jq '.data | {resolves_to_server, resolved_ips, cloudflare_proxy, next_actions}'
```

`cloudflare_proxy: true` means the record exists but is proxied (orange
cloud), which blocks certificate issuance.

Refusals to expect:

- **Agentic servers** (OpenClaw, Paperclip, Hermes, DeepSeek Harness) host only
  the site created during provisioning. The WordPress and native/auto Git
  endpoints return `403`; the Docker endpoint returns `422` (an agentic server
  is not a Docker server) and a one-click install is stopped by the
  compatibility gate with a `422` stack failure. No workaround.
- `POST /servers/{uuid}/sites/git` returns `422` on a Docker server, pointing
  at the Docker endpoint; `…/git/docker` returns `422` on a non-Docker server.
- `POST /servers/{uuid}/sites/wordpress` returns `422` on a Docker server —
  WordPress is not supported there.
- Any create returns `402` when the team is at its site limit.

## Pitfalls

- Many server writes are asynchronous — a reboot, a PHP install, a site
  create — and return success before the work completes; poll
  `GET /servers/{uuid}/tasks` (or the site's status) for those. Others are
  synchronous (service restart/disable, deploy-key verify, DNS check) and their
  own response is the result. Poll what the operation says is async, not
  everything.
- Disabling `ssh`, `nginx`, database, runtime, agent, or queue services can cause
  lockout or downtime. Require explicit confirmation immediately before calling
  `POST /servers/{uuid}/services/disable`.
- Site creation (WordPress and Git) lives here (the URL is `/servers/...`), but
  the resulting site is then managed via the `sites` skill / the `wordpress` skill.
- `setting default PHP` and `patching PHP` do not enforce a `write:servers`
  scope line in the docs but still require server write permission in practice.
