# Databases & database users

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


> Databases and database users are on the API (`servers.databases.*`, `servers.database-users.*`). Names go in the body, the password needs 12 or more characters, and deleting a database or user is irreversible: name the server and database, and confirm.

`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.

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
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
"$XC" POST "/servers/$SERVER_UUID/databases" '{"database_name":"app_prod"}' | jq '.message'
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
# The password (12 characters or more) comes from a variable the user set; it is never typed on the command line or echoed.
jq -n --arg pw "$DB_PASSWORD" '{username: "app_user", password: $pw, databases: ["app_prod"]}' \
  | "$XC" POST "/servers/$SERVER_UUID/database-users" - | jq '.data'
```

- Database create/delete and user mutations are keyed by **name** in the body,
  not by a UUID in the path.
- `databases` is an array of database names the user may access.
