# Site backups

`XC="scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| Trigger backup | `POST /sites/{uuid}/backup` |
| List backups | `GET /sites/{uuid}/backups` |
| Backup count | `GET /sites/{uuid}/backup-count` |
| Backup settings | `GET /sites/{uuid}/backup-settings` |
| Backup status | `GET /sites/{uuid}/backup-status` |

```bash
SITE_UUID='replace-me'
"$XC" POST "/sites/$SITE_UUID/backup" '{"label":"pre-update"}' | jq '.message'
"$XC" GET  "/sites/$SITE_UUID/backup-status" | jq '.data'
"$XC" GET  "/sites/$SITE_UUID/backups" | jq '(.data.items // .data) | map({uuid, label, status, created_at})'
```

- Backups are async — poll `backup-status` (or `GET /sites/{uuid}/events`) after
  triggering.
- `label` is optional but recommended for traceability.
