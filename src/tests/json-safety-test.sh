#!/usr/bin/env bash
# json-safety-test.sh — offline tests that src/xcloud-api.sh builds JSON safely.
#
# Covers the acceptance criteria of "Replace unsafe shell JSON interpolation":
# hostile input (quotes, control characters, injection attempts) must neither
# corrupt the JSON nor inject extra fields. No network access is needed —
# _api_call is stubbed to print the payload it would send.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
ok(){ echo "PASS $1"; PASS=$((PASS+1)); }
bad(){ echo "FAIL $1" >&2; FAIL=$((FAIL+1)); }

# Source the library with a stubbed transport: _api_call prints the payload.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../xcloud-api.sh" >/dev/null 2>&1 || true
_api_call(){ printf '%s' "${3:-}"; }

HOSTILE='ha"ha","admin":true,"x":"'      # tries to break out and inject a field
CTRL=$'line1\nline2\ttabbed'             # control characters

# 1. create_site: hostile domain must stay a single string value
p=$(xcloud_create_site "srv-uuid" "${HOSTILE}" "8.3")
echo "${p}" | jq -e . >/dev/null 2>&1 || bad "create-site: payload not valid JSON"
[[ $(echo "${p}" | jq -r '.domain') == "${HOSTILE}" ]] \
  && ok "create-site: hostile domain intact" || bad "create-site: domain mangled"
[[ $(echo "${p}" | jq 'has("admin")') == "false" ]] \
  && ok "create-site: no injected field" || bad "create-site: field injected!"

# 2. update_ssh (password mode): control chars + quotes survive, no injection
p=$(xcloud_update_ssh "site-uuid" "password" "" "${HOSTILE}${CTRL}")
echo "${p}" | jq -e . >/dev/null 2>&1 || bad "ssh-password: payload not valid JSON"
[[ $(echo "${p}" | jq -r '.password') == "${HOSTILE}${CTRL}" ]] \
  && ok "ssh-password: hostile secret intact" || bad "ssh-password: secret mangled"
[[ $(echo "${p}" | jq 'has("admin")') == "false" ]] \
  && ok "ssh-password: no injected field" || bad "ssh-password: field injected!"

# 3. update_ssh (public_key mode): key with quotes/newlines
p=$(xcloud_update_ssh "site-uuid" "public_key" "ssh-ed25519 AAAA\"quote${CTRL}" "")
echo "${p}" | jq -e '.ssh_public_keys | length == 1' >/dev/null 2>&1 \
  && ok "ssh-key: array shape kept" || bad "ssh-key: array corrupted"

# 4. add_domain: boolean stays boolean, hostile domain contained
p=$(xcloud_add_domain "site-uuid" "${HOSTILE}" "true")
[[ $(echo "${p}" | jq -r '.primary') == "true" ]] \
  && ok "add-domain: primary boolean" || bad "add-domain: primary wrong"
[[ $(echo "${p}" | jq 'has("admin")') == "false" ]] \
  && ok "add-domain: no injected field" || bad "add-domain: field injected!"

# 5. add_sudo_user: password with quotes
p=$(xcloud_add_sudo_user "srv-uuid" "deploy" 'p"w,\n$(rm -rf /)')
echo "${p}" | jq -e . >/dev/null 2>&1 \
  && [[ $(echo "${p}" | jq -r '.password') == 'p"w,\n$(rm -rf /)' ]] \
  && ok "sudo-user: hostile password intact" || bad "sudo-user: password mangled"

echo; echo "JSON safety tests: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
