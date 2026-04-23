# xCloud API Error Handling Guide

How to handle common failures gracefully.

---

## Authentication Errors

### 401 Unauthorized

**Cause:** Token is invalid, expired, or missing

**Response:**
```json
{
  "message": "Unauthenticated",
  "errors": []
}
```

**How to fix:**

1. **Check token exists:**
   ```bash
   echo $XCLOUD_API_TOKEN
   ```

2. **Verify token is valid:**
   ```bash
   curl -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
     https://app.xcloud.host/api/v1/user
   ```

3. **If expired:** Get new token at https://app.xcloud.host/settings/api-tokens

**Agent recovery:**
```python
try:
    user = api.get_user()
except XCloudAuthError:
    print("❌ Invalid token. Agent cannot proceed.")
    print("⚠️  Required: New API token from https://app.xcloud.host/settings/api-tokens")
    alert_operator("Authentication failed - manual token update needed")
    sys.exit(1)
```

---

## Rate Limiting (429)

**Cause:** Exceeded 60 requests per minute

**Response:**
```json
{
  "message": "Too Many Requests",
  "errors": []
}
```

**Headers:**
```
Retry-After: 45
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1713816000
```

**How to fix:**

1. **Back off exponentially:**
   ```python
   import time
   retry_after = int(response.headers.get("Retry-After", 60))
   time.sleep(retry_after)
   retry()
   ```

2. **Use the SDK helper:**
   ```python
   from xcloud_async import RateLimitManager
   
   limiter = RateLimitManager()
   for request in batch:
       limiter.wait_if_needed()
       api.create_wordpress_site(...)
   ```

3. **Batch operations:**
   ```python
   from xcloud_async import OperationBatcher
   
   batcher = OperationBatcher(api)
   for domain in domains:
       batcher.queue_operation({
           "type": "create_site",
           "domain": domain,
           "server_uuid": server_uuid
       })
   
   results = batcher.execute_batch()  # Rate-limited automatically
   ```

**Agent recovery:**
```python
@backoff.on_exception(
    backoff.expo,
    XCloudRateLimitError,
    max_tries=3
)
def create_site_with_retry(domain, server_uuid):
    return api.create_wordpress_site(domain=domain, server_uuid=server_uuid)

site = create_site_with_retry(domain, server_uuid)
```

---

## Timeout Errors

**Cause:** API or server is slow to respond

**Response:**
```
requests.exceptions.ConnectTimeout
requests.exceptions.ReadTimeout
requests.exceptions.Timeout
```

**How to fix:**

1. **Increase timeout (last resort):**
   ```python
   api = XCloudAPI(token="...")
   api.REQUEST_TIMEOUT = 60  # from default 30
   ```

2. **Retry with backoff:**
   ```python
   from xcloud_async import AsyncPoller
   
   poller = AsyncPoller(api)
   result = poller.retry_with_backoff(
       api.get_site,
       site_uuid,
       max_retries=3
   )
   ```

3. **Check if server is degraded:**
   ```bash
   curl https://app.xcloud.host/api/v1/health
   ```

**Agent recovery:**
```python
try:
    site = api.create_wordpress_site(domain, server_uuid)
except XCloudTimeoutError:
    print(f"⚠️  Site creation timeout - may still be provisioning")
    print(f"Check status later: GET /sites/<uuid>/status")
    
    # Store for later verification
    pending_ops.append({
        "domain": domain,
        "started_at": datetime.now(),
        "check_after": datetime.now() + timedelta(minutes=5)
    })
```

---

## 502 Bad Gateway (Site Provisioning)

**Cause:** Site is provisioning (takes 5-30 minutes), not yet ready

**Response:**
```
HTTP 502 Bad Gateway
nginx: no upstream available
```

**This is NORMAL during provisioning!**

**How to fix:**

1. **Don't panic — wait and poll:**
   ```python
   from xcloud_async import AsyncPoller
   
   poller = AsyncPoller(api)
   site = poller.poll_until_ready(
       "site",
       site_uuid,
       timeout=600,  # 10 minutes
       interval=15   # Check every 15 seconds
   )
   ```

2. **Check provisioning status:**
   ```python
   status = api.get_site_status(site_uuid)
   if status.get("provisioned"):
       return "Site ready!"
   else:
       return "Still provisioning..."
   ```

3. **Check recent events:**
   ```python
   events = api.get_site_events(site_uuid)
   for event in events:
       print(f"{event['type']}: {event['status']}")
   ```

