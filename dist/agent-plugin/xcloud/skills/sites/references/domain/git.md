# Git deployments

`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | MCP tool | Method + path |
|---|---|---|
| Git deployment info | `sites_git` | `GET /sites/{uuid}/git` |
| Update deployment settings | `sites_git_update` | `PUT /sites/{uuid}/git` |
| Trigger manual deployment | `sites_git_deploy` | `POST /sites/{uuid}/git/deploy` |
| Deployment records (staging push/pull) | `sites_deployment-logs` | `GET /sites/{uuid}/deployment-logs` |

**Creating** a Git-deployed site happens server-side — `git_detect`, then
`servers_sites_git_auto` (or `servers_sites_git_create` /
`servers_sites_git_docker`), plus deploy keys for private repositories. That
whole flow, including the refusals on agentic and Docker servers, is documented
in the `servers` skill; this file manages the site after it exists.

Inspect the current configuration first:

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/git" | jq '.data'
```

Update deployment settings. `git_branch` is required; all other fields are
optional and keep their current values when omitted:

```bash
"$XC" PUT "/sites/$SITE_UUID/git" '{
  "git_branch": "main",
  "enable_push_deploy": true,
  "run_after_deployment": true,
  "deploy_script": "composer install --no-dev\nphp artisan migrate --force",
  "restart_services": false,
  "env_file_path": "app"
}' | jq '.data'
```

Trigger a manual pull-and-deploy:

```bash
"$XC" POST "/sites/$SITE_UUID/git/deploy" | jq '.message'
```

Git deploys are async. After triggering one, xCloud must poll:

```bash
"$XC" GET "/sites/$SITE_UUID/deployment-logs" | jq '(.data.items // .data) | .[0:5]'
"$XC" GET "/sites/$SITE_UUID/events" | jq '(.data.items // .data) | .[0:10]'
```

`deployment-logs` returns the site's deployment records — `status`, `action`,
`source`, `destination`, `initiated_by`, timestamps — which in practice are the
staging↔production push/pull deployments. It carries no commit or branch, and
the *initial* deploy of a new Git site is not in it. Confirm a first deploy with
`GET /sites/{uuid}/status` (`deploy_state` is authoritative, `terminal` says
when to stop polling), and track a manual git deploy through
`GET /sites/{uuid}/events`.

Safety:

- Read current settings before writes.
- Restate the site, branch, push-deploy setting, script behavior, and restart
  intent before updating.
- Warn before running deployment scripts that include migrations, cache clears,
  service restarts, or other commands that can change production behavior.
