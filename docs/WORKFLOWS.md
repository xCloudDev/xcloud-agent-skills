# WORKFLOWS: Composition Patterns

End-to-end workflows combining multiple API operations for real-world tasks.

---

## 1. Full Site Provisioning (WordPress)

**Goal:** Provision site → configure domain → enable SSL → verify health  
**Time:** ~15 minutes  
**Difficulty:** Standard

```bash
#!/bin/bash
# Full WordPress provisioning workflow
set -e

SERVER_UUID=$1
DOMAIN=$2
PHP_VERSION=${3:-8.2}

echo "🚀 Starting WordPress provisioning for $DOMAIN"

# --- STEP 1: Preflight ---
echo "Step 1/6: Preflight checks..."

# Verify API access
curl -sS -f -o /dev/null \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  https://app.xcloud.host/api/v1/user || { echo "❌ API auth failed"; exit 1; }

# Verify server active
SERVER_STATUS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | jq -r '.data.status')
[ "$SERVER_STATUS" = "active" ] || { echo "❌ Server not active: $SERVER_STATUS"; exit 1; }

echo "  ✅ Preflight passed"

# --- STEP 2: Create WordPress site ---
echo "Step 2/6: Creating WordPress site..."

RESPONSE=$(curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites/wordpress" \
  -d "{
    \"mode\": \"live\",
    \"domain\": \"$DOMAIN\",
    \"title\": \"$DOMAIN\",
    \"php_version\": \"$PHP_VERSION\",
    \"ssl\": {\"provider\": \"letsencrypt\"},
    \"cache\": {\"full_page\": true, \"object_cache\": true}
  }")

SITE_UUID=$(echo "$RESPONSE" | jq -r '.data.uuid')
[ "$SITE_UUID" != "null" ] || { echo "❌ Site creation failed"; echo "$RESPONSE" | jq .; exit 1; }

echo "  ✅ Site created: $SITE_UUID"

# --- STEP 3: Poll for provisioning ---
echo "Step 3/6: Waiting for provisioning (up to 15 minutes)..."

for i in $(seq 1 90); do
  STATUS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq -r '.data.status')
  
  printf "\r  Status: %-20s (attempt %d/90)" "$STATUS" "$i"
  
  if [ "$STATUS" = "provisioned" ]; then
    echo ""
    echo "  ✅ Site provisioned"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo ""
    echo "❌ Provisioning failed"
    curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
      -H "Accept: application/json" \
      "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=5" | jq '.data.items[] | .message'
    exit 1
  fi
  
  sleep 10
done

# --- STEP 4: Configure SSH access ---
echo "Step 4/6: Configuring SSH access..."

if [ -n "$SSH_PUBLIC_KEY" ]; then
  curl -sS -X PUT \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
    -d "{
      \"authentication_mode\": \"public_key\",
      \"ssh_public_keys\": [\"$SSH_PUBLIC_KEY\"]
    }" | jq '.message'
  echo "  ✅ SSH configured with public key"
else
  echo "  ⏭️  Skipping SSH config (SSH_PUBLIC_KEY not set)"
fi

# --- STEP 5: Initial backup ---
echo "Step 5/6: Triggering initial backup..."

curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backup" | jq '.message'

echo "  ✅ Backup triggered"

# --- STEP 6: Verify health ---
echo "Step 6/6: Verifying site health..."

sleep 10
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ]; then
  echo "  ✅ Site responding: HTTP $HTTP_CODE"
else
  echo "  ⚠️  Site returned HTTP $HTTP_CODE (may need DNS propagation)"
fi

# --- Summary ---
echo ""
echo "🎉 Provisioning complete!"
echo "  Domain:    https://$DOMAIN"
echo "  Site UUID: $SITE_UUID"
echo "  Server:    $SERVER_UUID"
echo ""
echo "To retrieve WordPress credentials:"
echo "  curl -sS -H \"Authorization: Bearer \$XCLOUD_API_TOKEN\" \\"
echo "    https://app.xcloud.host/api/v1/sites/$SITE_UUID | jq '.data | {wordpress_user, wordpress_password, admin_url}'"
```

