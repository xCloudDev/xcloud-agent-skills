# Docker app backups

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.
For sites on a Docker server (Compose deploys and one-click apps).

| Operation | Operation id | Method + path |
|---|---|---|
| Back up now | `sites.docker.backup` | `POST /sites/{uuid}/docker/backup` |
| List backups | `sites.docker.backups` | `GET /sites/{uuid}/docker/backups` |
| One backup | `sites.docker.backup.show` | `GET /sites/{uuid}/docker/backups/{backupUuid}` |
| Label a backup | `sites.docker.backup.note.update` | `PUT /sites/{uuid}/docker/backups/{backupUuid}/note` |
| Delete a backup | `sites.docker.backup.destroy` | `DELETE /sites/{uuid}/docker/backups/{backupUuid}` |
| Backup count | `sites.docker.backupCount` | `GET /sites/{uuid}/docker/backup-count` |
| Schedule and retention | `sites.docker.backupSettings` · `.update` | `GET\|PUT /sites/{uuid}/docker/backup-settings` |

"Take a backup of the n8n app before I upgrade it, and tell me when it's done":

```bash
SITE_UUID='replace-me'
B=$("$XC" POST "/sites/$SITE_UUID/docker/backup" '{}' | jq -r '.data.uuid')
"$XC" GET "/sites/$SITE_UUID/docker/backups/$B" | jq '.data'   # poll until status is terminal
"$XC" PUT "/sites/$SITE_UUID/docker/backups/$B/note" '{"user_note":"before upgrade"}' | jq '.message'
```

- The app is **briefly cold-stopped** while its volumes are captured — say so
  before triggering it on a production app.
- `destination` is a storage-provider uuid (S3-compatible or SFTP); omit it for
  a local backup. Google Drive and pCloud are not supported.
- Schedule: `auto_backup` (bool) and `auto_backup_frequency` (`daily`,
  `weekly`, `monthly`) are required on update; `delete_after_days` sets
  retention.
- Deleting a backup is irreversible — confirm the exact backup (date and note)
  first.
