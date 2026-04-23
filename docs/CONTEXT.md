# CONTEXT: URL Parsing & Server Selection

How to resolve xCloud resource identifiers, parse URLs, and select the right server for operations.

---

## Resource Identifier Reference

| Resource | Identifier | Format | Example |
|----------|-----------|--------|---------|
| Server | `uuid` | UUID v4 | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| Site | `uuid` | UUID v4 | `b2c3d4e5-f6a7-8901-bcde-f12345678901` |
| Sudo User | `sudo_user_uuid` | UUID v4 | `c3d4e5f6-a7b8-9012-cdef-123456789012` |
| API Token | `tokenId` | Integer | `42` |
| Blueprint | `uuid` | UUID v4 | `d4e5f6a7-b8c9-0123-def0-234567890123` |

**Critical rule:** Never assume numeric IDs for servers/sites. Only `tokenId` uses integers.

---

## Resolving Resource UUIDs

### Find Server UUID by Name or IP

```bash
# By name (fuzzy search)
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?search=production" | \
  jq '.data.items[] | {uuid, name, ip_address}'

# By IP address
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | \
  jq '.data.items[] | select(.ip_address == "1.2.3.4") | {uuid, name}'

# All servers (small fleets)
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | \
  jq '.data.items[] | {uuid, name, ip_address, status}'
```

### Find Site UUID by Domain

```bash
# Exact match
DOMAIN='example.com'
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?search=$DOMAIN" | \
  jq --arg domain "$DOMAIN" '.data.items[] | select(.domain == $domain) | {uuid, domain}'

# Fuzzy search
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?search=example" | \
  jq '.data.items[] | {uuid, domain}'
```

### Resolve Server for a Given Site

```bash
SITE_UUID='your-site-uuid'

# Get server UUID from site
SERVER_UUID=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | \
  jq -r '.data.server_uuid')

echo "Server UUID: $SERVER_UUID"

# Then get server details
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | \
  jq '.data | {name, ip_address, status}'
```

---

## Server Selection Logic

When deploying a new site, select the right server using this logic:

```bash
# Find best server for deployment
find_best_server() {
  # Get all active servers with site counts
  curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/servers?status=active&per_page=100" | \
    jq -r '.data.items[] | .uuid' | while read SERVER_UUID; do
      
      SITE_COUNT=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
        -H "Accept: application/json" \
        "https://app.xcloud.host/api/v1/sites?server_uuid=$SERVER_UUID" | \
        jq '.data.items | length')
      
      # Select server with fewest sites (balanced distribution)
      echo "$SITE_COUNT $SERVER_UUID"
    done | sort -n | head -1 | awk '{print $2}'
}

BEST_SERVER=$(find_best_server)
echo "Deploying to server: $BEST_SERVER"
```

### Server Selection Decision Table

| Scenario | Selection Strategy |
|----------|-------------------|
| Single server fleet | Use that server |
| Multi-server, balanced | Pick server with fewest sites |
| Region-specific | Filter by server name/tag |
| Staging vs production | Use dedicated staging server |
| High-traffic sites | Prefer servers with fewer sites |

---

## URL Patterns

### Base URL
```
https://app.xcloud.host/api/v1
```

### Standard Endpoint Patterns

```
# Collections
GET  /servers                        → All servers
GET  /servers/{uuid}                 → Single server
GET  /servers/{uuid}/sites           → Sites on server
GET  /servers/{uuid}/tasks           → Async tasks for server
GET  /servers/{uuid}/php-versions    → Available PHP versions
GET  /servers/{uuid}/monitoring      → Server metrics
GET  /servers/{uuid}/sudo-users      → Sudo user list

# Server mutations
POST   /servers/{uuid}/reboot        → Reboot server
POST   /servers/{uuid}/sites/wordpress → Create WP site
POST   /servers/{uuid}/sudo-users    → Create sudo user
DELETE /servers/{uuid}/sudo-users/{uuid} → Delete sudo user

# Sites
GET  /sites                          → All sites (cross-server)
GET  /sites/{uuid}                   → Single site
GET  /sites/{uuid}/status            → Site status (async polling)
GET  /sites/{uuid}/events            → Site events log
GET  /sites/{uuid}/backups           → Backups list
GET  /sites/{uuid}/ssl               → SSL certificate info
GET  /sites/{uuid}/ssh               → SSH/SFTP config
GET  /sites/{uuid}/git               → Git config
GET  /sites/{uuid}/deployment-logs   → Deployment logs

# Site mutations
POST   /sites/{uuid}/backup          → Trigger backup
POST   /sites/{uuid}/cache/purge     → Purge caches
POST   /sites/{uuid}/ssl/renew       → Renew SSL
PUT    /sites/{uuid}/ssh             → Update SSH config
PATCH  /sites/{uuid}                 → Update site settings
DELETE /sites/{uuid}                 → Delete site

# Account
GET    /health                        → API health (no auth)
GET    /user                          → Current user info
GET    /user/tokens                   → API tokens list
DELETE /user/tokens/{tokenId}         → Revoke token
GET    /blueprints                    → Blueprint templates
```

---

## Pagination Handling

```bash
# Shape 1: data.items + data.pagination (servers, sites)
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=100" | \
  jq '{
    items: (.data.items // .data.data // []),
    pagination: (.data.pagination // .data.meta)
  }'

# Full pagination example (loop all pages)
PAGE=1
while true; do
  RESPONSE=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites?per_page=100&page=$PAGE")
  
  ITEMS=$(echo "$RESPONSE" | jq '.data.items // .data.data')
  LAST_PAGE=$(echo "$RESPONSE" | jq -r '.data.pagination.last_page // .data.meta.last_page')
  
  echo "$ITEMS" >> all-sites.json
  
  if [ "$PAGE" -ge "$LAST_PAGE" ]; then
    break
  fi
  
  PAGE=$((PAGE + 1))
done
```

---

## Environment Variables

```bash
# Required
export XCLOUD_API_TOKEN='your-token-here'

# Optional defaults
export XCLOUD_API_BASE='https://app.xcloud.host/api/v1'
export XCLOUD_DEFAULT_SERVER_UUID='server-uuid-for-deployments'
export XCLOUD_DEFAULT_PHP_VERSION='8.2'

# Used by src/xcloud-api.sh
XCLOUD_API_BASE="${XCLOUD_API_BASE:-https://app.xcloud.host/api/v1}"
```

---

## Context From URL (User-Provided)

When user provides a URL like `https://example.com`, extract the domain:

```bash
URL='https://example.com/some/path'

# Extract domain
DOMAIN=$(echo "$URL" | awk -F'[/:]' '{print $4}')
echo "Domain: $DOMAIN"

# Find site UUID from domain
SITE_UUID=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?search=$DOMAIN" | \
  jq -r --arg d "$DOMAIN" '.data.items[] | select(.domain == $d) | .uuid' | head -1)

echo "Site UUID: $SITE_UUID"
```

---

## UUID Validation

```bash
# Validate UUID format (bash)
validate_uuid() {
  local UUID=$1
  if [[ $UUID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    echo "valid"
  else
    echo "invalid"
  fi
}

# Example
UUID='a1b2c3d4-e5f6-7890-abcd-ef1234567890'
if [ "$(validate_uuid $UUID)" = "valid" ]; then
  echo "✅ Valid UUID"
else
  echo "❌ Invalid UUID: $UUID"
fi
```
