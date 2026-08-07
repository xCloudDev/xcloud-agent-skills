# Server PHP versions

`XC="scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.

| Operation | Method + path | Body |
|---|---|---|
| List installed | `GET /servers/{uuid}/php-versions` | — |
| List available | `GET /servers/{uuid}/php-versions/available` | — |
| Patch info | `GET /servers/{uuid}/php-versions/patch-info` | — |
| Install | `POST /servers/{uuid}/php-versions` | `{"php_version":"8.3"}` |
| Uninstall | `DELETE /servers/{uuid}/php-versions` | `{"php_version":"8.1"}` |
| Set default | `POST /servers/{uuid}/php-versions/{version}/default` | — |
| Toggle OPcache | `POST /servers/{uuid}/php-versions/{version}/opcache` | `{"enabled":true}` |
| Patch | `POST /servers/{uuid}/php-versions/{version}/patch` | — |

```bash
SERVER_UUID='replace-me'
"$XC" GET "/servers/$SERVER_UUID/php-versions" | jq '.data'
"$XC" POST "/servers/$SERVER_UUID/php-versions" '{"php_version":"8.3"}' | jq '.message'
"$XC" POST "/servers/$SERVER_UUID/php-versions/8.3/default" | jq '.message'
"$XC" POST "/servers/$SERVER_UUID/php-versions/8.3/opcache" '{"enabled":true}' | jq '.message'
```

- `php_version` is required for install/uninstall.
- `enabled` is required for the opcache toggle.
- Install/patch are async — confirm via `GET /servers/{uuid}/tasks`.
