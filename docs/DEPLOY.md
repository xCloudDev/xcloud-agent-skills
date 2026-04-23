# DEPLOY: Deploy Applications & Sites

**Intent:** Create WordPress sites, auto-provision on code push, containerize applications, and release updates.

**When to use this:**
- Deploy new WordPress sites
- Provision staging environments
- Continuous deployment automation
- Multi-environment releases
- Blueprint-based deployments

---

## Workflows

### 1. Create a WordPress Site

**Goal:** Provision a new WordPress installation  
**Inputs:** Domain name, server UUID, PHP version (optional)  
**Output:** Site UUID, admin URL, credentials

**Steps:**

```bash
SERVER_UUID='your-server-uuid'
DOMAIN='example.com'
PHP_VERSION='8.2'

# 1. Verify domain is available (resolve to Cloudflare NS)
nslookup $DOMAIN

# 2. Create the site
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites/wordpress" \
  -d '{
    "mode": "live",
    "domain": "'"$DOMAIN"'",
    "title": "My WordPress Site",
    "php_version": "'"$PHP_VERSION"'",
    "ssl": {
      "provider": "letsencrypt"
    },
    "cache": {
      "full_page": true,
      "object_cache": true
    }
  }' | jq '{uuid: .data.uuid, domain: .data.domain, status: .data.status, message: .message}'

# 3. Extract site UUID from response
SITE_UUID='from-step-2'

# 4. Poll site status (wait up to 10 minutes)
for i in {1..60}; do
  STATUS=$(curl -sS \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq -r '.data.status')
  
  echo "[$i/60] Status: $STATUS"
  
  if [ "$STATUS" = "provisioned" ]; then
    echo "✅ Site provisioned"
    break
  fi
  
  sleep 10
done

# 5. Retrieve WordPress credentials
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data | {domain, status, wordpress_user, wordpress_password, admin_url}'
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()

# Create and wait for provisioning
site = deployer.create_site_with_poll(
    domain="example.com",
    server_uuid="your-server-uuid",
    php_version="8.2",
    timeout=600
)

print(f"✅ Site ready: {site['domain']}")
print(f"Admin: https://{site['domain']}/wp-admin")
print(f"User: {site['wordpress_user']}")
print(f"Password: {site['wordpress_password']}")
```

---

### 2. Create Demo WordPress Site

**Goal:** Provision a temporary demo site (no custom domain)  
**Inputs:** Server UUID, optional title  
**Output:** Site UUID, temporary URL

**Steps:**

```bash
SERVER_UUID='your-server-uuid'

# 1. Create demo site
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites/wordpress" \
  -d '{
    "mode": "demo",
    "title": "Test Site",
    "php_version": "8.2"
  }' | jq '.data | {uuid, domain, status}'

# 2. Wait for provisioning
SITE_UUID='from-step-1'
sleep 30

# 3. Access via temporary URL
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data | {demo_url: .domain, status}'
```

---

### 3. Provision Staging on Code Push (CI/CD)

**Goal:** Automatically create staging sites on PR/feature branch  
**Inputs:** PR number, server UUID, feature branch name  
**Output:** Staging URL comment on PR

**Steps:**

```bash
# Triggered by: GitHub Actions / GitLab CI / Jenkins

SERVER_UUID='your-staging-server'
PR_NUMBER=$1  # From CI env var
BRANCH_NAME=$2

# 1. Create staging domain
STAGING_DOMAIN="pr-${PR_NUMBER}.staging.example.com"

# 2. Provision site
RESPONSE=$(curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites/wordpress" \
  -d '{
    "mode": "live",
    "domain": "'"$STAGING_DOMAIN"'",
    "title": "PR #'"$PR_NUMBER"' - '"$BRANCH_NAME"'",
    "php_version": "8.2"
  }')

SITE_UUID=$(echo "$RESPONSE" | jq -r '.data.uuid')

# 3. Wait for provisioning in background
(
  for i in {1..60}; do
    STATUS=$(curl -sS \
      -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
      -H "Accept: application/json" \
      "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq -r '.data.status')
    
    if [ "$STATUS" = "provisioned" ]; then
      # 4. Post comment to PR
      curl -X POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -d '{"body": "✅ Staging site ready: https://'"$STAGING_DOMAIN"'"}'
      break
    fi
    
    sleep 10
  done
) &

echo "Staging site creation started: $STAGING_DOMAIN"
```

