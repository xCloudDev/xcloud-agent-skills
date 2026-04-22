#!/bin/bash
# xCloud Public API Command-Line Tool
# Usage: xcloud-cli.sh <command> [args...]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_TOKEN="${XCLOUD_API_TOKEN:-}"
API_BASE="https://app.xcloud.host/api/v1"
VERBOSE="${VERBOSE:-0}"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}ℹ${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*" >&2
}

log_debug() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${BLUE}DEBUG${NC} $*" >&2
    fi
}

check_token() {
    if [[ -z "$API_TOKEN" ]]; then
        log_error "XCLOUD_API_TOKEN not set"
        echo "Set it with: export XCLOUD_API_TOKEN='your-token-here'"
        exit 1
    fi
}

api_request() {
    local method=$1
    local path=$2
    shift 2
    local extra_args=("$@")
    
    check_token
    
    log_debug "API: $method $path"
    
    curl -sS -X "$method" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "${extra_args[@]}" \
        "$API_BASE$path"
}

# ============================================================================
# HEALTH COMMANDS
# ============================================================================

cmd_health() {
    log_info "Checking xCloud API health..."
    
    response=$(curl -sS "$API_BASE/health")
    status=$(echo "$response" | jq -r '.status // "unknown"')
    version=$(echo "$response" | jq -r '.version // "unknown"')
    
    if [[ "$status" == "ok" ]]; then
        echo -e "${GREEN}✓${NC} API is healthy"
        echo "  Status: $status"
        echo "  Version: $version"
    else
        echo -e "${RED}✗${NC} API is not healthy"
        echo "  Response: $response"
        exit 1
    fi
}

cmd_whoami() {
    log_info "Getting current user..."
    
    response=$(api_request GET "/user")
    
    name=$(echo "$response" | jq -r '.data.name')
    email=$(echo "$response" | jq -r '.data.email')
    uuid=$(echo "$response" | jq -r '.data.uuid')
    
    echo "Authenticated as:"
    echo "  Name: $name"
    echo "  Email: $email"
    echo "  UUID: $uuid"
}

# ============================================================================
# SERVER COMMANDS
# ============================================================================

cmd_server_list() {
    log_info "Listing servers..."
    
    response=$(api_request GET "/servers?per_page=100")
    
    echo "$response" | jq '.data.items // .data.data // [] | .[] | "\(.name)\t\(.ip_address)\t\(.status)\t\(.location)"' -r | \
        column -t -s $'\t' -N "NAME,IP,STATUS,LOCATION"
}

cmd_server_get() {
    local server_uuid=$1
    
    log_info "Getting server: $server_uuid"
    
    response=$(api_request GET "/servers/$server_uuid")
    
    echo "$response" | jq '.data'
}

cmd_server_reboot() {
    local server_uuid=$1
    
    log_warn "This will reboot the server!"
    read -p "Continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Aborted."
        return 0
    fi
    
    log_info "Rebooting server: $server_uuid"
    
    response=$(api_request POST "/servers/$server_uuid/reboot")
    
    echo "$response" | jq '.data'
}

# ============================================================================
# SITE COMMANDS
# ============================================================================

cmd_site_list() {
    local server_uuid=${1:-}
    
    log_info "Listing sites..."
    
    if [[ -z "$server_uuid" ]]; then
        response=$(api_request GET "/sites?per_page=100")
    else
        response=$(api_request GET "/sites?server_uuid=$server_uuid&per_page=100")
    fi
    
    echo "$response" | jq '.data.items // .data.data // [] | .[] | "\(.name)\t\(.domain)\t\(.type)\t\(.status)"' -r | \
        column -t -s $'\t' -N "NAME,DOMAIN,TYPE,STATUS"
}

cmd_site_get() {
    local site_uuid=$1
    
    log_info "Getting site: $site_uuid"
    
    response=$(api_request GET "/sites/$site_uuid")
    
    echo "$response" | jq '.data'
}

