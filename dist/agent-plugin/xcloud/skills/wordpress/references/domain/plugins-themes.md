# WordPress plugins & themes

`XC="scripts/xcloud.sh"` · scope `read:sites` / `write:sites`.

| Operation | Method + path |
|---|---|
| List plugins | `GET /sites/{uuid}/wordpress/plugins` |
| List themes | `GET /sites/{uuid}/wordpress/themes` |
| Updates summary | `GET /sites/{uuid}/wordpress/updates` |
| Update items | `POST /sites/{uuid}/wordpress/update` |
| Activate items | `POST /sites/{uuid}/wordpress/activate` |
| Refresh item list | `POST /sites/{uuid}/wordpress/refresh` |

```bash
SITE_UUID='replace-me'
"$XC" GET "/sites/$SITE_UUID/wordpress/plugins?status=active" \
  | jq '(.data.items // .data) | map({slug, name, version, update_available})'
```

Update — required `type` (`plugin`|`theme`|`core`); `slugs` targets specific
items (omit for all of that type); `backup_before_update` is recommended:

```bash
"$XC" POST "/sites/$SITE_UUID/wordpress/update" '{
  "type": "plugin",
  "slugs": ["woocommerce","akismet"],
  "backup_before_update": true
}' | jq '.message'
```

Activate — required `type` and `slugs`:

```bash
"$XC" POST "/sites/$SITE_UUID/wordpress/activate" '{
  "type": "plugin",
  "slugs": ["woocommerce"],
  "backup_before_action": true
}' | jq '.message'
```

Refresh the cached plugin/theme inventory before reading it:

```bash
"$XC" POST "/sites/$SITE_UUID/wordpress/refresh" | jq '.message'
```

- Updates/activations are async — confirm via `GET /sites/{uuid}/events`.
- `backup_before_update` / `backup_before_action` snapshot the site first; prefer
  `true` for production.
