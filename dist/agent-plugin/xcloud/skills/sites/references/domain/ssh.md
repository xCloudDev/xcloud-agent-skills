# Site SSH/SFTP config

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| Get SSH/SFTP config | `GET /sites/{uuid}/ssh` |
| Update SSH/SFTP config | `PUT /sites/{uuid}/ssh` |
| List SSH keys | `GET /sites/{uuid}/ssh-keys` |

Switch to public-key auth (`ssh_public_keys` required):

```bash
SITE_UUID='replace-me'
"$XC" PUT "/sites/$SITE_UUID/ssh" '{
  "authentication_mode": "public_key",
  "ssh_public_keys": ["ssh-ed25519 AAAA... user@host"]
}' | jq '.message'
```

Switch to password auth (`password` required). The password is a secret —
build the JSON with `jq -n` and pipe it on **stdin** (`-`) so it never appears
in any process argument list:

```bash
jq -n --arg pw "$SITE_SSH_PASSWORD" \
  '{authentication_mode: "password", password: $pw}' \
  | "$XC" PUT "/sites/$SITE_UUID/ssh" - | jq '.message'
```

- `authentication_mode=public_key` requires `ssh_public_keys`;
  `authentication_mode=password` requires `password`.
- `GET /sites/{uuid}/ssh` exposes `site_user` — useful when triaging a 502
  caused by a missing OS user. Private keys are never returned.
