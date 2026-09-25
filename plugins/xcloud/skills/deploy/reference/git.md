# Git deployments

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · scopes `read:servers` /
`write:servers` to create, `read:sites` / `write:sites` for everything after.

| Operation | Operation id | Method + path |
|---|---|---|
| Git deployment info | `sites.git` | `GET /sites/{uuid}/git` |
| Update deployment settings | `sites.git.update` | `PUT /sites/{uuid}/git` |
| Trigger manual deployment | `sites.git.deploy` | `POST /sites/{uuid}/git/deploy` |
| Deploy settings a deploy reads | `sites.deploy-config` | `GET /sites/{uuid}/deploy-config` |
| Change deploy settings, no deploy | `sites.deploy-config.update` | `PUT /sites/{uuid}/deploy-config` |
| Provision/deploy status | `sites.status` | `GET /sites/{uuid}/status` |
| Diagnose a failed deploy | `sites.deploy-diagnosis` | `GET /sites/{uuid}/deploy-diagnosis` |
| Retry a failed deploy | `sites.provision-retry` | `POST /sites/{uuid}/provision-retry` |
| Full output of one step | `sites.events.show` | `GET /sites/{uuid}/events/{task_uuid}` |
| Server-side repair | `sites.rescue` | `POST /sites/{uuid}/rescue` |
| Analyse a repository | `git.detect` | `POST /git/detect` |
| Scan a compose file | `git.compose-scan` | `POST /git/compose-scan` |
| Deploy from Git (auto-detect) | `servers.sites.git.auto` | `POST /servers/{uuid}/sites/git/auto` |
| Deploy from Git (explicit settings) | `servers.sites.git.create` | `POST /servers/{uuid}/sites/git` |
| Deploy to a Docker server (pinned) | `servers.sites.git.docker` | `POST /servers/{uuid}/sites/git/docker` |
| Staging hostname a create would mint | `servers.staging-hostname.suggest` | `GET /servers/{uuid}/staging-hostname?label=…` |
| Deploy keys: list, prepare | `servers.git.deploy-keys.index` · `.store` | `GET\|POST /servers/{uuid}/git/deploy-keys` |
| Deploy keys: verify, delete | `servers.git.deploy-keys.verify` · `.destroy` | `POST /servers/{uuid}/git/deploy-keys/{key_uuid}/verify` · `DELETE /servers/{uuid}/git/deploy-keys/{key_uuid}` |
| Connected Git providers and their repos | `integrations.git.index` · `.repositories` | `GET /integrations/git` · `GET /integrations/git/{provider_uuid}/repositories` |
| Does the domain resolve to the server yet? | `servers.dns.check` | `POST /servers/{server}/dns/check` |

