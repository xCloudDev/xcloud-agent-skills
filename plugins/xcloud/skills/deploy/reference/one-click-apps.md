# One-click apps

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · scopes `read:sites` to browse,
`write:servers` to install, `write:sites` for lifecycle actions.

| Operation | Operation id | Method + path |
|---|---|---|
| Browse the catalog | `oneclickApps.index` | `GET /oneclick-apps?search=…` |
| One app's install form | `oneclickApps.show` | `GET /oneclick-apps/{slug}` |
| Will it fit this server? | `oneclickApps.compatibility` | `GET /servers/{uuid}/oneclick-apps/{slug}/compatibility` |
| Install | `oneclickApps.install` | `POST /servers/{uuid}/sites/oneclick/{slug}` |
| Install progress | `oneclickApps.status` | `GET /sites/{uuid}/oneclick/status` |
| Login details | `oneclickApps.credentials` | `GET /sites/{uuid}/oneclick/credentials` |
| Start / stop / restart / redeploy | `oneclickApps.lifecycle` | `POST /sites/{uuid}/oneclick/{action}` |
| Public app facts (stacks, minimum size) | `catalog.apps.index` | `GET /catalog/apps` |

## Flow

1. **Find the app.** `oneclickApps.index` with `search` (the catalog holds
   hundreds of apps; most run on a `docker_nginx` server). An empty catalog means
   it has not been synced on that environment — never answer "that app does not
   exist" from an empty list.
2. **Read its form.** `oneclickApps.show` returns the `fields` the install takes;
   `auto_generated` fields can be omitted. Apps that need a domain take
   `domain_parking_method`: `staging_env` (a free xCloud hostname) or `go_live`
   (with the full `name`).
3. **Pick the server** the user named, or list servers and let them choose
   (never silently). Run `oneclickApps.compatibility`: it checks stack, runtime,
   server state, billing, and RAM/CPU/disk against the latest monitoring
   snapshot. `monitor_available: false` means the resource check was
   **skipped**, not passed — say it was inconclusive. A server that is too small
   stays too small: suggest a larger server rather than retrying.
4. **Approve and install.** Restate app, server and address; on yes send
   `title` + `fields` (+ domain block) with `confirm: true` on MCP and an
   `Idempotency-Key` (`XCLOUD_IDEMPOTENCY_KEY` on REST).
5. **Poll** `oneclickApps.status` every 5–10 seconds until `is_terminal`. A
   failure names its `failed_phase` (`pre_install`, `install`, `post_install`,
   `provisioning`).
6. **Hand over.** Give the URL. Fetch credentials only when the user asks, show
   them once in the reply (never in a summary, log, or later message), and tell
   the user to store them in a password manager.

```bash
SERVER_UUID='replace-me'
"$XC" GET "/oneclick-apps?search=ghost&per_page=5" | jq '.data.items | map({slug, name, requirements})'
"$XC" GET "/servers/$SERVER_UUID/oneclick-apps/ghost/compatibility" | jq '.data'
KEY=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')   # keep it: a retry must reuse this key
jq -n '{title:"Ghost blog", domain_parking_method:"staging_env", fields:{}}' \
  | XCLOUD_IDEMPOTENCY_KEY="$KEY" "$XC" POST "/servers/$SERVER_UUID/sites/oneclick/ghost" - \
  | jq '.data | {site_uuid, installation_status, status_url}'
```

## Dashboard-only apps

The catalog lists some apps whose install form answers `404` on the API — n8n,
Supabase, Nextcloud, Mautic, LibreChat, Open WebUI, Ollama, Umami, WireGuard,
phpMyAdmin and Site.pro at the time of writing. For those, check the server fits
(a server that meets the app's minimum size), then point the user to
**Server → Sites → Create → One-Click Apps** in the dashboard. Use
`xcloud_docs_search` for the app's own setup guide and price facts.

## Lifecycle

`oneclickApps.lifecycle` is synchronous and destructive-class: `stop` takes the
app offline, `redeploy` recreates its containers. Confirm first. It answers `422`
while an install is still running or after a failed install, and is rate-limited
to 30 requests a minute. Agentic servers (OpenClaw, Paperclip, Hermes, DeepSeek
Harness) never take a one-click app.