---

### 4. Deploy with Blueprint

**Goal:** Create site from template/blueprint  
**Inputs:** Server UUID, blueprint UUID, domain (optional)  
**Output:** Site UUID, pre-configured site

**Steps:**

```bash
SERVER_UUID='your-server-uuid'
BLUEPRINT_UUID='blueprint-uuid'  # From SETUP.md
DOMAIN='example.com'

# 1. Create site from blueprint
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites/wordpress" \
  -d '{
    "mode": "live",
    "domain": "'"$DOMAIN"'",
    "blueprint_uuid": "'"$BLUEPRINT_UUID"'",
    "ssl": {
      "provider": "letsencrypt"
    }
  }' | jq '.data.uuid'

# 2. Poll until ready
SITE_UUID='from-step-1'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq '.data.status'
```

---

### 5. Deploy Containerized Application

**Goal:** Deploy Docker container to xCloud-hosted server  
**Inputs:** Server UUID, site UUID, Docker image URL  
**Output:** Running application, health verified

**Steps:**

```bash
SERVER_UUID='your-server-uuid'
SITE_UUID='your-site-uuid'
DOCKER_IMAGE='docker.io/myorg/myapp:latest'

# 1. Get SSH config for deployment
SSH_CONFIG=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh" | jq '.data')

SSH_USER=$(echo "$SSH_CONFIG" | jq -r '.site_user')
SSH_HOST=$(curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | jq -r '.data.ip_address')

# 2. Deploy Docker Compose via SSH
ssh -i ~/.ssh/xcloud_key "$SSH_USER@$SSH_HOST" << 'EOF'
  cat > /home/$USER/docker-compose.yml <<< 'EOF2'
version: '3.8'
services:
  app:
    image: $DOCKER_IMAGE
    ports:
      - "8080:3000"
    environment:
      NODE_ENV: production
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
EOF2

  docker-compose up -d
  docker-compose ps
EOF

# 3. Verify health via HTTP
sleep 5
curl -I https://$SITE_UUID.xcloud.local | head -3
```

---

### 6. Batch Deploy to Multiple Sites

**Goal:** Deploy same content/config to multiple sites  
**Inputs:** List of site UUIDs, deployment payload  
**Output:** Deployment status for each site

**Steps:**

```bash
# Define sites to deploy
SITES=("site-uuid-1" "site-uuid-2" "site-uuid-3")

# Deploy to each
for SITE_UUID in "${SITES[@]}"; do
  echo "Deploying to $SITE_UUID..."
  
  # Get SSH config
  SSH_CONFIG=$(curl -sS \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssh")
  
  # Deploy application
  # ... your deployment script ...
  
  # Verify
  curl -sS \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq '.data | {uuid, status}'
done
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()

# Deploy to multiple sites
sites = deployer.api.list_sites()
results = []

for site in sites['items']:
    result = {
        'domain': site['domain'],
        'status': 'deploying'
    }
    
    # Deploy logic here
    # ...
    
    results.append(result)

print(f"Deployed to {len(results)} sites")
```

---

## Checklist

- [ ] Server is active and has available capacity
- [ ] Domain is registered and DNS configured
- [ ] SSL provider selected (Let's Encrypt recommended)
- [ ] PHP version selected (8.1 or 8.2 recommended)
- [ ] Caching enabled for performance
- [ ] SSH access configured for deployments
- [ ] First deployment tested
- [ ] Monitoring configured
- [ ] Backup schedule set

---

## Safe Operation Rules

✅ **Always do:**
- Verify domain before site creation
- Test WordPress installation after provisioning
- Enable full-page cache for performance
- Document deployment process
- Use staging for testing before production

❌ **Never do:**
- Deploy to production without testing in staging first
- Use weak PHP versions (< 8.1)
- Disable SSL
- Deploy to servers at 100% capacity
- Make assumptions about site credentials

---

## Troubleshooting

**Site stuck in provisioning:**
- Wait 15 minutes (sometimes takes time)
- Check events: See TROUBLESHOOT.md
- Restart site from dashboard if needed

**WordPress credentials not returned:**
- Credentials shown only on creation
- Reset via WordPress dashboard if lost
- Contact support for credential recovery

**DNS not resolving:**
- Verify Cloudflare NS records are active
- Wait 5-10 minutes for propagation
- Check domain delegation at registrar
