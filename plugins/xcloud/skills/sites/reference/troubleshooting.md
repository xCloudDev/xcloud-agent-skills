# Troubleshooting a broken site (500 / 502 / blank page)

`XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"` · MCP tools first · scope
`read:sites` (step 5 also needs `write:sites`).

Work the ladder in order and stop at the first step that explains the failure.
Steps 1–4 are reads and change nothing. Step 5 is a **write**: it edits
`wp-config.php`, so it needs the user's approval (and `confirm: true` on MCP)
before you call it, and it must be turned off again afterwards.

| Step | MCP tool | Method + path | Answers |
|---|---|---|---|
| 1 | `sites_status` | `GET /sites/{uuid}/status` | Is the site provisioned? Did the last async job finish? |
| 2 | `sites_events` | `GET /sites/{uuid}/events` | Which step failed, and when |
| 2b | `sites_events_show` | `GET /sites/{uuid}/events/{task_uuid}` | A window of that step's output plus its `exit_code`, when the event's `output_truncated` is true (pass the event's own `uuid`) |
| 3 | `sites_access-logs` | `GET /sites/{uuid}/access-logs?type=nginx` | The web server's own account of the request |
| 4 | `sites_deployment-logs` | `GET /sites/{uuid}/deployment-logs` | Whether a recent staging push/pull deployment broke it |
| 5 ⚠️ write | `sites_wp-debug` | `POST /sites/{uuid}/wp-debug` | WordPress only — turn `WP_DEBUG` on, reproduce, turn it back off |

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/status" | jq '.data | {status, is_provisioned, deploy_state, terminal, failed_steps, error_message}'
"$XC" GET "/sites/$SITE_UUID/events" | jq '(.data.items // .data) | .[0:10] | map({uuid, name, type, status, output_truncated})'
"$XC" GET "/sites/$SITE_UUID/access-logs?type=nginx&limit=200" | jq '.data | {type, entry_count, entries: (.entries[0:40])}'
```

`sites_events_show` returns a **bounded window** of the output, anchored to the
end by default — which is where a build states its cause, so one call with no
`offset` usually answers the question and reports `output_complete`. When it is
false and you need the earlier output, start again at `offset=0` and follow
`next_offset` until it is null.

Notes that save a wrong turn:

- `deploy_state` on `sites_status` is the **authoritative** outcome of an async
  deploy; branch on it and stop polling when `terminal` is true. `failed_steps`
  is a diagnostic, not a verdict.
- `sites_deployment-logs` lists deployment records between sites (status,
  action, source, destination) — in practice staging↔production push/pull. The
  *initial* deploy from a Git create is not in there; confirm that one with
  `sites_status` and follow a manual git deploy through `sites_events`.
- `type=nginx` on `sites_access-logs` reads a glob over the site's nginx log
  directory, so it returns **access and error lines together** — that is the
  one API call that shows a PHP 500's error line. `type=access` is the access
  log alone; `type=lsws` is the OpenLiteSpeed equivalent.
- `sites_wp-debug` toggles the constant and is synchronous — the response is
  the final state. It needs `write:sites` plus the `site:manage-update` team
  permission. The debug **file** it produces is not readable over the API (see
  below). Turn it off again once reproduced.

## Logs the API cannot read

**Site → Logs** in the dashboard serves log types the Public API does not
expose: the PHP error log, the `WP_DEBUG` log contents, the Laravel log, the
PM2 log, the 7G/8G firewall logs, docker-compose logs, and the
OpenClaw / DeepSeek Harness service journals. It is also the only place a log
can be cleared or emailed as an export. When the ladder above runs out, send
the user there by name — do not invent an endpoint for it.

## Common causes

| Symptom | Likely cause | Check |
|---|---|---|
| `502` while `status` is still `provisioned` | Missing site OS user | `GET /sites/{uuid}/ssh` (`site_user`) plus `GET /servers/{uuid}/tasks` |
| `500` right after a deploy | Build or migration step failed | `sites_events` (find the `failed` event) → `sites_events_show` with its `uuid` |
| `500` on WordPress only after a plugin update | Fatal in the plugin | `sites_wp-debug`, then **Site → Logs** for the debug file |
| Site up, one page 404s | Nginx rules / redirections | `sites_customNginx`, `sites_redirections`, `sites_webRules` |
| Everything down on one server | Service stopped | `servers_services`, `servers_tasks` |

Repairs (`sites_rescue`, service restart, cache purge) are writes — restate the
target and the effect, get approval, then run them.

## Shell access, when the reads are not enough

Only after the read ladder is exhausted, and only with the user's explicit
permission for that specific action:

- **Temporary sudo user** — `servers_sudoUsers_store`
  (`POST /servers/{uuid}/sudo-users`) with `is_temporary: true`. Say who it is
  for and how long it is needed.
- **Site SSH/SFTP** — `sites_ssh_show` to read the current setting,
  `sites_ssh_update` to change authentication. Never put a password or key in a
  command line; build the JSON with `jq -n` and pipe it on stdin.

**Revoke when the work is done.** Delete the sudo user with
`servers_sudoUsers_destroy` and restore the previous SSH setting in the same
session — do not leave standing access behind, and tell the user it is gone.
