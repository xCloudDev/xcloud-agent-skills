#!/usr/bin/env bash
# smoke.sh — read-only checks for xcloud:deploy. No mutations: repository
# detection is side-effect free and nothing here creates, retries or installs.
# Usage: XCLOUD_API_TOKEN=... [XCLOUD_TEST_SERVER_UUID=...] ./smoke.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XC="${CLAUDE_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/../../.." && pwd)}/scripts/xcloud.sh"
: "${XCLOUD_API_TOKEN:?XCLOUD_API_TOKEN must be set}"
PASS=0; FAIL=0
verdict(){ local l="$1" p="$2" o="$3"
  if ! echo "${o}" | jq -e '.success == true and .data != null' >/dev/null 2>&1; then
    echo "FAIL ${l} (${p}): bad envelope" >&2; FAIL=$((FAIL+1)); return; fi
  echo "PASS ${l}"; PASS=$((PASS+1)); }
check(){ local l="$1" p="$2" o
  if ! o=$("${XC}" GET "${p}" 2>&1); then echo "FAIL ${l} (${p}): ${o}" >&2; FAIL=$((FAIL+1)); return; fi
  verdict "${l}" "${p}" "${o}"; }
check "one-click catalog" "/oneclick-apps?per_page=1"
check "app requirements"  "/catalog/apps"
check "git integrations"  "/integrations/git"
# /git/detect is a POST; xcloud.sh is GET-only, so it is not part of this smoke test.
if [[ -n "${XCLOUD_TEST_SERVER_UUID:-}" ]]; then
  S="${XCLOUD_TEST_SERVER_UUID}"
  check "staging hostname" "/servers/${S}/staging-hostname?label=smoke-check"
  check "deploy keys"      "/servers/${S}/git/deploy-keys"
fi
echo; echo "Smoke: ${PASS} passed, ${FAIL} failed"; (( FAIL == 0 ))
