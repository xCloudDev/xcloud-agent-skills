#!/bin/bash
# xCloud Public API Wrapper
# Centralized auth handling and helper functions for xCloud API calls
# Usage: source this file or call functions directly
# Requires: XCLOUD_API_TOKEN environment variable or ~/.xcloud/api-token file

set -e

# Configuration
XCLOUD_API_URL="${XCLOUD_API_URL:-https://app.xcloud.host/api/v1}"
XCLOUD_TOKEN_FILE="${XCLOUD_TOKEN_FILE:-$HOME/.xcloud/api-token}"
XCLOUD_TIMEOUT="${XCLOUD_TIMEOUT:-30}"

# Get API token from env or file
_get_token() {
    if [ -n "$XCLOUD_API_TOKEN" ]; then
        echo "$XCLOUD_API_TOKEN"
    elif [ -f "$XCLOUD_TOKEN_FILE" ]; then
        cat "$XCLOUD_TOKEN_FILE"
    else
        echo "❌ Error: XCLOUD_API_TOKEN not set and $XCLOUD_TOKEN_FILE not found" >&2
        return 1
    fi
}

# Make API call with consistent auth and error handling
# Usage: _api_call GET|POST|PUT|DELETE /endpoint [payload]
_api_call() {
    local method=$1
    local endpoint=$2
    local payload=$3
    
    local token
    token=$(_get_token) || return 1
    
    local url="${XCLOUD_API_URL}${endpoint}"
    
    if [ -n "$payload" ]; then
        curl -sS -X "$method" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            --max-time "$XCLOUD_TIMEOUT" \
            -d "$payload" \
            "$url"
    else
        curl -sS -X "$method" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            --max-time "$XCLOUD_TIMEOUT" \
            "$url"
    fi
}

# ============================================================================
# SERVER OPERATIONS
# ============================================================================

# List all servers
xcloud_servers() {
    local per_page="${1:-100}"
    _api_call GET "/servers?per_page=$per_page"
}

# Get server details
xcloud_server() {
    local server_uuid=$1
    _api_call GET "/servers/$server_uuid"
}

# Reboot server
xcloud_reboot_server() {
    local server_uuid=$1
    _api_call POST "/servers/$server_uuid/reboot" "{}"
}

# ============================================================================
# SITE OPERATIONS
# ============================================================================

# List sites on server
xcloud_sites() {
    local server_uuid=$1
    local per_page="${2:-100}"
    _api_call GET "/servers/$server_uuid/sites?per_page=$per_page"
}

# Get site details
xcloud_site() {
    local site_uuid=$1
    _api_call GET "/sites/$site_uuid"
}

# Create WordPress site
xcloud_create_site() {
    local server_uuid=$1
    local domain=$2
    local php_version="${3:-8.2}"
    
    local payload=$(cat <<EOF
{
    "domain": "$domain",
    "php_version": "$php_version"
}
EOF
)
    
    _api_call POST "/servers/$server_uuid/sites/wordpress" "$payload"
}

# Delete site
xcloud_delete_site() {
    local site_uuid=$1
    _api_call DELETE "/sites/$site_uuid" "{}"
}

# ============================================================================
# BACKUP OPERATIONS
# ============================================================================

# List backups for site
xcloud_backups() {
    local site_uuid=$1
    local per_page="${2:-100}"
    _api_call GET "/sites/$site_uuid/backups?per_page=$per_page"
}

# Trigger backup
xcloud_create_backup() {
    local site_uuid=$1
    _api_call POST "/sites/$site_uuid/backup" "{}"
}

# ============================================================================
# CACHE OPERATIONS
# ============================================================================

# Purge site cache
xcloud_purge_cache() {
    local site_uuid=$1
    _api_call POST "/sites/$site_uuid/cache/purge" "{}"
}

# ============================================================================
# SSH/SFTP OPERATIONS
# ============================================================================

# Get SSH configuration
xcloud_ssh_config() {
    local site_uuid=$1
    _api_call GET "/sites/$site_uuid/ssh-config"
}

