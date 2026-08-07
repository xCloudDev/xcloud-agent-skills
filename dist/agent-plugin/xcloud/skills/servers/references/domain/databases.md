# Databases & database users

> **⚠️ Not available on the current public API.** As of 2026-06-29 every endpoint
> below returns **HTTP 404 "Resource not found"** on all tested servers — while
> sibling endpoints (`php-versions`, `firewall-rules`) return `200` on the same
> server — and none appear in the live OpenAPI spec. Treat this file as a
> forward-looking reference only; do not rely on these endpoints until the API
> exposes them. The `xcloud:servers` smoke suite already treats `databases` as an
> optional sub-resource (404 → SKIP). See `docs/API-COVERAGE.md`.

`XC="scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.

## Databases

| Operation | Method + path | Body |
|---|---|---|
| List | `GET /servers/{uuid}/databases` | — |
| Search | `GET /servers/{uuid}/databases/search?q=` | — |
| Create | `POST /servers/{uuid}/databases` | `{"database_name":"app_prod"}` |
| Delete | `DELETE /servers/{uuid}/databases` | `{"database_name":"app_prod"}` |

## Database users

| Operation | Method + path | Required fields |
|---|---|---|
| List | `GET /servers/{uuid}/database-users` | — |
| Search | `GET /servers/{uuid}/database-users/search?q=` | — |
| Create | `POST /servers/{uuid}/database-users` | `username`, `password`, `databases` |
| Update | `PUT /servers/{uuid}/database-users` | `username`, `databases` |
| Delete | `DELETE /servers/{uuid}/database-users` | `username` |

```bash
SERVER_UUID='replace-me'
"$XC" POST "/servers/$SERVER_UUID/databases" '{"database_name":"app_prod"}' | jq '.message'
"$XC" POST "/servers/$SERVER_UUID/database-users" '{
  "username": "app_user",
  "password": "<strong-password>",
  "databases": ["app_prod"]
}' | jq '.data'
```

- Database create/delete and user mutations are keyed by **name** in the body,
  not by a UUID in the path.
- `databases` is an array of database names the user may access.
