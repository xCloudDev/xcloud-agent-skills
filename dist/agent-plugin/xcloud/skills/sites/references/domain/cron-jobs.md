# Site cron jobs

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


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
