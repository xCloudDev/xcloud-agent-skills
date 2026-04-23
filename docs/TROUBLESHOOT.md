# TROUBLESHOOT: Diagnose & Fix Issues

**Intent:** Diagnose failures, recover from errors, and restore service.

**When to use this:**
- Site or server not working
- Deployment failed
- SSL certificate errors
- 502 or other HTTP errors
- Database connectivity issues
- Performance degradation

---

## Quick Diagnosis Tree

```
Problem?
├─ Site returns 502 → See: 502 Error Recovery
├─ Site not accessible (DNS) → See: Domain Resolution
├─ SSL certificate invalid → See: SSL Certificate Issues
├─ Slow performance → See: Performance Degradation
├─ Database error → See: Database Issues
├─ PHP execution error → See: PHP Execution Errors
├─ API errors (401, 403, 429) → See: API Authorization & Rate Limits
├─ Deployment failed → See: Deployment Failures
└─ Site stuck provisioning → See: Provisioning Timeout
```

---

## Error Recovery Guide

For detailed recovery patterns by error code, see `docs/ERROR-HANDLING.md`. This section provides workflows.

---

## 1. 502 Bad Gateway Error Recovery

**Symptoms:** Site returns HTTP 502, but xCloud API shows `provisioned`

**Diagnostic steps:**

```bash
SITE_UUID='your-site-uuid'
DOMAIN='your-site.com'

# 1. Verify the 502 is real
curl -v https://$DOMAIN 2>&1 | grep "502\|Bad Gateway"

# 2. Check site status in API
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq '.data.status'

# 3. View recent error events
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=20" | \
  jq '.data.items[] | select(.status == "failed")'

# 4. Check SSH access (get site user)
SSH_USER=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" | jq -r '.data.site_user')

echo "Site user: $SSH_USER"

# 5. SSH in and check PHP-FPM
SERVER_IP=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq -r '.data.server_ip')

ssh "$SSH_USER@$SERVER_IP" "ps aux | grep php-fpm"

# 6. Check site error log
ssh "$SSH_USER@$SERVER_IP" "tail -50 ~/logs/error.log"
```

**Most common 502 causes & recovery:**

| Cause | Detection | Recovery |
|-------|-----------|----------|
| PHP-FPM crashed | Process not found | Restart via dashboard or API |
| Missing site user | "sudo: unknown user" in logs | Restore via snapshot/backup |
| Out of disk space | 100% disk usage | Delete old backups/files |
| Memory exhausted | OOM killer in logs | Increase swap or restart PHP |
| Database offline | Connection refused in error.log | Restart MySQL/PostgreSQL |

**Recovery actions:**

```bash
# Option 1: Restart site (graceful)
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/restart" | jq '.message'

# Wait and verify
sleep 10
curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN

# Option 2: Restore from backup (if above fails)
# See: Backup Restoration below
```

---

## 2. Domain Resolution Issues

**Symptoms:** Domain not resolving or pointing to wrong IP

**Diagnostic steps:**

```bash
DOMAIN='your-site.com'
SITE_UUID='your-site-uuid'

# 1. Check domain in xCloud
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | \
  jq '.data | {domain, status, server_ip}'

# 2. Check DNS resolution
nslookup $DOMAIN
dig $DOMAIN +short

# 3. Check Cloudflare (if using)
# Go to: https://dash.cloudflare.com/ and verify DNS records

# 4. Check expected vs actual IP
EXPECTED_IP=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq -r '.data.server_ip')

ACTUAL_IP=$(dig $DOMAIN +short | head -1)

echo "Expected: $EXPECTED_IP"
echo "Actual: $ACTUAL_IP"

if [ "$EXPECTED_IP" != "$ACTUAL_IP" ]; then
  echo "⚠️  IP mismatch! Update DNS records"
fi
```

**Recovery:**

```bash
# 1. Update DNS records in Cloudflare/registrar
# A record for $DOMAIN -> $EXPECTED_IP

# 2. Wait for TTL to expire (usually 5-10 minutes)
# Check propagation: https://www.whatsmydns.net

# 3. Verify resolution
dig $DOMAIN +short

# 4. Test HTTP access
curl -v https://$DOMAIN 2>&1 | head -20
```

---

## 3. SSL Certificate Issues

**Symptoms:** "Certificate expired", "invalid certificate", or browser warnings

**Diagnostic steps:**

```bash
SITE_UUID='your-site-uuid'
DOMAIN='your-site.com'

# 1. Check certificate status in API
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl" | \
  jq '.data | {provider, status, expires_at, valid_from, issuer}'

# 2. Check actual certificate
openssl s_client -connect $DOMAIN:443 -servername $DOMAIN < /dev/null | \
  openssl x509 -text -noout | \
  grep -A 1 "Validity\|Issuer"

# 3. Check for expiration
EXPIRES=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl" | \
  jq -r '.data.expires_at')

NOW=$(date +%s)
EXPIRES_EPOCH=$(date -d "$EXPIRES" +%s)
DAYS_LEFT=$(( ($EXPIRES_EPOCH - $NOW) / 86400 ))

echo "Days until expiration: $DAYS_LEFT"

if [ "$DAYS_LEFT" -lt 0 ]; then
  echo "❌ Certificate EXPIRED"
elif [ "$DAYS_LEFT" -lt 30 ]; then
  echo "⚠️  Certificate expiring soon"
fi
```

**Recovery:**

```bash
SITE_UUID='your-site-uuid'

# 1. Renew certificate
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl/renew" | jq '.message'

# 2. Wait for renewal (usually 30 seconds)
sleep 30

# 3. Verify new certificate
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl" | \
  jq '.data.expires_at'

# 4. Clear browser cache and test
curl -v --insecure https://$DOMAIN 2>&1 | grep "subject=\|issuer="
```