**Agent recovery:**
```python
site = api.create_wordpress_site(domain=domain, server_uuid=server_uuid)
site_uuid = site['uuid']

print(f"⏳ Site provisioning... (check back in 5 minutes)")

# Schedule check later
from xcloud_async import AsyncPoller

poller = AsyncPoller(api)
try:
    ready_site = poller.poll_until_ready("site", site_uuid, timeout=600)
    print(f"✅ Site ready: https://{ready_site['domain']}")
except TimeoutError:
    alert_operator(f"Site {domain} stuck provisioning after 10 min")
```

---

## 404 Not Found

**Cause:** Resource doesn't exist (wrong UUID, deleted, etc.)

**Response:**
```json
{
  "message": "Not found",
  "errors": []
}
```

**How to fix:**

1. **Verify UUID is correct:**
   ```python
   sites = api.list_sites()
   for site in sites['items']:
       print(f"{site['name']}: {site['uuid']}")
   ```

2. **Check if resource was deleted:**
   ```python
   try:
       site = api.get_site(site_uuid)
   except XCloudAPIError as e:
       if "404" in str(e):
           print(f"Site {site_uuid} no longer exists")
   ```

**Agent recovery:**
```python
def get_site_safe(site_uuid):
    try:
        return api.get_site(site_uuid)
    except XCloudAPIError as e:
        if "404" in str(e):
            print(f"⚠️  Site {site_uuid} not found - may have been deleted")
            return None
        raise
```

---

## 403 Forbidden

**Cause:** Token doesn't have required scope

**Response:**
```json
{
  "message": "Forbidden",
  "errors": []
}
```

**How to fix:**

1. **Check required scope:**
   ```
   read:servers     — list/view servers
   write:servers    — reboot servers, create sites
   read:sites       — list/view sites
   write:sites      — backup, cache purge, SSH config
   *                — all scopes
   ```

2. **Verify token has correct scope:**
   - Go to https://app.xcloud.host/settings/api-tokens
   - Check token's "Scopes" column
   - Regenerate if needed with correct scopes

**Agent recovery:**
```python
try:
    # This requires write:sites scope
    api.purge_cache(site_uuid)
except XCloudAuthError as e:
    if "403" in str(e):
        alert_operator(f"Token lacks required scope for this operation")
        print("Go to: https://app.xcloud.host/settings/api-tokens")
    raise
```

---

## 422 Unprocessable Entity

**Cause:** Invalid request payload

**Response:**
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "domain": ["The domain field is required."],
    "php_version": ["The php_version must be one of: 7.4, 8.0, 8.1, 8.2, 8.3"]
  }
}
```

**How to fix:**

1. **Check all required fields:**
   ```python
   # For WordPress creation:
   # - domain (required for live mode)
   # - php_version (required)
   # - ssl.provider (required for live mode)
   ```

2. **Validate values:**
   ```python
   valid_php = ["7.4", "8.0", "8.1", "8.2", "8.3"]
   if php_version not in valid_php:
       raise ValueError(f"Invalid PHP: {php_version}, must be one of {valid_php}")
   ```

**Agent recovery:**
```python
try:
    site = api.create_wordpress_site(
        domain=domain,
        php_version="9.5"  # INVALID
    )
except XCloudAPIError as e:
    if "422" in str(e):
        print(f"❌ Invalid request: {e}")
        print("Valid PHP versions: 7.4, 8.0, 8.1, 8.2, 8.3")
    raise
```

---

## SSL Certificate Errors

**Cause:** Let's Encrypt provisioning failed or certificate is invalid

**Symptoms:**
- Browser warning "SSL_ERROR_BAD_CERT_DOMAIN"
- API reports SSL status as "pending" for > 1 hour
- TLS handshake failures

**How to fix:**

1. **Check SSL status:**
   ```python
   site = api.get_site(site_uuid)
   print(site.get('ssl', {}).get('status'))  # pending, active, failed, expired
   ```

2. **Wait for Let's Encrypt provisioning (takes ~5 min):**
   ```python
   import time
   for i in range(30):  # Check for 15 minutes
       site = api.get_site(site_uuid)
       if site.get('ssl', {}).get('status') == 'active':
           print("✅ SSL ready")
           break
       time.sleep(30)
   ```

3. **If stuck in "pending":**
   - Check domain DNS is pointing to server
   - Verify domain is not behind CloudFlare proxy
   - Try Let's Encrypt retry via xCloud dashboard

**Agent recovery:**
```python
def verify_ssl_ready(site_uuid, max_wait=300):
    start = time.time()
    while time.time() - start < max_wait:
        site = api.get_site(site_uuid)
        ssl_status = site.get('ssl', {}).get('status')
        
        if ssl_status == 'active':
            return True
        elif ssl_status == 'failed':
            alert_operator(f"SSL provisioning failed for {site['domain']}")
            return False
        
        time.sleep(10)
    
    alert_operator(f"SSL provisioning timeout for {site['domain']}")
    return False
