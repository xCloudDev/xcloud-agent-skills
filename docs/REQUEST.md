# REQUEST: Query the API

**Intent:** Fetch data, build reports, list resources, verify state, and export information.

**When to use this:**
- Building dashboards/reports
- Verifying resource state
- Exporting data
- Searching for specific resources
- Checking resource relationships
- Auditing infrastructure

---

## Workflows

### 1. List All Servers

**Goal:** Get inventory of all servers  
**Inputs:** Optional filters  
**Output:** Servers with metadata

**Steps:**

```bash
# 1. List all servers (paginated, 100 per page)
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | \
  jq '.data.items[] | {uuid, name, status, ip_address, os, created_at}'

# 2. Filter by status
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?status=active&per_page=100" | \
  jq '.data.items | length'

# 3. Search by name
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?search=production" | \
  jq '.data.items[] | {name, ip_address}'
```

---

### 2. List All Sites

**Goal:** Inventory of all deployed sites  
**Inputs:** Optional filters, search  
**Output:** Sites with status and metadata

**Steps:**

```bash
# 1. List all sites
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=100" | \
  jq '.data.items[] | {uuid, domain, status, ssl_status, php_version, server_uuid}'

# 2. Filter by type
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?type=wordpress" | \
  jq '.data.items | length'

# 3. Filter by server
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?server_uuid=your-server-uuid" | \
  jq '.data.items[] | {domain, status}'

# 4. Search by domain/title
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?search=example.com" | \
  jq '.data.items[] | {domain, uuid}'

# 5. Filter by status
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?status=provisioned" | \
  jq '.data | {total: (.items | length), pagination}'
```

---

### 3. Get Single Resource Details

**Goal:** Fetch complete info for one resource  
**Inputs:** Server UUID or Site UUID  
**Output:** All available fields

**Steps:**

```bash
# Server details
SERVER_UUID='your-server-uuid'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID" | jq '.data'

# Site details
SITE_UUID='your-site-uuid'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID" | jq '.data'

# User account info
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/user" | jq '.data'
```

---

### 4. Export Site Report (CSV)

**Goal:** Export sites list for reporting  
**Inputs:** Filters (optional)  
**Output:** CSV formatted data

**Steps:**

```bash
# 1. Fetch all sites
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq -r '["Domain", "Status", "PHP", "SSL", "Created", "Server"] | @csv' > sites.csv

# 2. Append sites data
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq -r '.data.items[] | [.domain, .status, .php_version, .ssl_status, .created_at, .server_uuid] | @csv' >> sites.csv

# 3. View export
cat sites.csv
```

---

### 5. Find Site by Domain

**Goal:** Look up site UUID by domain  
**Inputs:** Domain name  
**Output:** Site UUID and details

**Steps:**

```bash
DOMAIN='example.com'

curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?search=$DOMAIN" | \
  jq '.data.items[] | select(.domain == "'$DOMAIN'") | {uuid, domain, status, server_uuid}'
```

---

### 6. List Site Backups

**Goal:** Inventory of backups for recovery  
**Inputs:** Site UUID  
**Output:** Backup list with dates and sizes

**Steps:**

```bash
SITE_UUID='your-site-uuid'

curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | \
  jq '.data.items[] | {id, created_at, size, status, note}'

# With sizes in human-readable format
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | \
  jq '.data.items[] | {created_at, size: (.size | if . > 1000000000 then "\(. / 1000000000 | round | tostring) GB" elif . > 1000000 then "\(. / 1000000 | round | tostring) MB" else "\(. / 1000 | round | tostring) KB" end), status}'
```

---

### 7. List Site Events (Activity Log)

**Goal:** View recent activities on a site  
**Inputs:** Site UUID, optional filters  
**Output:** Chronological event list

**Steps:**

```bash
SITE_UUID='your-site-uuid'

# Last 20 events
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=20" | \
  jq '.data.items[] | {created_at, event_type, status, message}'

# Only errors
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=100" | \
  jq '.data.items[] | select(.status == "failed") | {created_at, event_type, message}'

# Only deployment events
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/events?per_page=100" | \
  jq '.data.items[] | select(.event_type == "deployment") | {created_at, status, message}'
```

---

### 8. List Server Tasks

**Goal:** Track async operations on server  
**Inputs:** Server UUID  
**Output:** Task list with status

**Steps:**

```bash
SERVER_UUID='your-server-uuid'

curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/tasks" | \
  jq '.data.items[] | {id, task_type, status, created_at, completed_at}'
```

---

### 9. Check SSL Status

**Goal:** Inventory of SSL certificates  
**Inputs:** Optional site UUID (if omitted, checks all)  
**Output:** Certificate status, expiration dates

**Steps:**

```bash
# All sites' SSL status
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq '.data.items[] | {domain, ssl_status, ssl_expires_at}'

# Single site
SITE_UUID='your-site-uuid'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/ssl" | \
  jq '.data | {provider, status, expires_at, issuer, valid_from}'

# Find expiring certificates (< 30 days)
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq '.data.items[] | select(.ssl_expires_at < (now + 2592000 | todate)) | {domain, ssl_expires_at}'
```

---

### 10. API Health & Status

**Goal:** Verify API is functional  
**Inputs:** None  
**Output:** API health status

**Steps:**

```bash
# Check API health (no auth required)
curl -sS https://app.xcloud.host/api/v1/health | jq

# Verify authentication
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  https://app.xcloud.host/api/v1/user | jq '.data | {email, scopes}'
```

---

## Data Export Examples

### Export All Sites to JSON

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq '.data.items' > all-sites.json
```

### Export All Servers to JSON

```bash
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=1000" | \
  jq '.data.items' > all-servers.json
```

### Export Monitoring Data

```bash
SERVER_UUID='your-server-uuid'

curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/monitoring" | \
  jq '.data' > server-monitoring.json
```

---

## Python SDK Helpers

```python
from xcloud_sdk import XCloudAPI

api = XCloudAPI()

# Get all sites
sites = api.list_sites(per_page=1000)
print(f"Total sites: {sites['pagination']['total']}")

# Get single resource
site = api.get_site('your-site-uuid')
print(f"Domain: {site['domain']}")

# Export as JSON
import json
with open('sites.json', 'w') as f:
    json.dump(sites, f, indent=2)
```

---

## Safe Operation Rules

✅ **Always do:**
- Use filters to reduce data transfer
- Handle pagination correctly (check `pagination.last_page`)
- Cache results locally when making reports

❌ **Never do:**
- Fetch unlimited resources without pagination
- Store credentials in exported files
- Share raw API response with sensitive data
