# OPERATE: Monitor & Maintain

**Intent:** Monitor fleet health, manage logs, track performance, automate recovery, and maintain operational visibility.

**When to use this:**
- Daily health checks
- Performance monitoring
- Log analysis
- Automated recovery
- Status reporting
- Capacity planning

---

## Workflows

### 1. Fleet Health Check

**Goal:** Verify all servers and sites are healthy  
**Inputs:** None (scans entire infrastructure)  
**Output:** Health report with warnings

**Steps:**

```bash
# 1. Check API connectivity
curl -sS https://app.xcloud.host/api/v1/health | jq

# 2. List all servers and their status
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | jq '.data.items[] | {name, status, ip_address, site_count: (.sites_count // 0)}'

# 3. List all sites and their status
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=100&status=provisioned" | jq '.data.items[] | {domain, status, ssl_status, php_version}'

# 4. Check for recent errors
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=50" | jq '.data.items[] | select(.status != "provisioned") | {domain, status, updated_at}'
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()

# Get comprehensive fleet health
health = deployer.get_fleet_health()

print(f"✅ Servers: {health['servers']['total']} ({health['servers']['active']} active)")
print(f"✅ Sites: {health['sites']['total']} ({health['sites']['provisioned']} provisioned)")

if health['issues']:
    print(f"⚠️  Issues found:")
    for issue in health['issues']:
        print(f"  - {issue['domain']}: {issue['status']}")
```

---

### 2. Monitor Site Health

**Goal:** Watch single site for issues  
**Inputs:** Site UUID  
**Output:** Real-time status, alerts for problems

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. Get site overview
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data | {domain, status, php_version, ssl_status}'

# 2. Check site status (provisioning, provisioned, failed, etc.)
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq '.data | {status, last_check, health}'

# 3. View recent events (deploys, backups, errors)
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=20" | jq '.data.items[] | {created_at, event_type, status, message}'

# 4. Check SSL certificate status
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl" | jq '.data | {provider, status, expires_at, issuer}'

# 5. View backups and last backup date
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | jq '.data.items[0:3] | map({created_at, size, status})'

# 6. Real-time health: Monitor endpoint (polling)
watch -n 30 "curl -sS -H 'Authorization: Bearer $XCLOUD_API_TOKEN' -H 'Accept: application/json' https://app.xcloud.host/api/v1/sites/$SITE_UUID/status | jq '.data.status'"
```

---

### 3. Get Site Logs

**Goal:** Access site error/access logs for debugging  
**Inputs:** Site UUID  
**Output:** Log entries filtered by type

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. Get SSH config to access logs directly
SSH_CONFIG=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh")

SITE_USER=$(echo "$SSH_CONFIG" | jq -r '.data.site_user')
SERVER_IP=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq -r '.data.server_ip')

# 2. View WordPress error log
ssh "$SITE_USER@$SERVER_IP" "tail -f ~/public_html/wp-content/debug.log" | head -50

# 3. View web server access log
ssh "$SITE_USER@$SERVER_IP" "tail -f ~/logs/access.log" | head -50

# 4. View PHP-FPM error log
ssh "$SITE_USER@$SERVER_IP" "tail -f ~/logs/php-fpm.log" | head -50

# 5. View recent events from API (structured logs)
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events" | jq '.data.items[] | select(.level == "error") | {created_at, message}'
```

---

### 4. Automatic Backup Before Deployments

**Goal:** Create backup point before applying updates  
**Inputs:** Server UUID or site UUID  
**Output:** Backup created, ready for rollback

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. Trigger backup
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backup" | jq '.message'

# 2. Wait for backup to complete (up to 30 minutes)
for i in {1..180}; do
  STATUS=$(curl -sS \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | jq -r '.data.items[0].status')
  
  echo "[$i/180] Backup status: $STATUS"
  
  if [ "$STATUS" = "completed" ]; then
    echo "✅ Backup complete"
    break
  fi
  
  sleep 10
done

# 3. Verify backup exists
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | jq '.data.items[0] | {id, created_at, size, status}'

# Now safe to deploy
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()

# Backup all sites
results = deployer.backup_all_sites()

for result in results:
    print(f"{result['domain']}: {result['status']}")

print(f"✅ {len([r for r in results if r['status'] == 'backup_triggered'])} backups initiated")
```

---

### 5. Auto-Recovery: Restart Failed Site

**Goal:** Automatically recover site from 502 error  
**Inputs:** Site UUID  
**Output:** Site restarted and verified healthy

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. Detect 502 error
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://your-site.com)

if [ "$HTTP_STATUS" = "502" ]; then
  echo "⚠️  Site returned 502, attempting recovery..."
  
  # 2. Restart PHP-FPM via xCloud
  curl -sS -X POST \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/restart" | jq '.message'
  
  # 3. Wait for restart
  sleep 10
  
  # 4. Verify recovered
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://your-site.com)
  
  if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Site recovered"
  else
    echo "❌ Recovery failed. See TROUBLESHOOT.md"
  fi
fi
```

---

### 6. Monitoring Dashboard

**Goal:** Set up centralized monitoring view  
**Inputs:** List of site UUIDs  
**Output:** Real-time dashboard view

**Steps:**

```bash
# Create dashboard script
cat > ~/monitor-fleet.sh << 'MONITOR'
#!/bin/bash
while true; do
  clear
  echo "=== xCloud Fleet Monitoring ==="
  echo "Last update: $(date)"
  echo ""
  
  # Servers
  echo "📦 SERVERS"
  curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/servers?per_page=10" | \
    jq '.data.items[] | "\(.name): \(.status)"'
  
  echo ""
  echo "🌐 SITES (Top 10)"
  curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites?per_page=10" | \
    jq '.data.items[] | "\(.domain): \(.status) [SSL: \(.ssl_status)]"'
  
  echo ""
  echo "⚠️  ISSUES"
  curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites?per_page=100" | \
    jq '.data.items[] | select(.status != "provisioned") | "\(.domain): \(.status)"'
  
  sleep 60
done
MONITOR

chmod +x ~/monitor-fleet.sh
./~/monitor-fleet.sh
```

---

## Checklist

- [ ] All servers responding to API
- [ ] All sites showing `provisioned` status
- [ ] SSL certificates valid and not near expiration
- [ ] Latest backups exist (< 7 days old)
- [ ] No recent error events
- [ ] PHP-FPM running on all sites
- [ ] Monitoring configured
- [ ] Alert thresholds set

---

## Safe Operation Rules

✅ **Always do:**
- Check backups before making changes
- Monitor recovery attempts
- Document incidents
- Test health checks regularly

❌ **Never do:**
- Assume health check means full functionality
- Skip backups before risky changes
- Ignore SSL expiration warnings
- Restart multiple sites simultaneously without staggering

---

## Common Issues & Recovery

| Issue | Detection | Recovery |
|-------|-----------|----------|
| 502 Error | HTTP status check | See Auto-Recovery above |
| SSL Expired | `ssl_status: expired` | Run `curl -X POST .../sites/{uuid}/ssl/renew` |
| 100% Disk | Check `disk_usage` | Move/delete old backups |
| PHP-FPM Crashed | Site unresponsive | Restart via dashboard |
| OOM (Out of Memory) | Server slow | Increase swap or resize |

---

## Troubleshooting

See `docs/ERROR-HANDLING.md` for detailed error recovery patterns.
