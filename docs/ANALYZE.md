# ANALYZE: Understand & Optimize

**Intent:** Analyze utilization, identify cost optimization opportunities, plan capacity, and find security gaps.

**When to use this:**
- Monthly billing review
- Capacity planning
- Performance analysis
- Cost optimization
- Security audits
- Efficiency reporting

---

## Workflows

### 1. Server Utilization Analysis

**Goal:** Understand how much server capacity is being used  
**Inputs:** Server UUID (optional)  
**Output:** Utilization report with trends

**Steps:**

```bash
# 1. Get all servers and count sites per server
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | \
  jq '.data.items[] | {name, uuid, created_at} as $server | 
    (curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites?server_uuid=\($server.uuid)&per_page=100" | 
    jq .data.items | length) as $sites | 
    {server: $server.name, sites: $sites, uuid: $server.uuid}'

# 2. Check server monitoring data
SERVER_UUID='your-server-uuid'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers/$SERVER_UUID/monitoring" | \
  jq '.data | {cpu_usage: .cpu, memory_usage: .memory, disk_usage: .disk, network_in, network_out}'

# 3. Analyze - sites per server comparison
for SERVER in $(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers?per_page=100" | jq -r '.data.items[].uuid'); do
  COUNT=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?server_uuid=$SERVER" | jq '.data.items | length')
  echo "$SERVER: $COUNT sites"
done
```

---

### 2. Cost Analysis

**Goal:** Identify cost drivers and optimization opportunities  
**Inputs:** Account data  
**Output:** Cost breakdown report

**Steps:**

```bash
# 1. Count total resources
echo "=== Infrastructure Inventory ==="
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/servers?per_page=100" | \
  jq '.data | {total_servers: (.items | length), pagination}'

curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=100" | \
  jq '.data | {total_sites: (.items | length), pagination}'

# 2. Calculate storage usage (sum of backups)
echo "=== Storage Analysis ==="
for SITE_UUID in $(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=100" | jq -r '.data.items[].uuid'); do
  curl -sS \
    -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites/$SITE_UUID/backups" | \
    jq '.data.items[0:1] | map(.size) | add // 0'
done | awk '{sum+=$1} END {print "Total backup storage:", sum/(1024^3), "GB"}'

# 3. Cost estimate
echo "=== Estimated Monthly Cost ==="
SERVERS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers?per_page=100" | jq '.data.items | length')
SITES=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=100" | jq '.data.items | length')

echo "Servers: $SERVERS x \$XX/month = \$(($SERVERS * XX))"
echo "Sites: $SITES x \$XX/month = \$(($SITES * XX))"
```

---

### 3. Capacity Planning

**Goal:** Predict resource needs for growth  
**Inputs:** Historical data, growth rate  
**Output:** Recommendations for scaling

**Steps:**

```bash
# 1. Current capacity snapshot
CURRENT_SITES=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=100" | jq '.data | {total: (.items | length), per_page: .pagination.per_page}')

CURRENT_SERVERS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers?per_page=100" | jq '.data.items | length')

echo "Current: $CURRENT_SITES sites on $CURRENT_SERVERS servers"

# 2. Per-server capacity check
echo "Sites per server:"
for SERVER_UUID in $(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers?per_page=100" | jq -r '.data.items[].uuid'); do
  COUNT=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?server_uuid=$SERVER_UUID" | jq '.data.items | length')
  USAGE=$((COUNT * 100 / 50))  # Assuming 50 sites per server max
  echo "  Server: $COUNT sites ($USAGE% capacity)"
done

# 3. Recommendation
echo ""
echo "Recommendation:"
MAX_UTILIZATION=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/servers?per_page=100" | jq '[.data.items[] | (. as $server | (curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?server_uuid=\($server.uuid)" | jq ".data.items | length") / 50 * 100)] | max')

if (( $(echo "$MAX_UTILIZATION > 80" | bc -l) )); then
  echo "  ⚠️  Add new server (at least one server > 80% capacity)"
else
  echo "  ✅ Current capacity sufficient"
fi
```

---

### 4. Performance Analysis

**Goal:** Identify slow or problematic sites  
**Inputs:** None  
**Output:** Performance report

**Steps:**