---

## 2. Staging → Production Promotion

**Goal:** Promote tested staging site to production  
**Time:** ~5 minutes  
**Requires:** Staging site UUID, production domain

```bash
#!/bin/bash
STAGING_UUID=$1
PROD_DOMAIN=$2

echo "🔄 Promoting staging to production..."

# 1. Backup staging before changes
echo "Step 1: Backup staging..."
curl -sS -X POST -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$STAGING_UUID/backup" | jq '.message'
sleep 5

# 2. Change domain to production
echo "Step 2: Update domain to $PROD_DOMAIN..."
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$STAGING_UUID" \
  -d "{\"domain\": \"$PROD_DOMAIN\"}" | jq '.message'

# 3. Renew SSL for new domain
echo "Step 3: Renew SSL..."
curl -sS -X POST -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$STAGING_UUID/ssl/renew" | jq '.message'
sleep 30

# 4. Enable production caching
echo "Step 4: Enable production caching..."
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$STAGING_UUID" \
  -d '{"cache": {"full_page": true, "object_cache": true}}' | jq '.message'

# 5. Verify
echo "Step 5: Verifying production site..."
sleep 10
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "https://$PROD_DOMAIN")
echo "  HTTP status: $HTTP"

echo "✅ Promotion complete. Site UUID: $STAGING_UUID → $PROD_DOMAIN"
```

---

## 3. Fleet Health Check & Auto-Recover

**Goal:** Check all sites, auto-restart any in error state  
**Time:** Varies (1 minute per 10 sites)  
**Schedule:** Cron every 30 minutes

```bash
#!/bin/bash
# Fleet health check + auto-recovery

RECOVERED=0
FAILED=0
HEALTHY=0

echo "🔍 Fleet health check: $(date)"

# Get all sites
SITES=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000")

echo "$SITES" | jq -r '.data.items[] | .uuid' | while read SITE_UUID; do
  DOMAIN=$(echo "$SITES" | jq -r --arg u "$SITE_UUID" '.data.items[] | select(.uuid == $u) | .domain')
  STATUS=$(echo "$SITES" | jq -r --arg u "$SITE_UUID" '.data.items[] | select(.uuid == $u) | .status')
  
  if [ "$STATUS" = "provisioned" ]; then
    # Spot-check HTTP
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$DOMAIN" 2>/dev/null)
    
    if [ "$HTTP" = "200" ] || [ "$HTTP" = "301" ] || [ "$HTTP" = "302" ]; then
      HEALTHY=$((HEALTHY + 1))
    elif [ "$HTTP" = "502" ] || [ "$HTTP" = "503" ]; then
      echo "  ⚠️  $DOMAIN: HTTP $HTTP — attempting recovery"
      
      curl -sS -X POST -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
        -H "Accept: application/json" \
        "https://app.xcloud.host/api/v1/sites/$SITE_UUID/restart" > /dev/null 2>&1
      
      RECOVERED=$((RECOVERED + 1))
    fi
  else
    echo "  ❌ $DOMAIN: status=$STATUS"
    FAILED=$((FAILED + 1))
  fi
  
  sleep 1  # Rate limit protection
done

echo ""
echo "📊 Results: $HEALTHY healthy | $RECOVERED auto-recovered | $FAILED failed"
```

---

## 4. Pre-Deployment Backup & Deploy

**Goal:** Back up → deploy → verify rollback point  
**Time:** ~30 minutes (backup time varies)

