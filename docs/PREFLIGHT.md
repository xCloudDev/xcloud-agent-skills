# PREFLIGHT: Verification Checklist

Complete this checklist before starting any major operation.

---

## Pre-Deployment Checklist

Use before deploying a new WordPress site or application.

```
Infrastructure Ready
├─ [ ] API token valid and has required scopes
├─ [ ] Target server is active (status: active)
├─ [ ] Server has available capacity (< 80% disk used)
├─ [ ] PHP version desired is available on server
├─ [ ] Network connectivity verified (can ping server)
└─ [ ] DNS provider configured (Cloudflare if using)

Domain & DNS
├─ [ ] Domain registered and owned
├─ [ ] Domain registrar allows NS modification
├─ [ ] Cloudflare account created (if using)
├─ [ ] DNS records point to server IP
├─ [ ] DNS propagation verified (nslookup works)
└─ [ ] TTL set appropriately (3600+ for production)

Application Ready
├─ [ ] WordPress/app code prepared
├─ [ ] Database schema ready (if not auto-created)
├─ [ ] Configuration files have placeholders
├─ [ ] Environment variables documented
├─ [ ] SSH keys for deployment added
└─ [ ] Initial user/admin created

Security
├─ [ ] Strong password for admin/database user
├─ [ ] SSH keys configured (prefer Ed25519)
├─ [ ] Firewall rules allow 80/443 (if applicable)
├─ [ ] SSL provider selected (Let's Encrypt recommended)
└─ [ ] Backup location configured

Monitoring & Alerts
├─ [ ] Health checks configured
├─ [ ] Backup schedule set
├─ [ ] Uptime monitoring enabled
├─ [ ] Alert recipients configured
└─ [ ] Contact info for escalation ready
```

---

## Pre-Maintenance Checklist

Use before making changes to running sites.

```
Backup & Safety
├─ [ ] Recent backup exists (< 7 days old)
├─ [ ] Backup verified (restore tested if critical)
├─ [ ] Rollback plan documented
├─ [ ] Maintenance window communicated
└─ [ ] Approval obtained for major changes

Environment
├─ [ ] Changes tested in staging first
├─ [ ] No other changes happening simultaneously
├─ [ ] Monitoring alerts active
├─ [ ] On-call support available
└─ [ ] Estimated downtime calculated

Site State
├─ [ ] Site responding to requests
├─ [ ] SSL certificate valid
├─ [ ] Database accessible
├─ [ ] All services running
└─ [ ] Recent error logs reviewed
```

---

## Pre-Troubleshooting Checklist

Use before diagnosing issues.

```
Initial Assessment
├─ [ ] Issue scope defined (single site vs server vs API)
├─ [ ] Issue timeline documented (when did it start?)
├─ [ ] Reproduction steps recorded
├─ [ ] Affected users/sites listed
└─ [ ] Service level impact assessed

API Access
├─ [ ] API token valid (401 error check)
├─ [ ] API token has required scopes (403 error check)
├─ [ ] Rate limits not exceeded (429 error check)
├─ [ ] API connectivity verified (curl -s health endpoint)
└─ [ ] Correct API base URL used

Data Collection
├─ [ ] Recent logs gathered
├─ [ ] Recent events exported from API
├─ [ ] Site/server status captured
├─ [ ] Configuration documented
└─ [ ] Error messages recorded verbatim

Isolation
├─ [ ] Issue isolated to specific resource
├─ [ ] Other resources verified as healthy
├─ [ ] Pattern identified (all sites? specific type?)
└─ [ ] Root cause hypothesis formed
```

---

## Quick Check Scripts

### API Health Check

```bash
#!/bin/bash

echo "🔍 Preflight API Check"

# 1. Health
curl -sS https://app.xcloud.host/api/v1/health | jq '.data.status'

# 2. Auth
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  https://app.xcloud.host/api/v1/user | jq '.data.email'

# 3. Servers
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=1" | \
  jq '.data.items[0] | {status}'

echo "✅ Preflight complete"
```

### Server Readiness Check

```bash
#!/bin/bash

SERVER_UUID=$1

echo "🔍 Server Readiness Check: $SERVER_UUID"

# 1. Server status
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | \
  jq '.data | {status, os, ip_address}'

# 2. Disk usage
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/monitoring" | \
  jq '.data.disk'

# 3. Existing sites count
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?server_uuid=$SERVER_UUID" | \
  jq '.data.items | length'

# 4. PHP versions available
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/php-versions" | \
  jq '.data.items[] | select(.status == "available") | .version'

echo "✅ Server ready"
```

### Site Health Check

```bash
#!/bin/bash

SITE_UUID=$1

echo "🔍 Site Health Check: $SITE_UUID"

SITE=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID")

echo "Domain: $(echo $SITE | jq -r '.data.domain')"
echo "Status: $(echo $SITE | jq -r '.data.status')"
echo "PHP: $(echo $SITE | jq -r '.data.php_version')"
echo "SSL: $(echo $SITE | jq -r '.data.ssl_status')"

# HTTP test
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$(echo $SITE | jq -r '.data.domain'))
echo "HTTP: $HTTP_CODE"

# Backup check
BACKUPS=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | jq '.data.items | length')
echo "Backups: $BACKUPS"

if [ "$HTTP_CODE" = "200" ] && [ "$(echo $SITE | jq -r '.data.status')" = "provisioned" ]; then
  echo "✅ Site healthy"
else
  echo "⚠️  Site issues detected"
fi
```

---

## Preflight Automation

### Minimal Pre-Deploy

```bash
#!/bin/bash
# Run this 5 minutes before deploying

SERVER_UUID=$1
DOMAIN=$2

set -e

echo "⏳ Running preflight checks..."

# 1. API auth
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  https://app.xcloud.host/api/v1/user > /dev/null || exit 1

# 2. Server status
SERVER_STATUS=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | \
  jq -r '.data.status')

if [ "$SERVER_STATUS" != "active" ]; then
  echo "❌ Server not active: $SERVER_STATUS"
  exit 1
fi

# 3. Domain resolution
dig $DOMAIN +short > /dev/null || {
  echo "⚠️  Domain not resolving yet (expected, will resolve after deployment)"
}

echo "✅ Preflight passed"
```

---

## Troubleshooting Preflight

If preflight checks fail:

| Check | Fails | Next Step |
|-------|-------|-----------|
| API health | ❌ | Check internet connection, verify API URL |
| API auth (401) | ❌ | Verify token value and format |
| API auth (403) | ❌ | Check token scopes: `read:servers`, `write:sites`, etc. |
| Server status | ❌ | Server may be initializing, wait 5 minutes |
| Disk full | ❌ | Delete old backups or contact support |
| Domain DNS | ❌ | Normal before deployment, will resolve after |

---

## Checklist PDF Download

Print this checklist or save as PDF before deployment:

```bash
# Generate checklist (requires wkhtmltopdf)
wkhtmltopdf https://xcloud.host/preflight.md /tmp/preflight.pdf
```

Or copy the markdown above to a PDF editor.
