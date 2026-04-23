# SETUP: Provision Infrastructure

**Intent:** Create servers, configure cloud platforms, and prepare infrastructure capacity for applications.

**When to use this:** 
- Initial server provisioning
- Cloud platform setup (Cloudflare, DNS)
- Capacity planning
- Multi-server fleet initialization

---

## Workflows

### 1. Provision a New Server

**Goal:** Add a server to your fleet  
**Inputs:** Server name, location preference (optional)  
**Output:** Server UUID, IP address, status

**Steps:**

```bash
# 1. Check available servers (read-only)
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | jq '.data.items[] | {uuid, name, ip_address, status}'

# 2. If not available in API, provision via xCloud dashboard at:
# https://app.xcloud.host/servers/create

# 3. Verify new server appears in API (wait 30 seconds)
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers" | jq '.data.items[-1]'

# 4. Note the server UUID for future use
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudAPI

api = XCloudAPI()
servers = api.list_servers()
new_server = servers['items'][-1]  # Most recent

print(f"Server: {new_server['name']}")
print(f"UUID: {new_server['uuid']}")
print(f"IP: {new_server['ip_address']}")
```

---

### 2. Integrate with Cloudflare

**Goal:** Link Cloudflare account to xCloud  
**Inputs:** Cloudflare API token with zone:dns_records:edit scope  
**Output:** Cloudflare integration status

**Steps:**

```bash
# 1. Get Cloudflare token from:
# https://dash.cloudflare.com/profile/api-tokens

# 2. Check xCloud Cloudflare integrations
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/integrations/cloudflare" | jq

# 3. If not integrated, add Cloudflare via xCloud dashboard:
# https://app.xcloud.host/settings/integrations/cloudflare

# 4. Verify integration is active
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/integrations/cloudflare" | jq '.data | {email, status, domains: (.zones | length)}'
```

---

### 3. Prepare Server for WordPress

**Goal:** Verify server is ready for site deployment  
**Inputs:** Server UUID  
**Output:** Readiness report (PHP versions, storage, capacity)

**Steps:**

```bash
SERVER_UUID='your-server-uuid'

# 1. Get server details
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | jq '.data | {name, ip_address, status, os}'

# 2. Check available PHP versions
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/php-versions" | jq '.data.items[] | {version, status}'

# 3. Check existing sites and capacity
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sites" | jq '.data | {items: (.items | length), available_capacity: .pagination.total}'

# 4. Check monitoring and health
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/monitoring" | jq '.data | {cpu, memory, disk, network}'
```

**Python SDK approach:**

```python
from xcloud_sdk import XCloudAPI

api = XCloudAPI()
server_uuid = "your-server-uuid"

# Comprehensive readiness check
server = api.get_server(server_uuid)
php_versions = api.get_server_php_versions(server_uuid)
sites = api.list_sites(server_uuid=server_uuid)
monitoring = api.get_server_monitoring(server_uuid)

readiness_report = {
    "server": server['name'],
    "status": server['status'],
    "php_versions": [v['version'] for v in php_versions['items']],
    "existing_sites": len(sites['items']),
    "capacity_available": sites['pagination']['total'] > len(sites['items']),
    "health": monitoring
}

print(f"✅ Server ready for deployment" if server['status'] == 'active' else f"⚠️  Server not active")
```

---

### 4. Configure Sudo Users

**Goal:** Create deployment/management accounts on server  
**Inputs:** Server UUID, username, password, SSH keys (optional)  
**Output:** Sudo user UUID, access credentials

**Steps:**

```bash
SERVER_UUID='your-server-uuid'

# 1. Generate a strong password
PASSWORD=$(openssl rand -base64 32)

# 2. Create sudo user
curl -sS -X POST \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sudo-users" \
  -d '{
    "username": "deploy",
    "password": "'"$PASSWORD"'",
    "ssh_public_keys": ["ssh-ed25519 AAAA... your-public-key"],
    "is_temporary": false
  }' | jq

# 3. Verify sudo user was created
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/sudo-users" | jq '.data.items[] | {uuid, username, is_temporary}'

# 4. Store credentials securely (not in code)
echo "Deploy user: deploy"
echo "Password: $PASSWORD"
```

**Security note:** Never commit passwords to version control. Store in secure credential management system.

---

### 5. Load Blueprints

**Goal:** Review available server templates/blueprints  
**Inputs:** None  
**Output:** List of blueprints with descriptions

**Steps:**

```bash
# 1. List all blueprints
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/blueprints?per_page=100" | jq '.data.items[] | {uuid, name, description, is_default, is_public}'

# 2. Get details of specific blueprint
BLUEPRINT_UUID='blueprint-uuid'
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/blueprints/$BLUEPRINT_UUID" | jq

# 3. Use blueprint when creating WordPress sites (see DEPLOY.md)
```

---

## Checklist

Use this before deploying applications:

- [ ] Server created and active (`status: active`)
- [ ] Server IP address noted
- [ ] Cloudflare integrated (if using DNS delegation)
- [ ] PHP versions available (8.1+)
- [ ] Storage capacity verified (minimum 50GB free)
- [ ] Monitoring enabled
- [ ] At least one sudo user created for deployments
- [ ] SSH keys configured for automation
- [ ] Backup location configured

---

## Safe Operation Rules

✅ **Always do:**
- Verify server status before provisioning applications
- Create specific sudo users (never use root directly)
- Test SSH access after user creation
- Document server purpose and capacity

❌ **Never do:**
- Reboot servers without backup verification
- Use default/empty passwords
- Create users with `is_temporary: true` for long-lived services
- Skip Cloudflare integration if managing multiple domains

---

## Troubleshooting

**Server not appearing in API:**
- Wait 30-60 seconds after creation in dashboard
- Check server status in xCloud dashboard
- Verify API token has `read:servers` scope

**Sudo user creation fails:**
- Ensure password meets strength requirements (8+ chars, mixed case, numbers)
- Check SSH key format (must be Ed25519 or RSA)
- Verify server is in `active` status

**PHP versions not available:**
- Server may still be initializing (wait 5 minutes)
- Contact xCloud support if persists
