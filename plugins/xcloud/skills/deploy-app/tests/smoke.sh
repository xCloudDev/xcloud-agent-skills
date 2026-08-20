#!/usr/bin/env bash
# smoke.sh — read-only checks for xcloud:deploy-app. No mutations.
#
# git_detect (POST /git/detect) is side-effect-free repository analysis, so it
# is safe to run unconditionally against a fixed public repository — unlike
# servers_sites_git_auto/servers_sites_git_docker, which provision a real,
# billable site and are never exercised by a smoke suite.
#
# Usage: XCLOUD_API_TOKEN=... [XCLOUD_TEST_SERVER_UUID=...] ./smoke.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XC="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/../../.." && pwd)}/scripts/xcloud.sh"
: "${XCLOUD_API_TOKEN:?XCLOUD_API_TOKEN must be set}"

# A small, stable, public repository used only as a detection fixture.
TEST_REPO_URL="${XCLOUD_TEST_DEPLOY_REPO_URL:-https://github.com/laravel/laravel.git}"

PASS=0; FAIL=0

check_detect(){
  local label="$1" body="$2" o
  if ! o=$("${XC}" POST "/git/detect" "${body}" 2>&1); then
    echo "FAIL ${label}: ${o}" >&2; FAIL=$((FAIL+1)); return
  fi
  if ! echo "${o}" | jq -e '.success == true and .data != null and .data.repository_access != null' >/dev/null 2>&1; then
    echo "FAIL ${label}: bad envelope" >&2; FAIL=$((FAIL+1)); return
  fi
  echo "PASS ${label}"; PASS=$((PASS+1))
}

check_detect "detect public repo (no server)" \
  '{"repository_url":"'"${TEST_REPO_URL}"'"}'

if [[ -n "${XCLOUD_TEST_SERVER_UUID:-}" ]]; then
  check_detect "detect public repo (against a server)" \
    '{"repository_url":"'"${TEST_REPO_URL}"'","server_uuid":"'"${XCLOUD_TEST_SERVER_UUID}"'"}'
else
  echo "SKIP detect against a server (XCLOUD_TEST_SERVER_UUID not set)"
fi

echo; echo "Smoke: ${PASS} passed, ${FAIL} failed"; (( FAIL == 0 ))
