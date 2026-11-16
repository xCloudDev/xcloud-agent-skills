# Server cron jobs

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.

| Operation | Method + path |
|---|---|
| List | `GET /servers/{uuid}/cron-jobs` |
| Create | `POST /servers/{uuid}/cron-jobs` |
| Update | `PUT /servers/{uuid}/cron-jobs/{cronJobUuid}` |
| Delete | `DELETE /servers/{uuid}/cron-jobs/{cronJobUuid}` |
| Run now | `POST /servers/{uuid}/cron-jobs/{cronJobUuid}/execute` |
| Last output | `GET /servers/{uuid}/cron-jobs/{cronJobUuid}/output` |

A cron job runs a command on the server on a schedule. Show the user the
exact command, the schedule and the server it will run on, and confirm before
creating it, running it now or deleting it. The `user` cannot be `xcloud`:
use the system user the user names.

Create body — required `user`, `frequency`, `command`; `pattern` holds a custom
cron expression when `frequency=custom`:

```bash
SERVER_UUID='replace-me'
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
"$XC" POST "/servers/$SERVER_UUID/cron-jobs" '{
  "user": "$CRON_USER",
  "frequency": "custom",
  "pattern": "*/15 * * * *",
  "command": "php /home/$CRON_USER/cleanup.php"
}' | jq '.data'
```

```bash
CRON_UUID='replace-me'
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
"$XC" POST "/servers/$SERVER_UUID/cron-jobs/$CRON_UUID/execute" | jq '.message'
"$XC" GET  "/servers/$SERVER_UUID/cron-jobs/$CRON_UUID/output"  | jq '.data'
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
"$XC" DELETE "/servers/$SERVER_UUID/cron-jobs/$CRON_UUID" | jq '.message'
```

> Site-scoped cron is a different resource — see `xcloud:sites` (`reference/servers-cron-jobs.md`).
