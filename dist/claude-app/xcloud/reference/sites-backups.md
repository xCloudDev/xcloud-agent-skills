# Site backups

`XC="scripts/xcloud.sh"` · MCP tools first · scope
`read:sites` / `write:sites`.

xCloud has **three separate backup kinds**. They do not share endpoints, and
using the wrong one on the wrong site type returns `422`.

1. **Native site backups** — files and database of a WordPress/PHP/Node site
   on an nginx or OpenLiteSpeed server.
2. **Docker app backups** — cold-stop + restic snapshots of a Docker site's
   volumes. Docker sites only.
3. **Site snapshots** — reusable images of a site, used to clone or re-create
   it. Read-only on the API.

## 1. Native site backups

| Operation | MCP tool | Method + path |
|---|---|---|
| Trigger backup | `sites_backup` | `POST /sites/{uuid}/backup` |
| List backups | `sites_backups` | `GET /sites/{uuid}/backups` |
| Backup count | `sites_backupCount` | `GET /sites/{uuid}/backup-count` |
| Backup settings (read) | `sites_backupSettings` | `GET /sites/{uuid}/backup-settings` |
| Backup status (read) | `sites_backupStatus` | `GET /sites/{uuid}/backup-status` |

```bash
SITE_UUID='replace-me'
"$XC" POST "/sites/$SITE_UUID/backup" '{"label":"pre-update"}' | jq '.message'
"$XC" GET  "/sites/$SITE_UUID/backup-status" | jq '.data'
"$XC" GET  "/sites/$SITE_UUID/backups" | jq '(.data.items // .data) | map({uuid, label, status, created_at})'
```

- Backups are async — poll `backup-status` (or `sites_events`) after
  triggering. `sites_backup` is one of the few mutating operations marked
  non-destructive: it is safe to repeat.
- `label` is optional but recommended for traceability.
- A site can have several settings entries (typically one local, one remote).
  Storage-provider credentials are never returned — only the provider's uuid,
  name and connection status.
- `backup-status` reports only the site's **own** settings; inherited server or
  team defaults are not counted as configured.

## 2. Docker app backups

| Operation | MCP tool | Method + path |
|---|---|---|
| Trigger backup | `sites_docker_backup` | `POST /sites/{uuid}/docker/backup` |
| List backups | `sites_docker_backups` | `GET /sites/{uuid}/docker/backups` |
| One backup (poll it) | `sites_docker_backup_show` | `GET /sites/{uuid}/docker/backups/{backupUuid}` |
| Backup count | `sites_docker_backupCount` | `GET /sites/{uuid}/docker/backup-count` |
| Settings (read) | `sites_docker_backupSettings` | `GET /sites/{uuid}/docker/backup-settings` |
| Settings (**write**) | `sites_docker_backupSettings_update` | `PUT /sites/{uuid}/docker/backup-settings` |
| Delete a backup | `sites_docker_backup_destroy` | `DELETE /sites/{uuid}/docker/backups/{backupUuid}` |

- **The app is briefly cold-stopped** while its volumes are captured — warn the
  user before triggering one on a live app. The call returns `202` with the
  `running` backup; poll `sites_docker_backup_show` for `completed`/`failed`.
- `destination` is a storage-provider uuid; omit it for a local backup.
- Docker sites are the **only** site type whose backup schedule and retention
  can be written over the API.
- Deleting a backup drops the snapshot from its restic repository — it is
  destructive and irreversible; confirm the exact backup first.
- Every Docker endpoint returns `422` on a non-Docker site, and the native
  endpoints return `422` on a Docker site.

## 3. Snapshots

| Operation | MCP tool | Method + path |
|---|---|---|
| Snapshots of this site | `sites_snapshots` | `GET /sites/{uuid}/snapshots` |
| Snapshots taken from sites on a server | `servers_snapshots` | `GET /servers/{uuid}/snapshots` |

Read-only. `servers_snapshots` aggregates the **site** snapshots of every site
on that server — it is not a list of server images. Creating, scheduling and
restoring snapshots is dashboard work: **Server → Backup**.

## What the API cannot do

| Job | Where it lives |
|---|---|
| Restore a backup (to this site, a new site, or another site) | **Site → Backups** |
| Download a backup file | **Site → Backups** |
| Change a native site's schedule, retention or destination | **Site → Backup** |
| Apply backup settings across many sites at once | **Team settings → Global backup settings** |
| Add, verify or remove a backup storage provider | **User → Storage Providers** |

Trigger and read on the API; schedule, restore and store in the dashboard. See
`reference/capabilities.md` for the full map.
