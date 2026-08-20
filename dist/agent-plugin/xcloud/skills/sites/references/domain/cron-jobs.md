# Site cron jobs

`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| List | `GET /sites/{uuid}/cron-jobs` |
| Create | `POST /sites/{uuid}/cron-jobs` |
| Update | `PUT /sites/{uuid}/cron-jobs/{cronJobUuid}` |
| Delete | `DELETE /sites/{uuid}/cron-jobs/{cronJobUuid}` |
| Run now | `POST /sites/{uuid}/cron-jobs/{cronJobUuid}/execute` |
| Last output | `GET /sites/{uuid}/cron-jobs/{cronJobUuid}/output` |

Create body — required `frequency`, `command` (`pattern` for a custom cron
expression). Unlike server cron, no `user` field — it runs as the site user:

```bash
SITE_UUID='replace-me'
"$XC" POST "/sites/$SITE_UUID/cron-jobs" '{
  "frequency": "custom",
  "pattern": "0 3 * * *",
  "command": "wp cron event run --due-now"
}' | jq '.data'
```

> Server-scoped cron (with an explicit `user`) is a different resource — see
> the `servers` skill.
