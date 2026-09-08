# One-click apps

`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · MCP tools first · scope
`read:sites` / `read:servers` for the reads, `write:servers` to install,
`write:sites` for lifecycle actions.

One-click apps are pre-packaged applications (n8n, Uptime Kuma, Mautic,
Nextcloud, phpMyAdmin, Supabase, …) that xCloud installs as a site on an
existing server. **Creating one is a site create, so it happens against a
server**; everything afterwards is addressed by the new site's `uuid`.

| Step | MCP tool | Method + path |
|---|---|---|
| 1. Browse the catalog | `oneclickApps_index` | `GET /oneclick-apps` |
| 2. Read one app's install form | `oneclickApps_show` | `GET /oneclick-apps/{slug}` |
| 3. Check it fits the chosen server | `oneclickApps_compatibility` | `GET /servers/{uuid}/oneclick-apps/{slug}/compatibility` |
| 4. Install (async) | `oneclickApps_install` | `POST /servers/{uuid}/sites/oneclick/{slug}` |
| 5. Poll until terminal | `oneclickApps_status` | `GET /sites/{uuid}/oneclick/status` |
| 6. Fetch connection details | `oneclickApps_credentials` | `GET /sites/{uuid}/oneclick/credentials` |
| 7. Start / stop / restart / redeploy | `oneclickApps_lifecycle` | `POST /sites/{uuid}/oneclick/{action}` |

These operations are in the Public API spec, so the MCP generates a tool for
each. If a connected server does not list them, its deploy predates them — use
`$XC` for those calls and say so rather than telling the user the feature is
missing.

## The flow

Read the app's schema before building the install body. `fields` describes what
`fields.*` accepts; entries marked `auto_generated: true` may be omitted and
xCloud generates a value. `needs_domain` says whether the domain block is
required.

```bash
"$XC" GET "/oneclick-apps?per_page=100" | jq '(.data.items // []) | map({slug, name, category, service_class, min_ram_mb: .requirements.min_ram_mb})'
"$XC" GET "/oneclick-apps/n8n" | jq '.data | {needs_domain, service_class, fields: (.fields | map({key, required, auto_generated}))}'
```

Compatibility is advisory — runtime, stack, service class, server state,
billing and RAM/CPU/disk against the latest monitoring snapshot. Install
re-runs every gate regardless, and when `monitor_available` is false the
resource checks are simply omitted:

```bash
SERVER_UUID='replace-me'
"$XC" GET "/servers/$SERVER_UUID/oneclick-apps/n8n/compatibility" | jq '.data'
```

Install **provisions a real, billable site** — describe the app, the target
server and the domain, get explicit approval, then call it (on MCP, with
`confirm: true`). It returns `202`. This is one of the four operations that
accept an idempotency key, so send one and reuse it on every retry: on MCP pass
`idempotency_key`; over REST send an `Idempotency-Key` header with `curl`, since
the bundled wrapper cannot set headers. Rate limit: 10 installs/minute.

```bash
IDEMPOTENCY_KEY="$(cat /proc/sys/kernel/random/uuid)"
BASE="${XCLOUD_API_BASE_URL:-https://app.xcloud.host}"
printf '%s' '{"title":"Automation","domain_parking_method":"go_live",
  "name":"automation.example.com","ssl_provider":"xcloud","fields":{}}' \
| curl -fsS -X POST "$BASE/api/v1/servers/$SERVER_UUID/sites/oneclick/n8n" \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -H "Idempotency-Key: $IDEMPOTENCY_KEY" --data-binary @- | jq '.data'
```

Without a key, the wrapper form works for a one-shot install:

`title` is the only always-required field. When the app's schema says
`needs_domain: true`, add `domain_parking_method` — `go_live` (with `name` as
the full domain, optionally `ssl_provider: "xcloud"`) or `staging_env` (with
`selected_staging_domain`, and `name` as a bare label with no dots):

```bash
# live domain
"$XC" POST "/servers/$SERVER_UUID/sites/oneclick/n8n" '{
  "title": "Automation",
  "domain_parking_method": "go_live",
  "name": "automation.example.com",
  "ssl_provider": "xcloud",
  "fields": {}
}' | jq '.data'

# data-service app with no domain (e.g. PostgreSQL)
"$XC" POST "/servers/$SERVER_UUID/sites/oneclick/postgresql" '{"title":"My Postgres","fields":{}}' | jq '.data'
```

Keys not declared in the app's schema are ignored, and fields marked
`auto_generated: true` can be omitted.

Poll status no more than once every 5 seconds and stop when `is_terminal` is
true. `installation_status` tracks the app, `site_status` tracks the site's own
provisioning — read both. On failure, `failed_phase` is one of `pre_install`, `install`,
`post_install`, or `provisioning` (the app installed but a follow-up step such
as SSL failed) — report it with `error` rather than retrying blindly.

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/oneclick/status" | jq '.data | {installation_status, site_status, percentage, is_terminal, failed_phase, error}'
```

Credentials are available only once the install is operational (`installed`,
`running` or `stopped`); they return `422` while installing or after a failure.
**They are live secrets** — fetch them only when asked or right after an
install, never echo them into a summary, and never log them.

Lifecycle actions are synchronous, limited to 30/minute, and take one of
`start`, `stop`, `restart`, `redeploy`:

```bash
"$XC" POST "/sites/$SITE_UUID/oneclick/restart" '{}' | jq '.message'
```

`stop` takes the app offline and `redeploy` recreates its containers — both
need explicit confirmation naming the site.

## Which apps run where

Read `supported_stacks` and `requirements` off `catalog_apps_index`
(`GET /catalog/apps`) rather than assuming. The catalog is computed from the
same resolvers as the New Site form, so it is the authority on whether an app
is a native site type, a one-click app, or a template. n8n, for example, is
listed there as a `one_click` app whose entry point is the one-click create
flow — not as a hand-rolled Node or Docker deployment.

Agentic servers (OpenClaw, Paperclip, Hermes, DeepSeek Harness) accept no new
sites at all, one-click included — see the capability map in
`reference/capabilities.md`.