---

## 4. Deployment Failures

**Symptoms:** Git push fails, deployment doesn't start, or WordPress installation incomplete

**Diagnostic steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. Check deployment events
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=50" | \
  jq '.data.items[] | select(.event_type == "deployment")'

# 2. Get deployment logs (if available)
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/deployment-logs" | jq '.data'

# 3. Check Git status
GIT_STATUS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/git" | jq '.data')

echo "Git configured: $(echo $GIT_STATUS | jq '.repository')"

# 4. Check SSH keys
SSH_CONFIG=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" | jq '.data')

echo "SSH keys: $(echo $SSH_CONFIG | jq '.ssh_public_keys | length')"
```

**Recovery:**

```bash
# 1. Verify SSH access from deployment machine
ssh -i ~/.ssh/deploy_key site-user@server "ls -la ~/public_html"

# 2. If SSH fails: Update SSH keys
curl -sS -X PUT \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
  -d '{
    "authentication_mode": "public_key",
    "ssh_public_keys": ["ssh-ed25519 AAAA... your-key"]
  }' | jq '.message'

# 3. Retry deployment
# Push to repo again, or manually deploy via SSH
```

---

## 5. Database Connection Issues

**Symptoms:** "Can't connect to database", WordPress shows database error

**Diagnostic steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. Check site databases
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/databases" | \
  jq '.data.items[] | {name, host, port, status}'

# 2. Check WordPress database config
SITE_USER=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" | jq -r '.data.site_user')

SERVER_IP=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq -r '.data.server_ip')

ssh "$SITE_USER@$SERVER_IP" "grep -E 'DB_NAME|DB_HOST|DB_USER' ~/public_html/wp-config.php"

# 3. Test MySQL connectivity
ssh "$SITE_USER@$SERVER_IP" "mysql -h localhost -u wordpress_user -p'password' -D wordpress_db -e 'SELECT 1;'"
```

**Recovery:**

```bash
# 1. Restart database server
SERVER_UUID='your-server-uuid'

curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/restart-database" | jq '.message'

# Wait for restart
sleep 30

# 2. Verify connection
curl -v https://your-site.com 2>&1 | grep -i database
```

---

## 6. Performance Degradation

**Symptoms:** Site is slow, high CPU/memory usage

**Diagnostic steps:**

```bash
SERVER_UUID='your-server-uuid'

# 1. Check server resources
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/monitoring" | \
  jq '.data | {cpu: .cpu, memory: .memory, disk: .disk}'

# 2. Check all sites on server
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?server_uuid=$SERVER_UUID" | \
  jq '.data.items | length'

# 3. Measure response time
time curl -s https://your-site.com > /dev/null
```

**Recovery:**

```bash
# Option 1: Clear caches
SITE_UUID='your-site-uuid'

curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/cache/purge" | jq '.message'

# Option 2: Scale server resources or upgrade PHP
# Contact xCloud support for server upgrades

# Option 3: Optimize WordPress
# - Enable caching (see CONFIGURE.md)
# - Remove unused plugins
# - Update to latest PHP version
```

---

## 7. Backup Restoration

**Goal:** Restore site from backup after corruption or error

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. List available backups
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | \
  jq '.data.items[] | {id, created_at, size, status}'

# 2. Select backup (by ID)
BACKUP_ID='backup-id-from-step-1'

# 3. Restore backup
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/restore" \
  -d '{"backup_id": "'"$BACKUP_ID"'"}' | jq '.message'

# 4. Wait for restoration (can take 10-30 minutes)
for i in {1..180}; do
  STATUS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq -r '.data.status')
  
  echo "[$i/180] Status: $STATUS"
  
  if [ "$STATUS" = "provisioned" ]; then
    echo "✅ Restoration complete"
    break
  fi
  
  sleep 10
done

# 5. Verify site
curl -I https://your-site.com | head -3
```

---

## 8. Provisioning Timeout

**Symptoms:** Site stuck in "provisioning" status for > 20 minutes

**Recovery:**

```bash
SITE_UUID='your-site-uuid'

# 1. Check events for errors
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=50" | \
  jq '.data.items[] | {created_at, event_type, status, message}'

# 2. If no errors and still provisioning (>20 min):
# Option A: Wait longer (provisioning can take up to 30 minutes)
# Option B: Cancel and retry

# Cancel site
curl -sS -X DELETE \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.message'

# Wait 30 seconds
sleep 30

# Recreate site (see DEPLOY.md)
```

---

## Safe Operation Rules

✅ **Always do:**
- Check events log first (often shows root cause)
- Backup before attempting major fixes
- Test recovery in staging first
- Document what you did and results

❌ **Never do:**
- Delete sites without backup
- Ignore error messages
- Make multiple changes simultaneously (hard to debug)
- Assume graceful shutdown isn't needed

---

## When to Contact Support

Contact xCloud support at support@xcloud.host if:
- ❌ Recovery steps don't work
- ❌ API returns 5XX errors
- ❌ Database/infrastructure failure
- ❌ Data loss or corruption
- ❌ Security incident

**Provide to support:**
- Site UUID
- Server UUID
- Timeline of issue
- Steps already taken
- Relevant error messages/logs

---

## Escalation Checklist

Before escalating:
- [ ] Checked recent events for root cause
- [ ] Verified DNS/SSL configuration
- [ ] Checked server resources (CPU, memory, disk)
- [ ] Attempted standard recovery (restart, cache purge)
- [ ] Reviewed ERROR-HANDLING.md for similar error
- [ ] Collected diagnostic data (logs, API responses)