The create URLs live under `/servers/…`, but the whole flow — create, poll,
diagnose, retry, redeploy — is owned here. On MCP, start with
`xcloud_agent_search` ("deploy a Node app from GitHub", "deploy a Docker
Compose app") — it returns this whole flow with every operation's body in one
response.

## REST fallback: the whole flow

```bash
SERVER_UUID='replace-me'
REPO='https://github.com/acme/app'
# 1. detect (side-effect free)
jq -n --arg r "$REPO" --arg s "$SERVER_UUID" '{repository_url:$r, server_uuid:$s}' \
  | "$XC" POST /git/detect - | jq '.data | {repository_access, detection, compatibility}'
# 2. preview (creates nothing)
jq -n --arg r "$REPO" '{repository:{url:$r}, dry_run:true}' \
  | "$XC" POST "/servers/$SERVER_UUID/sites/git/auto" - | jq '.data | {would_create, warnings}'
# 3. after the user approves the preview: same body, no dry_run, idempotent
KEY=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')   # keep it: a retry must reuse this key
NEW=$(jq -n --arg r "$REPO" '{repository:{url:$r}}' \
  | XCLOUD_IDEMPOTENCY_KEY="$KEY" "$XC" POST "/servers/$SERVER_UUID/sites/git/auto" -)
printf '%s' "$NEW" | jq '.data | {uuid, domain, type, poll_url}'
SITE_UUID=$(printf '%s' "$NEW" | jq -er '.data.uuid') \
  || echo "create failed or no response — list the server's sites, then retry with the same KEY"
# 4. poll until terminal
"$XC" GET "/sites/$SITE_UUID/status" | jq '.data | {deploy_state, terminal, current_step, poll_after_seconds}'
```

## Detect first

Call `git.detect` with the `server_uuid` the human chose, so access and
compatibility are judged against that exact target — always, even when the
human says the repository is private or hands you a key. Send
`repository_url` for a public repo, or `provider_uuid` + `repository_full_name`
for a connected one. Branch on `repository_access`: `detection` is `null`
whenever the repository could not be read, and that is an access problem no
explicit app type bypasses. A public HTTPS repo reported `not_found` while
`git ls-remote` works is a probe failure, not a private repository.

Read `warnings[]` and surface them before deploying: `compound_start_command`
(a start command with `&&` or `cd` must be handed to a shell), `engines_node_mismatch`
(package.json `engines.node` does not cover the server's Node — change the
server default with `servers.node-versions.default`, there is no per-site
Node), `dot_directory_assets` (the build serves files from a dot-prefixed
directory such as Vite's `node_modules/.vite/` — on a Docker server send
`docker.allowed_dot_paths` with exactly the entries named), and
`no_package_json_at_root` (the app lives in a subdirectory).

Then deploy with `servers.sites.git.auto` — only `repository` is required; it
fills in every field you omit, on native and Docker servers alike. Reach for
`servers.sites.git.create` (nginx/OpenLiteSpeed) or `servers.sites.git.docker`
(Docker) only when the human gave you explicit values to pin, never as a way
around an access failure. An app that is not Node, PHP or static output (Go,
Rust, Python) deploys on a Docker server only.

## Dry run, then the real call

All four site-creation operations accept `dry_run: true`. It runs every check
the real call runs — validation, repository probe, detection, deploy key,
domain uniqueness, port check, the requested `node_version` against the
server, Cloudflare zone — and stops before persisting: `200` with
`data.dry_run: true`, `data.would_create` (type, serving mode, commands,
branch, hostname, port) and `warnings`, or the exact 4xx the real call would
answer. No `confirm`, no `Idempotency-Key`, nothing created. Show
`would_create` to the human and get the yes on that. Then send the **same**
body without `dry_run`, with `confirm: true` and an `Idempotency-Key`. Do not
change fields between the preview and the create.

`servers.staging-hostname.suggest` tells you the staging hostname a create
would mint for a label (and whether it is taken) when the human wants to know
the URL before creating anything.

## Private SSH repositories

A private repository with no connected git provider needs a deploy key:

1. `servers.git.deploy-keys.index` — a key may already be prepared, from an
   earlier conversation or attempt. **Never mint a second key for a repository
   whose key the human has already added.**
2. `servers.git.deploy-keys.store` — mints a key and returns the PUBLIC half
   only. The human adds it to the repository as a read-only deploy key.
3. `servers.git.deploy-keys.verify` with `repository_url` and `detect: true` —
   proves the key can clone (`errors.code: deploy_key_not_verified` when it
   cannot) and returns detection **and** the compose scan, the only scan a
   private SSH repository has.
   `compose.suggested_primary_port.host_port` is the `port` a Compose deploy
   needs.
4. Deploy, passing the key as `repository.deploy_key_uuid` next to the SSH
   `repository.url`.

## Which compose file xCloud runs

xCloud does **not** search for a compose file at deploy time.
`docker.compose_file` defaults to `docker-compose.yml` at the repository root,
the auto endpoint (`servers.sites.git.auto`) always uses that default, and the
server-side deploy stops with "file not found in repository root" when it is
missing. So a repository whose file is `compose.yaml`, `compose.yml` or
`docker-compose.yaml`, or lives in a subdirectory, must deploy through
`servers.sites.git.docker` with `docker.compose_file` set explicitly.

`git.detect` looks at the repository **root** only (a `Dockerfile` or one of
the four compose names). `git.compose-scan` is where the name gets resolved:
send `compose_file` (a file, or a directory); when that file is missing it tries
`compose.yaml`, `compose.yml`, `docker-compose.yml`, `docker-compose.yaml` in
that order, says which one it scanned in `warnings`, and returns
`compose_file_resolved`. **Read `compose_file_resolved` back and send exactly
that path as `docker.compose_file`** — never the name you guessed. The
deploy-key verify response's `compose` block carries the same field for a
private SSH repository.

The pinned `servers.sites.git.docker` dry run does not probe whether an HTTPS
repository is reachable (it only proves an SSH URL with a deploy key), so a
private HTTPS URL passes the preview and fails at clone — run `git.detect`
first, always.

## Docker Compose host ports

Run `git.compose-scan` before a Docker deploy — never guess the port. xCloud
runs the repository's own compose file as-is and proxies to the host port that
file publishes; it never rewrites the `ports:` mapping, and its nginx already
owns 80/443. So `port` must be:

- **free on the server** — a port another site or an unmanaged process already
  holds is refused with `errors.code: port_unavailable`;
- **published by the file** — a port it does not publish is refused with
  `port_not_published`, and `errors.published_ports` lists the ones it does.

A `${PORT:-8080}:8080` mapping is resolved against the `env_file_content` you
send, exactly as `docker compose up` reads it — which is how two apps with the
same default port share one server. When the file cannot be read (private repo,
rate-limited host) the port is accepted and `warnings` say it was not checked.

## Cloudflare-managed domains: the four refusals

`cloudflare: true` on a live domain lets xCloud write the proxied DNS record and
issue the certificate itself — never add the A record by hand on this path. It
is refused with `422` before anything is created, identically in a dry run, on
the WordPress, Git and Docker creates alike. Branch on `errors.code`:

| `errors.code` | Means | Do |
|---|---|---|
| `cloudflare_zone_not_found` | The domain's zone is not on a Cloudflare account connected to this team | Connect the account (`integrations.cloudflare.index` shows what is connected) or drop the flag |
| `cloudflare_ssl_unsupported_domain` | Two or more labels below the apex (`a.b.example.com`) | Use a one-label subdomain, or the `xcloud` certificate provider |
| `cloudflare_ssl_provider_conflict` | `cloudflare: true` with `ssl_provider: custom`, or `ssl_provider: cloudflare` without the flag | Make the two agree |
| `cloudflare_zone_lookup_failed` | Cloudflare could not be asked — **not** "no zone" | Retry later; do not tell the user the zone is missing |

After the `202`, `servers.dns.check` reports `cloudflare_managed` and the next
action, and `sites.status` → `ssl.serving_blocked: true` means visitors get a
`526` even though the deploy succeeded.

## Polling

Poll `sites.status` every ten seconds (or after `poll_after_seconds`) and
branch on `deploy_state` only — never on `status` or `migration_status`:

- `in_progress` — `terminal` is `false`; wait and poll again. A
  `progress_percentage` that sits still for a minute during a package install
  is not a stall; `current_step` names what is running.
- `deployed` / `failed` / `cancelled` — `terminal` is `true`; stop.

`failed_steps` lists provisioning steps whose latest attempt failed and was not
recovered; on a `deployed` site that means "succeeded, but verify". A site
being deleted reports `in_progress` until the endpoint answers 404 — that 404
is the completion. A staging hostname's DNS record lands a minute or two
after the 202, so never read an early NXDOMAIN as a failure. And `deployed`
means the deploy chain finished, not that the application answers: fetch the
site URL before reporting it live. Read the `ssl` block too —
`serving_blocked: true` means every visitor gets a 526 even though the deploy
succeeded. On a Docker site a 403 on a dot-prefixed path is the dot-path
allowlist, fixed with `docker.allowed_dot_paths` via
`sites.deploy-config.update` (vhost regenerated, no rebuild), not a redeploy.

If you must stop before the state is terminal, say the deploy is **still
running**, hand over the `poll_url` from the 202, and do not call it deployed.

## When a deploy fails

1. `sites.deploy-diagnosis` — read it before touching the events by hand. It
   returns the `failed_step` (name, exit code, redacted `output_tail`), a
   deterministic `classification` (`repository_access`, `dependency_install`,
   `build_failed`, `web_root_missing`, `start_command`, `port_conflict`,
   `runtime_version`, `env_missing`, `docker_build`, `compose_invalid`,
   `provisioning_prerequisite` or `unknown`), a one-sentence `explanation`
   safe to show a human, `correctable_fields` narrowed to what this site type
   accepts, and `next`: `retry`, `redeploy`, `rescue`, `recreate` or
   `support`. For `unknown`, `correctable_fields` is the site's full field
   list, not a suggestion — read `output_tail` first.
2. `sites.provision-retry` on the **same** site — do not delete and recreate a
   site whose deploy failed; it keeps its domain, port and database. Send only
   the fields named in `correctable_fields` as `corrections` (omit it for a
   plain retry), describe what will change, get the human's approval (on MCP
   `confirm: true`), and pass an `Idempotency-Key`. A native deploy resumes
   from the failed step (a branch or env change re-clones); a Docker deploy
   re-runs its install in full. `202` with `attempt_id`, `resume_from_step`,
   `applied_corrections` and `poll_url`; `409` while a deploy or another retry
   runs; `422` unless `deploy_state` is `failed` or when a field is not
   correctable (`site_type`, `repository`, `domain` and `database` never are —
   `next: recreate` means a new site).
