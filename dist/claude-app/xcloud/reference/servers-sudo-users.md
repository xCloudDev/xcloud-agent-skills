# Sudo users

`XC="scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.
OS-level privileged accounts on the server (distinct from the API token user).

| Operation | Method + path |
|---|---|
| List | `GET /servers/{uuid}/sudo-users` |
| Create or update | `POST /servers/{uuid}/sudo-users` |
| Delete | `DELETE /servers/{uuid}/sudo-users/{sudo_user_uuid}` |

Create/update body (all optional in schema, but supply `username` plus either
keys or a password):

The password is a secret — build the JSON with `jq -n` and pipe it on **stdin**
(`-`) so it never appears in any process argument list:

```bash
SERVER_UUID='replace-me'
jq -n --arg pw "$SUDO_PASSWORD" '{
  username: "deploy",
  password: $pw,
  ssh_public_keys: ["ssh-ed25519 AAAA... user@host"],
  is_temporary: false
}' | "$XC" POST "/servers/$SERVER_UUID/sudo-users" - | jq '.data'
```

```bash
SUDO_USER_UUID='replace-me'
"$XC" DELETE "/servers/$SERVER_UUID/sudo-users/$SUDO_USER_UUID" | jq '.message'
```

- Private keys are never returned.
- `is_temporary: true` provisions a short-lived account.
