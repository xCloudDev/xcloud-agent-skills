# Databases & database users — DEPRECATED

> **⚠️ Deprecated: not part of the xCloud Public API, and not planned for this
> release.** Every endpoint below is deliberately withheld — the routes exist
> in xCloud's public-API route file but are commented out ("TEMPORARILY
> HIDDEN"), no `databases` or `database-users` path appears in the OpenAPI
> spec, and live calls return **HTTP 404 "Resource not found"** while sibling
> endpoints (`php-versions`, `firewall-rules`) return `200` on the same server.
> Neither MCP surface exposes a database tool. **Database and database-user
> management is dashboard-only: Server → Database.** Send the user there; do
> not call anything below, and do not present it as a capability. This file is
> kept only as a record of the shape those endpoints had, for the day they
> ship. Verified 2026-09-08.

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
