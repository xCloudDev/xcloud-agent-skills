# Site cache

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| Cache settings | `GET /sites/{uuid}/cache/settings` |
| Purge full-page cache | `POST /sites/{uuid}/cache/purge` |
| Purge all caches | `POST /sites/{uuid}/cache/purge-all` |

```bash
SITE_UUID='replace-me'
"$XC" GET  "/sites/$SITE_UUID/cache/settings" | jq '.data'
"$XC" POST "/sites/$SITE_UUID/cache/purge"     | jq '.message'   # full-page only
"$XC" POST "/sites/$SITE_UUID/cache/purge-all" | jq '.message'   # full-page + object + CDN
```

- `purge` clears the full-page cache; `purge-all` clears every cache layer.
- Async — confirm via `GET /sites/{uuid}/events`.
- `cache/settings` reads which layers are on (`page_cache`, `object_cache` with
  `redis` / `object_cache_pro`, `cloudflare_edge_cache`); **turning a layer on
  or off is dashboard-only (Site → WordPress → Caching)** — no operation enables one. A slow
  site or "should caching be on" → the `performance` skill.
