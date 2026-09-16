# Git deployments

`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| Git deployment info | `GET /sites/{uuid}/git` |
| Update deployment settings | `PUT /sites/{uuid}/git` |
| Trigger manual deployment | `POST /sites/{uuid}/git/deploy` |
| Deploy settings a deploy reads | `GET /sites/{uuid}/deploy-config` |
| Change deploy settings, no deploy | `PUT /sites/{uuid}/deploy-config` |
| Provision/deploy status | `GET /sites/{uuid}/status` |
| Diagnose a failed deploy | `GET /sites/{uuid}/deploy-diagnosis` |
| Retry a failed deploy | `POST /sites/{uuid}/provision-retry` |

**Creating** a Git-deployed site happens server-side (the `servers` skill) and
follows the flow below; "Polling" onwards applies to this skill's sites too.

## Detect first

Call `git.detect` with the `server_uuid` the human chose, so access and
compatibility are judged against that exact target. Branch on
`repository_access`: `detection` is `null` whenever the repository could not be
read, and that is an access problem no explicit app type bypasses. Read
`warnings` for what detection guessed or could not settle.

Then deploy with `servers.sites.git.auto` — it fills in every field you omit,
on native and Docker servers alike. Reach for `servers.sites.git.create`
(nginx/OpenLiteSpeed) or `servers.sites.git.docker` (Docker) only when the human
gave you explicit values to pin, never as a way around an access failure.

## Private SSH repositories

A private repository with no connected git provider needs a deploy key:

1. `servers.git.deploy-keys.index` — a key may already be prepared, from an
   earlier conversation or attempt. **Never mint a second key for a repository
   whose key the human has already added.**
2. `servers.git.deploy-keys.store` — mints a key and returns the PUBLIC half
   only. The human adds it to the repository as a read-only deploy key.
3. `servers.git.deploy-keys.verify` with `detect: true` — proves the key can
   clone, and returns detection **and** the compose scan (the only one a private
   SSH repository has: the standalone scan cannot use a deploy key).
   `compose.suggested_primary_port.host_port` is the `port` a Compose deploy needs.
4. Deploy, passing the key as `repository.deploy_key_uuid`.

## Docker Compose host ports

xCloud runs the repository's own compose file as-is and proxies to the host port
that file publishes — it never rewrites the `ports:` mapping. So `port` must be:

- **free on the server** — a port another site or an unmanaged process already
  holds is refused with `errors.code: port_unavailable`;
- **published by the file** — a port it does not publish is refused with
  `port_not_published`, and `errors.published_ports` lists the ones it does.

A `${PORT:-8080}:8080` mapping is resolved against the `env_file_content` you
send, exactly as `docker compose up` reads it — which is how two apps with the
same default port share one server. When the file cannot be read (private repo,
rate-limited host) the port is accepted and `warnings` say it was not checked.

## Polling

Poll `sites.status` and branch on `deploy_state` only — never on `status` or
`migration_status`, which are internal:

- `in_progress` — `terminal` is `false`; wait `poll_after_seconds` and poll again.
- `deployed` / `failed` / `cancelled` — `terminal` is `true`; stop.

`failed_steps` lists provisioning steps whose latest attempt failed and was not
recovered; on a `deployed` site that means "succeeded, but verify", not a
failure. A site being deleted reports `in_progress` until the endpoint answers
404 — that 404 is the completion. And `deployed` means the deploy chain finished,
not that the application answers: fetch the site URL before reporting it live.

## When a deploy fails

1. `sites.deploy-diagnosis` — a deterministic `classification`, a one-sentence
   `explanation` safe to show a human, `correctable_fields` narrowed to what
   this site type accepts, and `next`: `retry`, `redeploy`, `rescue`,
   `recreate` or `support`. `next_hint` names the exact operation.
2. `sites.provision-retry` on the **same** site — do not delete and recreate a
   site whose deploy failed. Send the wrong settings as `corrections`, describe
   what will change, get the human's approval (on MCP, then `confirm: true`),
   and pass an `Idempotency-Key`. It answers 409 while a deploy or another retry
   is running, and 422 unless `deploy_state` is `failed`.
3. Poll `sites.status` again until `terminal`.

`sites.deploy-config` shows the values that produced the failure;
`sites.deploy-config.update` changes settings without deploying anything, so it
never fixes a broken site on its own. `deploy_script_fail_fast` lives there: new
sites stop their deploy script at the first failing command, while a site created
before the setting existed reports `false` until someone turns it on.

## Managing an existing site

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/git" | jq '.data'
"$XC" PUT "/sites/$SITE_UUID/git" '{"git_branch":"main","enable_push_deploy":true}' | jq '.data'
"$XC" POST "/sites/$SITE_UUID/git/deploy" | jq '.message'
"$XC" GET "/sites/$SITE_UUID/status" | jq '.data | {deploy_state, terminal, poll_after_seconds}'
```

`git_branch` is required on the update; every other field keeps its current
value when omitted.

Safety: read current settings before writes; restate the site, branch,
push-deploy setting, script behavior and restart intent before updating; and warn
before running deployment scripts that include migrations, cache clears, service
restarts, or anything else that can change production behavior.
