# Site domains, redirections & web rules

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scope `read:sites`.

| Operation | Method + path |
|---|---|
| Primary domain info | `GET /sites/{uuid}/domain` |
| Domain update status | `GET /sites/{uuid}/domain/status` |
| List all domains | `GET /sites/{uuid}/domains` |
| List redirections | `GET /sites/{uuid}/redirections` |
| List web rules | `GET /sites/{uuid}/web-rules` |

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/domain"  | jq '.data'
"$XC" GET "/sites/$SITE_UUID/domains" | jq '(.data.items // .data) | map({domain, is_primary, status})'
"$XC" GET "/sites/$SITE_UUID/redirections" | jq '.data'
```

- Changes: `sites.domains.update` (www and extra domains), `sites.domain.update` (primary domain, go live), `sites.redirections.store/update/destroy` and `sites.webRules.store/update/destroy`. Show the domain or rule and the site first, and confirm. Custom nginx stays dashboard-only. `sites.domains.update` is refused (`422`) for one-click catalog apps: send the user to the app's Domain page in the dashboard.
- After a domain change, poll `/sites/{uuid}/domain/status` for propagation.
- SSL for a domain is a separate concern — see the `ssl` skill.
