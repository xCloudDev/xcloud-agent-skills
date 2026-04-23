# OPERATIONS: Safe vs Destructive Matrix

Reference for all API operations — safety classification, confirmation requirements, and rollback options.

---

## Operation Classification

### 🟢 SAFE — Read-only, no side effects

These operations are always safe to run at any time:

| Operation | Endpoint | Notes |
|-----------|----------|-------|
| API health check | `GET /health` | Unauthenticated |
| Get current user | `GET /user` | Reads account info |
| List servers | `GET /servers` | No side effects |
| Get server details | `GET /servers/{uuid}` | Read-only |
| List sites | `GET /sites` | No side effects |
| Get site details | `GET /sites/{uuid}` | Read-only |
| Get site status | `GET /sites/{uuid}/status` | Safe for polling |
| Get site events | `GET /sites/{uuid}/events` | Read-only |
| List backups | `GET /sites/{uuid}/backups` | Read-only |
| Get SSL info | `GET /sites/{uuid}/ssl` | Read-only |
| Get SSH config | `GET /sites/{uuid}/ssh` | Read-only |
| List blueprints | `GET /blueprints` | Read-only |
| List PHP versions | `GET /servers/{uuid}/php-versions` | Read-only |
| List sudo users | `GET /servers/{uuid}/sudo-users` | Read-only |
| List server tasks | `GET /servers/{uuid}/tasks` | Read-only |
| Get deployment logs | `GET /sites/{uuid}/deployment-logs` | Read-only |
| List API tokens | `GET /user/tokens` | Read-only |

---

### 🟡 CAUTION — Mutations with recovery path

These operations change state but can be reversed:

| Operation | Endpoint | Risk | Recovery |
|-----------|----------|------|----------|
| Trigger backup | `POST /sites/{uuid}/backup` | Low | No rollback needed (additive) |
| Purge cache | `POST /sites/{uuid}/cache/purge` | Low | Cache rebuilds automatically |
| Update SSH auth mode | `PUT /sites/{uuid}/ssh` | Medium | Re-apply previous auth |
| Update site settings | `PATCH /sites/{uuid}` | Medium | Re-apply previous settings |
| Create sudo user | `POST /servers/{uuid}/sudo-users` | Low | Delete the user |
| Renew SSL cert | `POST /sites/{uuid}/ssl/renew` | Low | Cert reverts on failure |
| Trigger rescue | `POST /sites/{uuid}/rescue` | Medium | Reboot required |

**Confirmation requirement:** State the resource name and effect clearly before executing. For automated scripts, log the action.

---

### 🔴 DESTRUCTIVE — Cannot be easily undone

These operations are irreversible or high-impact:

| Operation | Endpoint | Risk | Required Confirmation |
|-----------|----------|------|-----------------------|
| Delete site | `DELETE /sites/{uuid}` | Critical | Verify UUID + domain |
| Delete sudo user | `DELETE /servers/{uuid}/sudo-users/{uuid}` | High | Verify username |
| Revoke API token | `DELETE /user/tokens/{tokenId}` | High | Cannot recover token |
| Reboot server | `POST /servers/{uuid}/reboot` | Critical | All sites go down temporarily |

**Mandatory before destructive ops:**
1. Verify you have the correct UUID (not similar ones)
2. Confirm the resource name/domain matches intent
3. Create a backup (for site delete)
4. Get explicit user/operator confirmation
5. Log the action with timestamp

---

## Confirmation Templates

Use these patterns when automating destructive operations:

### Site Deletion Confirmation

```bash
SITE_UUID='your-site-uuid'

# Fetch site info for confirmation
SITE_INFO=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID")

DOMAIN=$(echo "$SITE_INFO" | jq -r '.data.domain')
SERVER_UUID=$(echo "$SITE_INFO" | jq -r '.data.server_uuid')

echo "⚠️  DESTRUCTIVE OPERATION"
echo "Action: DELETE site"
echo "Domain: $DOMAIN"
echo "Site UUID: $SITE_UUID"
echo "Server UUID: $SERVER_UUID"
echo ""
echo "This will permanently delete the site and all its data."
echo ""
read -p "Type the domain to confirm deletion: " CONFIRM_DOMAIN

if [ "$CONFIRM_DOMAIN" != "$DOMAIN" ]; then
  echo "❌ Confirmation mismatch. Aborted."
  exit 1
fi

# Backup first
curl -sS -X POST -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backup"

sleep 5  # Allow backup to initiate

# Delete
curl -sS -X DELETE -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.message'

echo "✅ Site deleted: $DOMAIN"
```