3. Poll `sites.status` again until `terminal`.

`next: rescue` is a server-side repair (`sites.rescue`: a stuck process, file
permissions), not a settings change. `sites.events.show` returns one step's
full output (up to 20 KB, credential-redacted) when the tail is not enough.
`sites.deploy-config` shows the values that produced the failure;
`sites.deploy-config.update` changes settings without deploying anything, so
it never fixes a broken site on its own. `deploy_script_fail_fast` lives there:
new sites stop their deploy script at the first failing command, while a site
created before the setting existed reports `false` until someone turns it on.

`sites.git.deploy` is for shipping a new commit to a site that is already
live — it replaces what is serving, so it is destructive. It is not the
recovery path for a failed deploy.

## Managing an existing site

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/git" | jq '.data'
"$XC" PUT "/sites/$SITE_UUID/git" '{"git_branch":"main","enable_push_deploy":true}' | jq '.data'
"$XC" GET "/sites/$SITE_UUID/deploy-config" | jq '.data'
"$XC" POST "/sites/$SITE_UUID/git/deploy" | jq '.message'
"$XC" GET "/sites/$SITE_UUID/status" | jq '.data | {deploy_state, terminal, poll_after_seconds}'
"$XC" GET "/sites/$SITE_UUID/deploy-diagnosis" | jq '.data | {classification, explanation, correctable_fields, next}'
```

`git_branch` is required on the update; every other field keeps its current
value when omitted.

Safety: read current settings before writes; restate the site, branch,
push-deploy setting, script behavior and restart intent before updating; and warn
before running deployment scripts that include migrations, cache clears, service
restarts, or anything else that can change production behavior.