# Update SSH configuration
xcloud_update_ssh() {
    local site_uuid=$1
    local auth_mode=$2
    local ssh_key=${3:-}
    local password=${4:-}
    
    local payload=$(cat <<EOF
{
    "authentication_mode": "$auth_mode"
EOF
)
    
    if [ "$auth_mode" = "public_key" ] && [ -n "$ssh_key" ]; then
        payload=$(cat <<EOF
{
    "authentication_mode": "public_key",
    "ssh_keys": ["$ssh_key"]
}
EOF
)
    elif [ "$auth_mode" = "password" ] && [ -n "$password" ]; then
        payload=$(cat <<EOF
{
    "authentication_mode": "password",
    "password": "$password"
}
EOF
)
    fi
    payload="${payload}"$'\n'"}"
    
    _api_call PUT "/sites/$site_uuid/ssh-config" "$payload"
}

# ============================================================================
# DOMAIN OPERATIONS
# ============================================================================

# Get domain configuration
xcloud_domains() {
    local site_uuid=$1
    _api_call GET "/sites/$site_uuid/domains"
}

# Add domain
xcloud_add_domain() {
    local site_uuid=$1
    local domain=$2
    local primary="${3:-false}"
    
    local payload=$(cat <<EOF
{
    "domain": "$domain",
    "primary": $primary
}
EOF
)
    
    _api_call POST "/sites/$site_uuid/domains" "$payload"
}

# ============================================================================
# ENVIRONMENT & VARIABLES
# ============================================================================

# Get environment variables
xcloud_variables() {
    local site_uuid=$1
    _api_call GET "/sites/$site_uuid/variables"
}

# Set environment variable
xcloud_set_variable() {
    local site_uuid=$1
    local key=$2
    local value=$3
    
    local payload=$(cat <<EOF
{
    "$key": "$value"
}
EOF
)
    
    _api_call PUT "/sites/$site_uuid/variables" "$payload"
}

# ============================================================================
# SUDO USER OPERATIONS
# ============================================================================

# List sudo users
xcloud_sudo_users() {
    local site_uuid=$1
    _api_call GET "/sites/$site_uuid/sudo-users"
}

# Add sudo user
xcloud_add_sudo_user() {
    local site_uuid=$1
    local username=$2
    local password=${3:-}
    
    local payload=$(cat <<EOF
{
    "username": "$username"
EOF
)
    
    if [ -n "$password" ]; then
        payload=$(cat <<EOF
{
    "username": "$username",
    "password": "$password"
}
EOF
)
    fi
    payload="${payload}"$'\n'"}"
    
    _api_call POST "/sites/$site_uuid/sudo-users" "$payload"
}

# ============================================================================
# HEALTH & STATUS
# ============================================================================

# Get user info (validates authentication)
xcloud_whoami() {
    _api_call GET "/user"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Wait for site to be provisioned
xcloud_wait_provisioned() {
    local site_uuid=$1
    local timeout="${2:-600}"
    local interval="${3:-15}"
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local status
        status=$(xcloud_site "$site_uuid" | jq -r '.provisioned // false')
        
        if [ "$status" = "true" ]; then
            echo "✅ Site $site_uuid provisioned"
            return 0
        fi
        
        echo "⏳ Waiting for provisioning... ($elapsed/$timeout seconds)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    echo "❌ Timeout waiting for site provisioning"
    return 1
}

# Parse xCloud dashboard URL and extract IDs
xcloud_parse_url() {
    local url=$1
    
    # Extract project ID
    local project_id=$(echo "$url" | grep -oP 'project/\K[^/]+' || true)
    # Extract service ID
    local service_id=$(echo "$url" | grep -oP 'service/\K[^/?]+' || true)
    # Extract environment ID from query param
    local environment_id=$(echo "$url" | grep -oP 'environmentId=\K[^&]+' || true)
    
    echo "project=$project_id"
    echo "service=$service_id"
    echo "environment=$environment_id"
}

# Pretty print JSON response
xcloud_pretty() {
    jq '.' 2>/dev/null || cat
}

# ============================================================================
# VALIDATION
# ============================================================================

# Validate token format
xcloud_validate_token() {
    local token
    token=$(_get_token) || return 1
    
    # Token should have format: ID|SECRET
    if [[ $token =~ ^[0-9]+\|[a-zA-Z0-9]+$ ]]; then
        echo "✅ Token format valid"
        return 0
    else
        echo "⚠️  Token format may be invalid (expected: ID|SECRET)"
        return 1
    fi
}

# Test API connection
xcloud_test_connection() {
    echo "Testing xCloud API connection..."
    
    # Check token
    if ! xcloud_validate_token; then
        return 1
    fi
    
    # Test authentication
    local user
    user=$(xcloud_whoami | jq -r '.name // empty')
    if [ -n "$user" ]; then
        echo "✅ Authenticated as: $user"
        return 0
    else
        echo "❌ Authentication failed"
        return 1
    fi
}

# Export functions for use in other scripts
export -f _get_token
export -f _api_call
export -f xcloud_servers
export -f xcloud_server
export -f xcloud_reboot_server
export -f xcloud_sites
export -f xcloud_site
export -f xcloud_create_site
export -f xcloud_delete_site
export -f xcloud_backups
export -f xcloud_create_backup
export -f xcloud_purge_cache
export -f xcloud_ssh_config
export -f xcloud_update_ssh
export -f xcloud_domains
export -f xcloud_add_domain
export -f xcloud_variables
export -f xcloud_set_variable
export -f xcloud_sudo_users
export -f xcloud_add_sudo_user
export -f xcloud_whoami
export -f xcloud_wait_provisioned
export -f xcloud_parse_url
export -f xcloud_pretty
export -f xcloud_validate_token
export -f xcloud_test_connection

# If sourced (not executed), don't run anything
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    return 0
fi

# If executed directly, show help
cat <<EOF
xCloud API Wrapper v1.2.0

Usage: source xcloud-api.sh [command] [args...]

Commands:
  whoami              Show authenticated user
  test                Test API connection
  servers             List all servers
  server UUID         Get server details
  sites UUID          List sites on server
  site UUID           Get site details
  create-site UUID DOMAIN [PHP_VERSION]
                      Create WordPress site
  backups UUID        List backups for site
  backup UUID         Trigger backup
  purge-cache UUID    Purge site cache
  
Examples:
  source xcloud-api.sh
  xcloud_servers | jq
  xcloud_create_site "server-uuid" "example.com" "8.2"
  xcloud_wait_provisioned "site-uuid"

For full documentation, see:
  - docs/SETUP.md
  - docs/OPERATE.md
  - https://app.xcloud.host/api/v1/docs
EOF