### Server Reboot Confirmation

```bash
SERVER_UUID='your-server-uuid'

SERVER=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID")

NAME=$(echo "$SERVER" | jq -r '.data.name')
SITE_COUNT=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?server_uuid=$SERVER_UUID" | \
  jq '.data.items | length')

echo "⚠️  CAUTION: SERVER REBOOT"
echo "Server: $NAME"
echo "UUID: $SERVER_UUID"
echo "Sites affected: $SITE_COUNT"
echo ""
echo "All sites will be unavailable during reboot (typically 2-5 minutes)."
echo ""
read -p "Confirm reboot? [yes/no]: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Reboot cancelled."
  exit 0
fi

curl -sS -X POST -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/reboot" | jq '.message'

echo "Server rebooting. Monitor with:"
echo "  watch -n 10 'curl -sS https://app.xcloud.host/api/v1/servers/$SERVER_UUID | jq .data.status'"
```

---

## Rollback Procedures

### After SSH Config Change

```bash
SITE_UUID='your-site-uuid'
OLD_KEYS='["ssh-ed25519 AAAA... previous-key"]'

curl -sS -X PUT \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
  -d "{
    \"authentication_mode\": \"public_key\",
    \"ssh_public_keys\": $OLD_KEYS
  }"
```

### After Cache Purge

No rollback needed — cache rebuilds automatically on next request.

### After Site Settings Update (Domain/PHP)

```bash
SITE_UUID='your-site-uuid'
OLD_DOMAIN='old.example.com'
OLD_PHP='8.1'

curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d "{
    \"domain\": \"$OLD_DOMAIN\",
    \"php_version\": \"$OLD_PHP\"
  }"
```

---

## Rate Limit Protection

Implement automatic rate limit handling in scripts:

```bash
# Call API with retry on 429
xcloud_request() {
  local METHOD=$1
  local ENDPOINT=$2
  local DATA=${3:-}
  local MAX_RETRIES=3
  local RETRY=0
  
  while [ $RETRY -lt $MAX_RETRIES ]; do
    if [ -n "$DATA" ]; then
      RESPONSE=$(curl -sS -w "\n%{http_code}" -X "$METHOD" \
        -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$DATA" \
        "${XCLOUD_API_BASE:-https://app.xcloud.host/api/v1}$ENDPOINT")
    else
      RESPONSE=$(curl -sS -w "\n%{http_code}" -X "$METHOD" \
        -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
        -H "Accept: application/json" \
        "${XCLOUD_API_BASE:-https://app.xcloud.host/api/v1}$ENDPOINT")
    fi
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" = "429" ]; then
      RETRY=$((RETRY + 1))
      WAIT=$((RETRY * 5))
      echo "Rate limited. Waiting ${WAIT}s (attempt $RETRY/$MAX_RETRIES)..." >&2
      sleep "$WAIT"
    else
      echo "$BODY"
      return 0
    fi
  done
  
  echo "❌ Max retries exceeded" >&2
  return 1
}
```

---

## Audit Log Template

Record all mutations with this format:

```bash
log_operation() {
  local ACTION=$1
  local RESOURCE=$2
  local UUID=$3
  local RESULT=$4
  
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $ACTION | $RESOURCE | $UUID | $RESULT" >> /var/log/xcloud-operations.log
}

# Usage
log_operation "DELETE" "site" "$SITE_UUID" "success"
log_operation "REBOOT" "server" "$SERVER_UUID" "initiated"
log_operation "BACKUP" "site" "$SITE_UUID" "triggered"
```

---

## Batch Operation Safety

When operating on multiple resources, apply safety buffers:

```bash
# Safe batch: 1-second delay between operations
SITE_UUIDS=("uuid1" "uuid2" "uuid3")

for SITE_UUID in "${SITE_UUIDS[@]}"; do
  echo "Processing: $SITE_UUID"
  
  # Your operation
  curl -sS -X POST \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backup" | \
    jq '.message'
  
  sleep 1  # Avoid rate limit (60 req/min = 1 req/sec max)
done
```
