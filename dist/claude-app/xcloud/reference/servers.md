
# xCloud Servers

Owns server infrastructure and server-level security. Read the shared layer
first for auth, base URL, envelope, pagination, and rate limits:

- `reference/auth.md`
- `reference/conventions.md`
- `reference/mcp.md` — **prefer `mcp__xcloud__servers_*`
  tools when connected** (e.g. `servers_index`, `servers_show`, `servers_reboot`,
  `servers_sites_wordpress_create`, `servers_sites_git_create`); the `$XC` calls
  below are the REST fallback.

```bash
XC="scripts/xcloud.sh"
```

Scopes: reads need `read:servers`, writes need `write:servers`.

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · Servers** — <server>`, give the
trimmed result, and close with a `_via xcloud:servers_` line.

Narrate each call (see **Progress narration**): before every `$XC` call print one
line of what xCloud is doing, e.g. `☁️ xCloud is fetching server \`<name>\`…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Creating…" or "Provisioning…". Say `xCloud is creating…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

Big domain — detailed per-sub-resource guidance lives in `reference/`:

| Sub-resource | Reference file |
|---|---|
| PHP versions (install, default, opcache, patch) | `reference/servers-php-versions.md` |
| Server cron jobs (CRUD, execute, output) | `reference/servers-cron-jobs.md` |
| Databases & database users ⚠️ _(404 on the current API — see file)_ | `reference/servers-databases.md` |
| Firewall rules, fail2ban, IP whitelisting | `reference/servers-firewall.md` |
| Sudo users | `reference/servers-sudo-users.md` |

## Core endpoints

| Operation | Method + path |
|---|---|
| List servers | `GET /servers` |
| Get server | `GET /servers/{uuid}` |
| List sites on server | `GET /servers/{uuid}/sites` |
| Monitoring (+ history) | `GET /servers/{uuid}/monitoring[/history]` |
| Services | `GET /servers/{uuid}/services` |
| Restart a service | `POST /servers/{uuid}/services/restart` |
| Disable a service | `POST /servers/{uuid}/services/disable` |
| Recent tasks | `GET /servers/{uuid}/tasks` |
| Snapshots | `GET /servers/{uuid}/snapshots` |
| Supervisor processes | `GET /servers/{uuid}/supervisor-processes` |
| Reboot server | `POST /servers/{uuid}/reboot` |
| Create WordPress site on server | `POST /servers/{uuid}/sites/wordpress` |
| **Create Git-deployed site on server** | `POST /servers/{uuid}/sites/git` |
| Analyse a repository before deploying (side-effect-free) | `POST /git/detect` |
| Detect-then-deploy a repository in one call | `POST /servers/{uuid}/sites/git/auto` |
| Deploy a repository to a Docker server with explicit container config | `POST /servers/{uuid}/sites/git/docker` |

**Not here:** site settings → `xcloud:sites`; SSL → `xcloud:ssl`; WordPress
plugins/themes/updates → `xcloud:wordpress`. Orchestrating a full
"deploy this project" request — syncing an uncommitted/local project into a
repo, running the sequence below, and verifying the live URL — is
`xcloud:deploy-app`; it calls these same endpoints rather than duplicating
them.

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
# then poll site provisioning:  GET /sites/{new_uuid}/status   (xcloud:sites)
```

Create a **Git-deployed site** — `site_type` is one of `laravel`, `nodejs`,
`custom-php`, `wordpress`, `lovable`. Atomic: if any step fails, no partial site
is left behind. Repository source is EITHER a connected provider
(`repository.provider_uuid` + `repository.full_name` — required for private
repos) OR a public HTTPS `repository.url`; private `git@…` SSH URLs are
rejected. `domain.mode` is `live` or `staging`; Node `ssr`/`hybrid` apps also
need `start_command` + `port`:

```bash
"$XC" POST "/servers/$SERVER_UUID/sites/git" '{
  "site_type": "custom-php",
  "repository": {"url": "https://github.com/acme/app.git", "branch": "main"},
  "domain": {"mode": "live", "name": "app.example.com", "ssl_provider": "xcloud"},
  "enable_push_deploy": false
}' | jq '.data'
# then manage deploys via xcloud:sites (reference/git.md):
#   PUT /sites/{uuid}/git · POST /sites/{uuid}/git/deploy
```

**Prefer detect-then-deploy** (`git/auto`) over the explicit form above unless
the exact `site_type`/build settings are already known — it resolves them from
the repository itself and routes a Docker server to the container path
automatically:

```bash
# Preview first — no mutation:
"$XC" POST "/git/detect" '{"repository_url": "https://github.com/acme/app.git", "server_uuid": "'"$SERVER_UUID"'"}' \
  | jq '.data | {repository_access, detection, compatibility, deploy_via}'

# Then deploy — everything but `repository` is optional:
"$XC" POST "/servers/$SERVER_UUID/sites/git/auto" '{
  "repository": {"url": "https://github.com/acme/app.git", "branch": "main"},
  "confirm": true
}' | jq '.data'
```

## Pitfalls

- Server writes are async; success is returned before work completes — poll
  `GET /servers/{uuid}/tasks`.
- Disabling `ssh`, `nginx`, database, runtime, agent, or queue services can cause
  lockout or downtime. Require explicit confirmation immediately before calling
  `POST /servers/{uuid}/services/disable`.
- Site creation (WordPress and Git) lives here (the URL is `/servers/...`), but
  the resulting site is then managed via `xcloud:sites` / `xcloud:wordpress`.
- `setting default PHP` and `patching PHP` do not enforce a `write:servers`
  scope line in the docs but still require server write permission in practice.
