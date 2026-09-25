# Staging environments and new WordPress sites

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · scopes `write:sites` (staging),
`write:servers` (WordPress create).

| Operation | Operation id | Method + path |
|---|---|---|
| List a production site's staging environments | `sites.stagingSites` | `GET /sites/{uuid}/staging-sites` |
| Create a Git-backed staging environment | `sites.stagingSites.create` | `POST /sites/{uuid}/staging-sites` |
| Create a WordPress site | `servers.sites.wordpress.create` | `POST /servers/{uuid}/sites/wordpress` |
| Blueprints for a new WordPress site | `blueprints.index` | `GET /blueprints` |

## Staging from a branch (Git sites)

"Give me a staging copy of the API site from `feature/checkout`":

1. Resolve the **production** site (`sites.show`). Staging never nests: a
   staging or demo site's uuid answers `422` on both calls above — that means
   "not a production site", not "no staging".
2. Supported for Git-backed sites only (Laravel, Node.js, custom PHP,
   Lovable); WordPress staging is a dashboard action (**Site overview → Add Staging**).
   Needs a paid plan and the `site:deploy-staging` team permission.
3. Body: `environment_name` (lowercase, digits, hyphens), `branch`, `mode`.
   `demo` puts it on a free test hostname (`subdomain` + `demo_domain`
   optional); `live` needs `domain` (not a demo TLD) and `ssl`.
   `env_init_mode` seeds `.env` from production: `copy_keys` (keys, secrets
   blanked — the safe default), `copy_values`, or `empty`; database and Redis
   credentials are always the environment's own. `target_server_uuid` places it
   on another server (e.g. "not the production server").
4. A private repository with no connected provider needs a prepared, verified
   `deploy_key_uuid` (see `reference/git.md` → Private SSH repositories).
5. Restate branch, server, hostname and `.env` seeding, get the yes, send with
   `confirm: true` on MCP. `202` → poll the new site's `sites.status` exactly as
   a deploy, then fetch the URL before reporting it ready.

Pushing staging to production (or pulling production down) is dashboard-only
(on the staging site: **Site → Manage Staging**); `sites.deployment-logs` is where that
history is readable.

```bash
PROD_UUID='replace-me'
jq -n '{environment_name:"checkout", branch:"feature/checkout", mode:"demo", env_init_mode:"copy_keys"}' \
  | "$XC" POST "/sites/$PROD_UUID/staging-sites" - | jq '.data | {uuid, name, status}'
```

## New WordPress site

"Dry-run a WordPress site called Northwind on my Frankfurt server, then create
it":

1. Server: Nginx or OpenLiteSpeed only — WordPress is refused on Docker and
   agentic servers. Prefer a server whose `database_type` is not `none` (a
   server without one installs a database engine first; `database` picks it).
2. `mode: demo` → a free xCloud hostname; it refuses `domain`, `ssl`,
   `cloudflare` and `additional_domains`. `mode: live` needs `domain` + `ssl`.
   `ssl.provider` is `xcloud` (free Let's Encrypt, the default choice),
   `custom` (with `certificate` + `private_key`), or `cloudflare` (only with
   `cloudflare: true` on a connected zone). There is no `letsencrypt` value.
3. Optional: `blueprint_uuid` (from `blueprints.index`) **or** `snapshot_uuid`,
   never both; `php_version`, `wordpress_version`, `cache`.
4. Live domain not on Cloudflare → `servers.dns.check` first; the site cannot
   get its certificate until the domain resolves to the server.
5. Send `dry_run: true`, show `would_create`, get the yes, then the same body
   with `confirm: true` and an `Idempotency-Key`. Poll `sites.status`, fetch the
   URL, and offer a magic login (`xcloud:wordpress`). Auto-generated admin
   credentials are returned once — hand them over once, never repeat them.

```bash
SERVER_UUID='replace-me'
jq -n '{mode:"demo", title:"Northwind", dry_run:true}' \
  | "$XC" POST "/servers/$SERVER_UUID/sites/wordpress" - | jq '.data | {would_create, warnings}'
```
