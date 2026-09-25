# Server PHP versions

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.

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
- **Set default** changes the server's command-line `php` and the version new
  sites get. It moves **no existing site** — each site keeps its own PHP
  version, which only the dashboard changes (**Site → Site Settings**). When the
  version is not installed yet, the call installs it first (asynchronous).
- `enabled` is required for the opcache toggle.
- Install/patch are async — confirm via `GET /servers/{uuid}/tasks`.
