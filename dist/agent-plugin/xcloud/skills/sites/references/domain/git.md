# Git deployments

`XC="scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| Git deployment info | `GET /sites/{uuid}/git` |
| Update deployment settings | `PUT /sites/{uuid}/git` |
| Trigger manual deployment | `POST /sites/{uuid}/git/deploy` |

**Creating** a Git-deployed site happens server-side — `POST
/servers/{uuid}/sites/git` (`xcloud:servers`); this file manages the site after
it exists.

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

Git deploys are async. After triggering one, xCloud must poll one of:

```bash
"$XC" GET "/sites/$SITE_UUID/deployment-logs" | jq '(.data.items // .data) | .[0:5]'
"$XC" GET "/sites/$SITE_UUID/events" | jq '(.data.items // .data) | .[0:10]'
```

Safety:

- Read current settings before writes.
- Restate the site, branch, push-deploy setting, script behavior, and restart
  intent before updating.
- Warn before running deployment scripts that include migrations, cache clears,
  service restarts, or other commands that can change production behavior.
