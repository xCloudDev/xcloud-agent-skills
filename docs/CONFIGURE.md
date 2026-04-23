# CONFIGURE: Change Settings

**Intent:** Manage site configuration, update authentication, modify domain settings, and manage cache/performance settings.

**When to use this:**
- Update SSH/SFTP authentication
- Change domains
- Modify PHP versions
- Enable/disable caching
- Configure monitoring
- Rotate credentials

---

## Workflows

### 1. Update SSH/SFTP Authentication

**Goal:** Change how users authenticate to the site  
**Inputs:** Site UUID, auth mode (password or public_key), credentials  
**Output:** Updated SSH config, verified access

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# Option A: Switch to public key authentication
curl -sS -X PUT \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
  -d '{
    "authentication_mode": "public_key",
    "ssh_public_keys": [
      "ssh-ed25519 AAAA... user@host",
      "ssh-rsa AAAA... another@host"
    ]
  }' | jq '.data | {authentication_mode, ssh_public_keys}'

# Option B: Switch to password authentication
PASSWORD=$(openssl rand -base64 32)
curl -sS -X PUT \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" \
  -d '{
    "authentication_mode": "password",
    "password": "'"$PASSWORD"'"
  }' | jq '.data | {authentication_mode, status}'

# 3. Verify configuration
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" | jq '.data'

# 4. Test access
ssh site-user@site-ip "ls -la" 2>&1 | head -3
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudAPI

api = XCloudAPI()

# Update to public key auth
result = api.update_site_ssh_config(
    site_uuid="your-site-uuid",
    authentication_mode="public_key",
    ssh_public_keys=["ssh-ed25519 AAAA..."]
)

print(f"✅ Auth updated: {result['authentication_mode']}")
```

---

### 2. Change Site Domain

**Goal:** Move site to different domain (with DNS migration)  
**Inputs:** Site UUID, new domain  
**Output:** Site responding on new domain, old domain redirects

**Steps:**

```bash
SITE_UUID='your-site-uuid'
OLD_DOMAIN='old.example.com'
NEW_DOMAIN='new.example.com'

# 1. Check current domain
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data | {uuid, domain, status}'

# 2. Update DNS to point to site IP
# In Cloudflare/registrar: A record pointing $NEW_DOMAIN -> site IP

# 3. Trigger domain update
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{
    "domain": "'"$NEW_DOMAIN"'"
  }' | jq '.data | {domain, status}'

# 4. Renew SSL certificate for new domain
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl/renew" | jq '.message'

# 5. Verify site works on new domain
sleep 10
curl -I https://$NEW_DOMAIN | head -3

# 6. Set up 301 redirect from old domain to new (optional)
# Via WordPress .htaccess or web server config
```

---

### 3. Update PHP Version

**Goal:** Upgrade or downgrade PHP version for a site  
**Inputs:** Site UUID, new PHP version  
**Output:** Site running on new PHP version

**Steps:**

```bash
SITE_UUID='your-site-uuid'
NEW_PHP_VERSION='8.2'

# 1. Check available PHP versions on server
SERVER_UUID='your-server-uuid'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/php-versions" | jq '.data.items[] | {version, status}'

# 2. Check current PHP version
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data.php_version'

# 3. Update PHP version
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{
    "php_version": "'"$NEW_PHP_VERSION"'"
  }' | jq '.message'

# 4. Verify change (may take 30 seconds)
sleep 30
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data.php_version'

# 5. Test site functionality
curl -I https://your-site-domain | grep -i php-version
```

---

### 4. Configure Caching

**Goal:** Enable/disable full-page and object caching  
**Inputs:** Site UUID, cache settings  
**Output:** Cache configuration updated

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# 1. View current cache configuration
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data.cache'

# Option A: Enable both full-page and object caching (recommended)
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{
    "cache": {
      "full_page": true,
      "object_cache": true
    }
  }' | jq '.data.cache'

# Option B: Disable caching (for development)
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{
    "cache": {
      "full_page": false,
      "object_cache": false
    }
  }' | jq '.data.cache'

# 3. Purge cache after enabling
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/cache/purge" | jq '.message'
```

---

### 5. Configure Monitoring

**Goal:** Enable monitoring and alerts for site health  
**Inputs:** Site UUID, monitoring preferences  
**Output:** Monitoring active, alerts configured

**Steps:**

```bash
SITE_UUID='your-site-uuid'
SERVER_UUID='your-server-uuid'

# 1. Get current server monitoring status
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/monitoring" | jq '.data'

# 2. Enable site-level monitoring
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{
    "monitoring": {
      "enabled": true,
      "check_interval": 300,
      "health_checks": ["http", "ssl", "php"]
    }
  }' | jq '.data.monitoring'

# 3. View monitoring dashboard
# https://app.xcloud.host/sites/$SITE_UUID/monitoring
```

---

### 6. Rotate API Tokens

**Goal:** Revoke and create new API tokens for security  
**Inputs:** (from dashboard or existing token)  
**Output:** New token, old token revoked

**Steps:**

```bash
# 1. List current tokens
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/user/tokens" | jq '.data.items[] | {id, name, last_used_at, created_at}'

# 2. Revoke old token by ID
OLD_TOKEN_ID='token-id-from-step-1'
curl -sS -X DELETE \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/user/tokens/$OLD_TOKEN_ID" | jq '.message'

# 3. Create new token via dashboard:
# https://app.xcloud.host/settings/api-tokens

# 4. Update environment variable
export XCLOUD_API_TOKEN='new-token-here'

# 5. Verify new token works
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/user" | jq '.data | {email, api_token_count}'
```

---

## Checklist

- [ ] Site UUID confirmed
- [ ] Current configuration documented
- [ ] Change requirements clear
- [ ] Backup created if needed (see OPERATE.md)
- [ ] Testing plan in place
- [ ] Rollback plan documented
- [ ] Change applied
- [ ] Verification successful

---

## Safe Operation Rules

✅ **Always do:**
- Backup before making major changes
- Test changes in staging first
- Document all configuration changes
- Verify changes with health checks

❌ **Never do:**
- Disable all authentication (password + public keys)
- Downgrade PHP to unsupported versions
- Change domains without DNS update
- Make multiple changes simultaneously

---

## Rollback Procedures

**If domain change breaks site:**
```bash
# Restore original domain via API
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{"domain": "original-domain.com"}'
```

**If PHP version causes errors:**
```bash
# Downgrade to previous version
curl -sS -X PATCH \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" \
  -d '{"php_version": "8.1"}'
```

---

## Troubleshooting

**SSH connection fails after auth change:**
- Wait 30 seconds for config propagation
- Verify SSH key format (Ed25519 preferred)
- Check firewall rules
- See TROUBLESHOOT.md for detailed diagnosis

**Domain not resolving after change:**
- Check DNS propagation: `nslookup domain.com`
- Verify Cloudflare CNAME if using
- Wait up to 5 minutes for TTL expiry
- Check domain registrar settings

**PHP version not supported:**
- Verify version exists: See step 1 of Update PHP Version
- Contact support for other versions