```

---

## Database Connection Issues

**Cause:** WordPress site can't connect to database (rare, but happens on new sites)

**Symptoms:**
- "Error establishing a database connection"
- Site returns HTTP 500
- "wp-config.php" files missing DB credentials

**How to fix:**

1. **SSH into site and check database:**
   ```bash
   ssh user@site.domain
   wp db check --path=/var/www/public
   wp db info
   ```

2. **Restart WordPress/PHP:**
   ```bash
   sudo systemctl restart php-fpm
   sudo systemctl restart nginx
   ```

3. **Verify WordPress config:**
   ```bash
   wp config get DB_HOST
   wp config get DB_NAME
   ```

**Agent recovery:**
```python
def check_wordpress_health(site_uuid, domain):
    # Check HTTP response
    try:
        response = requests.get(f"https://{domain}", timeout=10)
        if response.status_code == 500:
            print("⚠️  WordPress error - may be database issue")
            
            # SSH and check
            ssh_config = api.get_site_ssh_config(site_uuid)
            run_ssh_command(ssh_config, "wp db check")
    except Exception as e:
        print(f"⚠️  Health check failed: {e}")
```

---

## PHP Execution Issues

**Cause:** PHP files can't execute (permissions, syntax, memory limits)

**Symptoms:**
- PHP files download instead of execute
- "Segmentation fault" errors
- "Out of memory" errors

**How to fix:**

1. **Check PHP syntax:**
   ```bash
   ssh user@site.domain
   php -l /var/www/public/index.php
   ```

2. **Increase PHP memory limit:**
   ```bash
   wp config set WP_MEMORY_LIMIT 256M
   wp config set WP_MAX_MEMORY_LIMIT 512M
   ```

3. **Check file permissions:**
   ```bash
   ls -la /var/www/public/
   # Files should be www-data:www-data
   ```

---

## Network Connectivity Issues

### Agent can't reach xCloud API

**Cause:** Network firewall, DNS, or ISP blocking

**Symptoms:**
```
requests.exceptions.ConnectionError: Failed to establish a new connection
Name or service not known
```

**How to fix:**

1. **Test DNS:**
   ```bash
   nslookup app.xcloud.host
   ```

2. **Test connectivity:**
   ```bash
   curl -v https://app.xcloud.host/api/v1/health
   ```

3. **Check firewall:**
   - Whitelist https://app.xcloud.host (port 443)
   - Check ISP isn't blocking

---

## Quick Reference Table

| Error | HTTP Code | Cause | Fix |
|-------|-----------|-------|-----|
| Unauthorized | 401 | Invalid token | Get new token |
| Forbidden | 403 | Missing scope | Update token scopes |
| Not Found | 404 | Wrong UUID | List resources, get correct UUID |
| Unprocessable | 422 | Invalid data | Check required fields |
| Too Many Requests | 429 | Rate limit | Back off, wait, retry |
| Bad Gateway | 502 | Provisioning | Wait & poll `/status` |
| Timeout | 0 | Server slow | Retry with exponential backoff |
| SSL Error | TLS | Certificate issue | Wait for Let's Encrypt or use HTTP |
| Database Error | 500 | DB connection | SSH and check `wp db check` |

---

## Testing Error Scenarios

### Test 401 (invalid token)
```bash
curl -H "Authorization: Bearer invalid" https://app.xcloud.host/api/v1/user
```

### Test 404 (wrong UUID)
```bash
XCLOUD_API_TOKEN="..." curl -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  https://app.xcloud.host/api/v1/sites/invalid-uuid-12345
```

### Test 429 (rate limit)
```bash
# Make 70 rapid requests (exceeds 60/min)
for i in {1..70}; do curl -s https://app.xcloud.host/api/v1/health; done
```

---

## Getting Help

1. **Check this guide** — most issues are covered above
2. **Check API docs** — https://app.xcloud.host/api/v1/docs
3. **Check recent events** — `GET /sites/{uuid}/events`
4. **Contact xCloud support** — support@xcloud.host
