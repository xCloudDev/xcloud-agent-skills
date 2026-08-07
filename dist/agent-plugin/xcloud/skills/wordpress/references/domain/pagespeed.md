# PageSpeed Insights

`XC="scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| Latest snapshot | `GET /sites/{uuid}/pagespeed` |
| History | `GET /sites/{uuid}/pagespeed/history` |
| Trigger scan | `POST /sites/{uuid}/pagespeed/scan` |

```bash
SITE_UUID='replace-me'
"$XC" POST "/sites/$SITE_UUID/pagespeed/scan" | jq '.message'           # async
"$XC" GET  "/sites/$SITE_UUID/pagespeed" \
  | jq '.data | {performance, lcp, cls, inp, fetched_at}'
"$XC" GET  "/sites/$SITE_UUID/pagespeed/history" | jq '(.data.items // .data) | .[0:10]'
```

- Scans are async — poll `GET /sites/{uuid}/pagespeed` for the fresh snapshot.
- Applies to any site, not only WordPress (owned here by convention).
