#!/usr/bin/env bash
# Offline token argv and host hardening checks; curl is always a local fake.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XC="${SCRIPT_DIR}/../xcloud.sh"
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "${TEST_DIR}"' EXIT
export TEST_DIR
export XCLOUD_API_TOKEN='dummy-hardening-token|special/=='
unset XCLOUD_API_BASE_URL XCLOUD_ALLOW_CUSTOM_HOST XCLOUD_ALLOW_INSECURE_HTTP
unset XCLOUD_TEAM_ID XCLOUD_IDEMPOTENCY_KEY XCLOUD_VERBOSE
cat > "${TEST_DIR}/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${TEST_DIR}/argv"
while (( $# )); do
  if [[ "$1" == '-H' && "$2" == @* ]]; then
    header_file="${2#@}"
    [[ "$(stat -c %a "${header_file}")" == 600 ]]
    cat "${header_file}" > "${TEST_DIR}/headers"
    printf '%s' "${header_file}" > "${TEST_DIR}/header-path"
  fi
  shift
done
printf '{}\n200\n'
exit "${FAKE_CURL_STATUS:-0}"
CURL
chmod +x "${TEST_DIR}/curl"
export PATH="${TEST_DIR}:${PATH}"
"${XC}" GET /user > /dev/null
! grep -qF "${XCLOUD_API_TOKEN}" "${TEST_DIR}/argv"
grep -qxF "Authorization: Bearer ${XCLOUD_API_TOKEN}" "${TEST_DIR}/headers"
[[ ! -e "$(cat "${TEST_DIR}/header-path")" ]]
echo 'PASS token absent from argv, header delivered via private file, file removed'
if FAKE_CURL_STATUS=7 "${XC}" GET /user >/dev/null 2>&1; then
  echo 'FAIL curl failure was ignored' >&2; exit 1
fi
[[ ! -e "$(cat "${TEST_DIR}/header-path")" ]]
echo 'PASS header file removed after curl failure'
for host in https://example.invalid https://app.xcloud.host.example.invalid \
            https://app.xcloud.host@example.invalid http://127.0.0.1:8000; do
  rm -f "${TEST_DIR}/argv"
  if XCLOUD_API_BASE_URL="$host" XCLOUD_ALLOW_INSECURE_HTTP=1 \
     "${XC}" GET /user > /dev/null 2> "${TEST_DIR}/stderr"; then
    echo 'FAIL custom host accepted without opt-in' >&2; exit 1
  fi
  [[ ! -e "${TEST_DIR}/argv" ]]
  grep -q 'XCLOUD_ALLOW_CUSTOM_HOST=1' "${TEST_DIR}/stderr"
done
echo 'PASS custom hosts refused before curl'
XCLOUD_API_BASE_URL=https://example.invalid XCLOUD_ALLOW_CUSTOM_HOST=1 \
  "${XC}" GET /user > /dev/null 2> "${TEST_DIR}/stderr"
grep -q '^warning:.*custom host' "${TEST_DIR}/stderr"
echo 'PASS custom HTTPS host opt-in runs with warning'
rm -f "${TEST_DIR}/argv"
if XCLOUD_API_BASE_URL=http://127.0.0.1:8000 XCLOUD_ALLOW_CUSTOM_HOST=1 \
   "${XC}" GET /user > /dev/null 2> "${TEST_DIR}/stderr"; then
  echo 'FAIL plaintext host accepted without both overrides' >&2; exit 1
fi
[[ ! -e "${TEST_DIR}/argv" ]]
XCLOUD_API_BASE_URL=http://127.0.0.1:8000 XCLOUD_ALLOW_CUSTOM_HOST=1 \
  XCLOUD_ALLOW_INSECURE_HTTP=1 "${XC}" GET /user >/dev/null 2> "${TEST_DIR}/stderr"
grep -q '^warning:.*custom host' "${TEST_DIR}/stderr"
echo 'PASS local HTTP requires both overrides'