```bash
# 1. Check site response times
echo "=== Site Performance Analysis ==="
for DOMAIN in $(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=100" | jq -r '.data.items[].domain'); do
  RESPONSE_TIME=$(curl -s -w "%{time_total}\n" -o /dev/null "https://$DOMAIN" | xargs printf "%.2f" 2>/dev/null || echo "N/A")
  echo "$DOMAIN: ${RESPONSE_TIME}s"
done | sort -k2 -rn | head -10

# 2. Cache hit rate analysis
SITE_UUID='your-site-uuid'
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites/$SITE_UUID/monitoring" | \
  jq '.data | {cache_hit_rate, page_load_time, request_count}'

# 3. PHP version impact analysis
echo "=== Sites by PHP Version ==="
curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq 'group_by(.php_version) | map({version: .[0].php_version, count: length}) | sort_by(.version) | reverse'
```

---

### 5. Security Audit

**Goal:** Identify security gaps and misconfigurations  
**Inputs:** None  
**Output:** Security report with recommendations

**Steps:**

```bash
echo "=== Security Audit ==="

# 1. SSL Certificate Status
echo "📋 SSL Status:"
EXPIRED=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=1000" | jq '[.data.items[] | select(.ssl_status == "expired")] | length')
EXPIRING=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=1000" | jq '.data.items[] | select(.ssl_expires_at < (now + 2592000 | todate))' | jq -s 'length')

echo "  - Expired: $EXPIRED"
echo "  - Expiring in 30 days: $EXPIRING"

if (( EXPIRED > 0 )); then
  echo "  ⚠️  ACTION: Renew expired certificates"
fi

# 2. SSH Authentication Methods
echo "📋 SSH Authentication:"
PASSWORD_AUTH=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=1000" | jq '[.data.items[] | select(.ssh_authentication_mode == "password")] | length')
PUBKEY_AUTH=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=1000" | jq '[.data.items[] | select(.ssh_authentication_mode == "public_key")] | length')

echo "  - Public Key: $PUBKEY_AUTH (✅ secure)"
echo "  - Password: $PASSWORD_AUTH (⚠️  less secure)"

# 3. Backup Status
echo "📋 Backup Coverage:"
NO_BACKUPS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites?per_page=1000" | jq -r '.data.items[].uuid' | while read UUID; do
  BACKUP_COUNT=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" -H "Accept: application/json" "https://app.xcloud.host/api/v1/sites/$UUID/backups" | jq '.data.items | length')
  if [ "$BACKUP_COUNT" = "0" ]; then
    echo "1"
  fi
done | wc -l)

echo "  - Sites without backups: $NO_BACKUPS"

if (( NO_BACKUPS > 0 )); then
  echo "  ⚠️  ACTION: Enable automatic backups"
fi
```

---

### 6. Usage Trends Over Time

**Goal:** Track growth and usage patterns  
**Inputs:** Historical dates  
**Output:** Trend analysis

**Steps:**

```bash
# Example: Count newly created sites this month
MONTH_START=$(date -d "$(date +%Y-%m-01)" +%s)
MONTH_END=$(date +%s)

curl -sS \
  -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  -H "Accept: application/json" \
  "https://app.xcloud.host/api/v1/sites?per_page=1000" | \
  jq ".data.items[] | select(.created_at | fromdateiso8601 > $MONTH_START and fromdateiso8601 < $MONTH_END)" | \
  jq -s "length" | \
  xargs echo "New sites this month:"
```

---

## Python SDK Analysis

```python
from xcloud_sdk import XCloudAPI
from collections import Counter

api = XCloudAPI()

# Get all sites
sites = api.list_sites(per_page=1000)

# Analyze PHP versions
php_versions = Counter([s['php_version'] for s in sites['items']])
print("PHP Versions:")
for version, count in php_versions.most_common():
    print(f"  {version}: {count} sites")

# Calculate average sites per server
server_count = len(api.list_servers()['items'])
site_count = len(sites['items'])
avg_per_server = site_count / server_count

print(f"\nAverage sites per server: {avg_per_server:.1f}")

# Find underutilized servers
for server in api.list_servers()['items']:
    server_sites = api.list_sites(server_uuid=server['uuid'])
    utilization = len(server_sites['items']) / 50 * 100  # Assuming 50 max
    if utilization < 30:
        print(f"⚠️  Underutilized: {server['name']} ({utilization:.0f}%)")
```

---

## Safe Operation Rules

✅ **Always do:**
- Review analysis monthly
- Act on security findings immediately
- Plan capacity 1-2 months ahead
- Document optimization decisions

❌ **Never do:**
- Ignore expired SSL certificates
- Assume backup existence without verification
- Make capacity decisions without monitoring data
- Ignore security audit findings

---

## Checklist

- [ ] SSL certificates checked monthly
- [ ] Capacity trending analyzed
- [ ] Cost analysis reviewed
- [ ] Performance baselines established
- [ ] Security audit completed
- [ ] Unused resources identified
- [ ] Growth projections calculated
