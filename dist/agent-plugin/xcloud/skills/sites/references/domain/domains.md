# Site domains, redirections & web rules

`XC="scripts/xcloud.sh"` · scope `read:sites`.

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

- These are read-only in the public API today.
- After a domain change, poll `/sites/{uuid}/domain/status` for propagation.
- SSL for a domain is a separate concern — see `xcloud:ssl`.
