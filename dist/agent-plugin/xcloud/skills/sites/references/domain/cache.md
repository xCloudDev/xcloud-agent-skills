# Site cache

`XC="scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

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
