# RESPONSE-FORMAT: Standard Output Structure

Consistent output patterns for agents and scripts working with the xCloud API.

---

## API Response Shapes

### Success Envelope

```json
{
  "success": true,
  "message": "Operation completed successfully.",
  "data": { ... }
}
```

### Error Envelope

```json
{
  "success": false,
  "message": "Validation error.",
  "errors": {
    "domain": ["The domain field is required."]
  }
}
```

### List Response (verified live shape)

```json
{
  "success": true,
  "message": "Success",
  "data": {
    "items": [ { ... } ],
    "pagination": {
      "total": 45,
      "per_page": 15,
      "current_page": 1,
      "last_page": 3
    }
  }
}
```

**Note:** Some endpoints use `data.data` + `data.meta` instead of `data.items` + `data.pagination`. Use the shape-tolerant jq pattern:

```bash
jq '(.data.items // .data.data // []) | map({uuid, name, status})'
jq '.data.pagination // .data.meta'
```

---

## jq Extraction Patterns

### Extract list items safely

```bash
# Shape-tolerant item extraction
curl ... | jq '(.data.items // .data.data // [])'

# With field selection
curl ... | jq '(.data.items // .data.data // []) | map({uuid, name, status})'

# Count items
curl ... | jq '(.data.items // .data.data // []) | length'
```

### Extract pagination info

```bash
curl ... | jq '.data.pagination // .data.meta | {total, per_page, current_page, last_page}'
```

### Extract single field values

```bash
# For shell variable assignment
UUID=$(curl ... | jq -r '.data.uuid')
STATUS=$(curl ... | jq -r '.data.status')
DOMAIN=$(curl ... | jq -r '.data.domain')
```

### Filter by field value

```bash
# Find active servers
curl ... | jq '.data.items[] | select(.status == "active")'

# Find sites by domain
curl ... | jq --arg d "example.com" '.data.items[] | select(.domain == $d)'

# Find recently failed items
curl ... | jq '.data.items[] | select(.status == "failed") | {uuid, domain, updated_at}'
```

---

## Standard Agent Output Format

When agents report xCloud operation results, use this format:

### Single Resource Operation

```
✅ [ACTION] complete
  Resource: [TYPE] / [DOMAIN or NAME]
  UUID: [UUID]
  Status: [STATUS]
  Time: [TIMESTAMP]
```

Example:
```
✅ Backup triggered
  Resource: site / example.com
  UUID: a1b2c3d4-e5f6-...
  Status: backup_triggered
  Time: 2026-04-23T10:15:00Z
```

### Batch Operation Result

```
📦 [OPERATION] Summary
  Total: [N]
  Success: [N]
  Failed: [N]

  ✅ example1.com: [STATUS]
  ✅ example2.com: [STATUS]
  ❌ example3.com: [ERROR]
```

### Health Report

```
📊 Fleet Health Report - [DATE]
  Servers: [N] total ([N] active)
  Sites:   [N] total ([N] provisioned)
  
  Issues:
  ⚠️  [DOMAIN]: [ISSUE]
  
  Backups:
  📅 Last backup: [DATE]
  
  SSL:
  🔒 Expiring soon: [N] certificates
```

---

## Shell Output Helpers

### Color-coded status

```bash
# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

print_status() {
  local STATUS=$1
  local MSG=$2
  
  case $STATUS in
    "ok"|"provisioned"|"active"|"success")
      echo -e "${GREEN}✅${NC} $MSG"
      ;;
    "warning"|"degraded"|"expiring")
      echo -e "${YELLOW}⚠️ ${NC} $MSG"
      ;;
    "error"|"failed"|"expired")
      echo -e "${RED}❌${NC} $MSG"
      ;;
    *)
      echo "  $MSG"
      ;;
  esac
}

# Usage
print_status "provisioned" "example.com is healthy"
print_status "failed" "staging.com provisioning failed"
```

### Progress indicator

```bash
poll_with_progress() {
  local SITE_UUID=$1
  local MAX_ATTEMPTS=${2:-90}
  
  for i in $(seq 1 $MAX_ATTEMPTS); do
    STATUS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
      -H "Accept: application/json" \
      "https://app.xcloud.host/api/v1/sites/$SITE_UUID/status" | jq -r '.data.status')
    
    printf "\r  ⏳ [%3d/%d] Status: %-20s" "$i" "$MAX_ATTEMPTS" "$STATUS"
    
    case $STATUS in
      "provisioned") echo ""; return 0 ;;
      "failed") echo ""; return 1 ;;
    esac
    
    sleep 10
  done
  
  echo ""
  return 1
}
```

---

## JSON Report Template

For structured reporting:

```bash
generate_report() {
  local TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  SERVERS=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/servers?per_page=100")
  
  SITES=$(curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites?per_page=1000")
  
  jq -n \
    --arg ts "$TIMESTAMP" \
    --argjson servers "$SERVERS" \
    --argjson sites "$SITES" \
    '{
      generated_at: $ts,
      summary: {
        servers: ($servers.data.items | length),
        sites: ($sites.data.items | length),
        active_sites: ($sites.data.items | map(select(.status == "provisioned")) | length),
        failed_sites: ($sites.data.items | map(select(.status == "failed")) | length)
      },
      issues: ($sites.data.items | map(select(.status != "provisioned")) | map({
        uuid, domain, status, updated_at
      }))
    }'
}

generate_report | tee fleet-report-$(date +%Y%m%d).json
```

---

## Error Handling Format

Standardize error messages for logging/alerting:

```bash
handle_api_error() {
  local HTTP_CODE=$1
  local BODY=$2
  local ENDPOINT=$3
  
  case $HTTP_CODE in
    401) echo "❌ AUTH_FAILED: Check XCLOUD_API_TOKEN" ;;
    403) echo "❌ FORBIDDEN: Token lacks required scope for $ENDPOINT" ;;
    404) echo "❌ NOT_FOUND: Resource not found at $ENDPOINT" ;;
    422) echo "❌ VALIDATION: $(echo $BODY | jq -r '.errors // .message')" ;;
    429) echo "⚠️  RATE_LIMITED: Wait before retrying" ;;
    5*) echo "❌ SERVER_ERROR: xCloud API error ($HTTP_CODE) at $ENDPOINT" ;;
    *) echo "  HTTP $HTTP_CODE at $ENDPOINT" ;;
  esac
}
```

---

## Table Formatting

For terminal-friendly tabular output:

```bash
# Print sites as table
print_sites_table() {
  printf "%-40s %-15s %-8s %-8s\n" "DOMAIN" "STATUS" "PHP" "SSL"
  printf "%s\n" "$(printf '=%.0s' {1..75})"
  
  curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
    -H "Accept: application/json" \
    "https://app.xcloud.host/api/v1/sites?per_page=100" | \
    jq -r '.data.items[] | "\(.domain) \(.status) \(.php_version // "N/A") \(.ssl_status // "N/A")"' | \
    while read DOMAIN STATUS PHP SSL; do
      printf "%-40s %-15s %-8s %-8s\n" "$DOMAIN" "$STATUS" "$PHP" "$SSL"
    done
}

print_sites_table
```
