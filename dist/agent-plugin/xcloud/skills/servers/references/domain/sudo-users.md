# Sudo users

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.
OS-level privileged accounts on the server (distinct from the API token user).

| Operation | Method + path |
|---|---|
| List | `GET /servers/{uuid}/sudo-users` |
| Create or update | `POST /servers/{uuid}/sudo-users` |
| Delete | `DELETE /servers/{uuid}/sudo-users/{sudo_user_uuid}` |

Create/update body: `username` and `ssh_public_keys` are required, and a
non-root user also needs a `password`. Creating or deleting a sudo user
needs two-factor authentication on the account. A sudo user is a standing
privileged account: say the server name, the username and that it has full
root rights, and prefer `is_temporary: true`. Offer the removal at the same
time (the delete call below) and remind the user to remove it when the work
is done.

The password is a secret — read it from a file only the user can read (mode
600, one line) with `jq --rawfile`, and pipe the JSON on **stdin** (`-`), so it
is never an argument to any process:

```bash
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
SERVER_UUID='replace-me'
jq -n --rawfile pw "$SUDO_PASSWORD_FILE" '{
  username: "deploy",
  password: ($pw|rtrimstr("\n")),
  ssh_public_keys: ["ssh-ed25519 AAAA... user@host"],
  is_temporary: true
}' | "$XC" POST "/servers/$SERVER_UUID/sudo-users" - | jq '.data'
```

```bash
SUDO_USER_UUID='replace-me'
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
"$XC" DELETE "/servers/$SERVER_UUID/sudo-users/$SUDO_USER_UUID" | jq '.message'
```

- Private keys are never returned. Never echo the password back; read it from
  a variable the user set, not from the command line.
- `is_temporary: true` provisions a short-lived account.
