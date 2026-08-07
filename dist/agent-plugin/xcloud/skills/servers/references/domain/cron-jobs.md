# Server cron jobs

`XC="scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.

| Operation | Method + path |
|---|---|
| List | `GET /servers/{uuid}/cron-jobs` |
| Create | `POST /servers/{uuid}/cron-jobs` |
| Update | `PUT /servers/{uuid}/cron-jobs/{cronJobUuid}` |
| Delete | `DELETE /servers/{uuid}/cron-jobs/{cronJobUuid}` |
| Run now | `POST /servers/{uuid}/cron-jobs/{cronJobUuid}/execute` |
| Last output | `GET /servers/{uuid}/cron-jobs/{cronJobUuid}/output` |

Create body — required `user`, `frequency`, `command`; `pattern` holds a custom
cron expression when `frequency=custom`:

```bash
SERVER_UUID='replace-me'
"$XC" POST "/servers/$SERVER_UUID/cron-jobs" '{
  "user": "xcloud",
  "frequency": "custom",
  "pattern": "*/15 * * * *",
  "command": "php /home/xcloud/cleanup.php"
}' | jq '.data'
```

```bash
CRON_UUID='replace-me'
"$XC" POST "/servers/$SERVER_UUID/cron-jobs/$CRON_UUID/execute" | jq '.message'
"$XC" GET  "/servers/$SERVER_UUID/cron-jobs/$CRON_UUID/output"  | jq '.data'
"$XC" DELETE "/servers/$SERVER_UUID/cron-jobs/$CRON_UUID" | jq '.message'
```

> Site-scoped cron is a different resource — see `xcloud:sites` (`references/domain/cron-jobs.md`).