cmd_site_status() {
    local site_uuid=$1
    
    log_info "Getting site status: $site_uuid"
    
    response=$(api_request GET "/sites/$site_uuid/status")
    
    provisioned=$(echo "$response" | jq -r '.data.provisioned')
    
    if [[ "$provisioned" == "true" ]]; then
        echo -e "${GREEN}✓${NC} Site is provisioned"
    else
        echo -e "${YELLOW}⏳${NC} Site is still provisioning"
    fi
    
    echo "$response" | jq '.data'
}

cmd_site_create() {
    local domain=$1
    local server_uuid=${2:-}
    local php_version=${3:-8.2}
    
    if [[ -z "$domain" ]] || [[ -z "$server_uuid" ]]; then
        log_error "Usage: xcloud-cli.sh site create <domain> <server_uuid> [php_version]"
        exit 1
    fi
    
    log_info "Creating WordPress site..."
    echo "  Domain: $domain"
    echo "  Server: $server_uuid"
    echo "  PHP: $php_version"
    
    response=$(api_request POST "/servers/$server_uuid/sites/wordpress" \
        -d "{
            \"mode\": \"live\",
            \"domain\": \"$domain\",
            \"php_version\": \"$php_version\",
            \"ssl\": {\"provider\": \"letsencrypt\"},
            \"cache\": {\"full_page\": true, \"object_cache\": true}
        }")
    
    echo "$response" | jq '.'
}

cmd_site_backup() {
    local site_uuid=$1
    
    log_info "Triggering backup: $site_uuid"
    
    response=$(api_request POST "/sites/$site_uuid/backup")
    
    echo "$response" | jq '.data'
}

cmd_site_events() {
    local site_uuid=$1
    
    log_info "Getting site events: $site_uuid"
    
    response=$(api_request GET "/sites/$site_uuid/events")
    
    echo "$response" | jq '.data.items // .data.data // [] | .[] | "\(.type)\t\(.status)\t\(.created_at)"' -r | \
        column -t -s $'\t' -N "TYPE,STATUS,CREATED"
}

cmd_site_ssh() {
    local site_uuid=$1
    
    log_info "Getting SSH config: $site_uuid"
    
    response=$(api_request GET "/sites/$site_uuid/ssh")
    
    echo "$response" | jq '.data'
}

cmd_site_backups() {
    local site_uuid=$1
    
    log_info "Getting backup history: $site_uuid"
    
    response=$(api_request GET "/sites/$site_uuid/backups")
    
    echo "$response" | jq '.data.items // .data.data // [] | .[] | "\(.created_at)\t\(.size)"' -r | \
        column -t -s $'\t' -N "CREATED,SIZE"
}

cmd_site_purge_cache() {
    local site_uuid=$1
    
    log_info "Purging cache: $site_uuid"
    
    response=$(api_request POST "/sites/$site_uuid/cache/purge")
    
    echo "$response" | jq '.data'
}

# ============================================================================
# BLUEPRINT COMMANDS
# ============================================================================

cmd_blueprint_list() {
    log_info "Listing blueprints..."
    
    response=$(api_request GET "/blueprints?per_page=100")
    
    echo "$response" | jq '.data.items // .data.data // [] | .[] | "\(.name)\t\(.id)\t\(.is_default)"' -r | \
        column -t -s $'\t' -N "NAME,ID,DEFAULT"
}

# ============================================================================
# MONITOR COMMANDS
# ============================================================================

cmd_monitor_site() {
    local site_uuid=$1
    local interval=${2:-10}
    
    log_info "Monitoring site (updating every ${interval}s, Ctrl+C to stop)..."
    
    while true; do
        clear
        echo "Site Status Monitor - $(date)"
        echo "================================"
        
        response=$(api_request GET "/sites/$site_uuid/status")
        provisioned=$(echo "$response" | jq -r '.data.provisioned')
        
        if [[ "$provisioned" == "true" ]]; then
            echo -e "Status: ${GREEN}✓${NC} Provisioned"
        else
            echo -e "Status: ${YELLOW}⏳${NC} Provisioning"
        fi
        
        echo "$response" | jq '.data'
        
        sleep "$interval"
    done
}