```python
# Python version using SDK
from xcloud_sdk import XCloudAPI, XCloudDeployer
from xcloud_async import AsyncPoller, DeploymentTracker
import time

api = XCloudAPI()
deployer = XCloudDeployer(api)
poller = AsyncPoller(api)
tracker = DeploymentTracker()

SITE_UUID = "your-site-uuid"
DEPLOY_ID = f"deploy-{int(time.time())}"

print(f"🚀 Starting deployment {DEPLOY_ID}")

# 1. Track deployment start
tracker.start_deployment(DEPLOY_ID, site_uuid=SITE_UUID)

# 2. Backup
print("Step 1: Creating backup...")
api.trigger_backup(SITE_UUID)
tracker.update_deployment(DEPLOY_ID, stage="backup_triggered")

# 3. Wait for backup (or proceed with timeout)
time.sleep(15)  # Give backup 15 seconds to initiate

# 4. Deploy
print("Step 2: Deploying application...")
# Your deployment logic here
# e.g., SSH + git pull, rsync, docker-compose up
tracker.update_deployment(DEPLOY_ID, stage="deploying")

# 5. Verify
print("Step 3: Verifying...")
status = api.get_site_status(SITE_UUID)
if status['status'] == 'provisioned':
    tracker.complete_deployment(DEPLOY_ID, success=True)
    print(f"✅ Deployment {DEPLOY_ID} complete")
else:
    tracker.complete_deployment(DEPLOY_ID, success=False)
    print(f"❌ Deployment {DEPLOY_ID} failed - rollback from backup")
```

---

## 5. Multi-Site SSL Renewal

**Goal:** Renew expiring SSL certs across all sites  
**Time:** ~1 minute per site  
**Schedule:** Weekly cron check

```bash
#!/bin/bash
# Renew all SSL certificates expiring within 30 days

RENEWED=0
CURRENT_DATE=$(date +%s)
THRESHOLD_DATE=$((CURRENT_DATE + 2592000))  # 30 days

echo "🔒 SSL renewal check: $(date)"

curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq -r '.data.items[] | "\(.uuid) \(.domain) \(.ssl_status) \(.ssl_expires_at)"' | \
  while read SITE_UUID DOMAIN SSL_STATUS SSL_EXPIRES; do
    
    # Parse expiration date
    if [ -n "$SSL_EXPIRES" ] && [ "$SSL_EXPIRES" != "null" ]; then
      EXPIRES_TS=$(date -d "$SSL_EXPIRES" +%s 2>/dev/null || echo "0")
      
      if [ "$EXPIRES_TS" -lt "$THRESHOLD_DATE" ] || [ "$SSL_STATUS" = "expired" ]; then
        echo "  Renewing: $DOMAIN (expires: $SSL_EXPIRES)"
        
        curl -sS -X POST -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
          -H "Accept: application/json" \
          "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl/renew" | \
          jq '.message'
        
        RENEWED=$((RENEWED + 1))
        sleep 5  # Rate limit protection
      fi
    fi
  done

echo "✅ SSL renewal complete. Renewed: $RENEWED certificates"
```

---

## 6. Disaster Recovery Drill

**Goal:** Test backup restoration  
**Time:** ~30 minutes  
**Use:** Regular DR drills

```bash
#!/bin/bash
SITE_UUID=$1  # Production site UUID

echo "🚨 Disaster Recovery Drill: $(date)"

# 1. List available backups
echo "Available backups:"
BACKUPS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups")

echo "$BACKUPS" | jq '.data.items[0:5][] | {id, created_at, size: (.size | if . > 1000000 then "\(. / 1000000 | round | tostring) MB" else "\(. | tostring) bytes" end), status}'

# 2. Select most recent backup
BACKUP_ID=$(echo "$BACKUPS" | jq -r '.data.items[0].id')
BACKUP_DATE=$(echo "$BACKUPS" | jq -r '.data.items[0].created_at')

echo ""
echo "Selected backup: $BACKUP_ID ($BACKUP_DATE)"
echo ""
read -p "Proceed with restoration? This will overwrite current site. [yes/no]: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ DR drill cancelled."
  exit 0
fi

# 3. Restore
echo "Restoring..."
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/restore" \
  -d "{\"backup_id\": \"$BACKUP_ID\"}" | jq '.message'

# 4. Poll until restored
for i in $(seq 1 120); do
  STATUS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq -r '.data.status')
  
  printf "\r  Restoring: %s (attempt %d/120)" "$STATUS" "$i"
  
  if [ "$STATUS" = "provisioned" ]; then
    echo ""
    echo "✅ DR drill complete — backup restored successfully"
    break
  fi
  sleep 15
done
```