cmd_monitor_servers() {
    log_info "Monitoring all servers (Ctrl+C to stop)..."
    
    while true; do
        clear
        echo "Server Health Monitor - $(date)"
        echo "===================================="
        
        response=$(api_request GET "/servers?per_page=100")
        
        echo "$response" | jq '.data.items // .data.data // [] | .[] | "\(.name)\t\(.status)\t\(.location)"' -r | \
            column -t -s $'\t' -N "NAME,STATUS,LOCATION"
        
        sleep 30
    done
}

# ============================================================================
# HELP & VERSION
# ============================================================================

cmd_help() {
    cat << EOF
${BLUE}xCloud Public API CLI${NC}

${BLUE}USAGE:${NC}
  xcloud-cli.sh <command> [args...]

${BLUE}COMMANDS:${NC}

  Health & Auth:
    health          - Check API health
    whoami          - Get current user info

  Servers:
    server list               - List all servers
    server get <uuid>         - Get server details
    server reboot <uuid>      - Reboot server (DANGEROUS)

  Sites:
    site list [server_uuid]   - List all sites (optionally filtered by server)
    site get <uuid>           - Get site details
    site status <uuid>        - Get site provisioning status
    site create <domain> <server_uuid> [php_version]  - Create WordPress site
    site backup <uuid>        - Trigger backup
    site events <uuid>        - Get site events
    site ssh <uuid>           - Get SSH/SFTP config
    site backups <uuid>       - Get backup history
    site purge-cache <uuid>   - Purge full-page cache

  Blueprints:
    blueprint list            - List available blueprints

  Monitoring:
    monitor site <uuid> [interval]  - Watch site status
    monitor servers                 - Watch all servers

  Other:
    help            - Show this help
    version         - Show version

${BLUE}EXAMPLES:${NC}
  # List all servers
  export XCLOUD_API_TOKEN="12|..."
  ./xcloud-cli.sh server list

  # Create a new WordPress site
  ./xcloud-cli.sh site create example.com 26724fa4-f96e-4a55-b454-b701be6eb366

  # Monitor site provisioning
  ./xcloud-cli.sh monitor site 9c070806-3f2b-4f04-8a2b-8d1851bcbd5b 5

${BLUE}ENVIRONMENT:${NC}
  XCLOUD_API_TOKEN  - Your xCloud API token (required)
  VERBOSE           - Set to 1 for debug output

${BLUE}API DOCS:${NC}
  https://app.xcloud.host/api/v1/docs
EOF
}

cmd_version() {
    echo "xCloud CLI v1.1.0"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local command=${1:-help}
    
    case "$command" in
        # Health
        health) cmd_health ;;
        whoami) cmd_whoami ;;
        
        # Servers
        server)
            case "${2:-}" in
                list) cmd_server_list ;;
                get) cmd_server_get "$3" ;;
                reboot) cmd_server_reboot "$3" ;;
                *) log_error "Unknown server command: $2"; exit 1 ;;
            esac
            ;;
        
        # Sites
        site)
            case "${2:-}" in
                list) cmd_site_list "${3:-}" ;;
                get) cmd_site_get "$3" ;;
                status) cmd_site_status "$3" ;;
                create) cmd_site_create "$3" "$4" "${5:-8.2}" ;;
                backup) cmd_site_backup "$3" ;;
                events) cmd_site_events "$3" ;;
                ssh) cmd_site_ssh "$3" ;;
                backups) cmd_site_backups "$3" ;;
                purge-cache) cmd_site_purge_cache "$3" ;;
                *) log_error "Unknown site command: $2"; exit 1 ;;
            esac
            ;;
        
        # Blueprints
        blueprint)
            case "${2:-}" in
                list) cmd_blueprint_list ;;
                *) log_error "Unknown blueprint command: $2"; exit 1 ;;
            esac
            ;;
        
        # Monitoring
        monitor)
            case "${2:-}" in
                site) cmd_monitor_site "$3" "${4:-10}" ;;
                servers) cmd_monitor_servers ;;
                *) log_error "Unknown monitor command: $2"; exit 1 ;;
            esac
            ;;
        
        # Help
        help|--help|-h) cmd_help ;;
        version|--version|-v) cmd_version ;;
        
        *) log_error "Unknown command: $command"; exit 1 ;;
    esac
}

main "$@"
