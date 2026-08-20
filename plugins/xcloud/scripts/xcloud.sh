#!/usr/bin/env bash
# xcloud.sh — thin curl wrapper for the xCloud Public API.
#
# Shared by every xcloud-* domain skill. Skills invoke it via
# "${CLAUDE_PLUGIN_ROOT}"/scripts/xcloud.sh — one copy, no per-skill duplication.
#
# Usage:
#   ./xcloud.sh GET  /sites
#   ./xcloud.sh GET  '/sites/abc-123/ssl'
#   ./xcloud.sh POST /sites/abc-123/ssl/renew '{"force":true}'
#   ./xcloud.sh POST /sites/abc-123/ssl-certificates - < body.json   # body on stdin
#   jq -n --arg pw "$PW" '{password:$pw}' | ./xcloud.sh POST /servers/x/sudo-users -
#
# Pass `-` as the body argument to read the JSON body from stdin. Prefer the
# stdin form for bodies carrying secrets (private keys, passwords, credentials):
# argv is visible to other processes on the machine; stdin is not. Either way
# the body is handed to curl via stdin, never on curl's command line.
#
# Reads:
#   XCLOUD_API_TOKEN            (required) Sanctum personal access token
#   XCLOUD_API_BASE_URL         (default https://app.xcloud.host) — custom hosts
#                               must be https:// (see XCLOUD_ALLOW_INSECURE_HTTP)
#   XCLOUD_ALLOW_INSECURE_HTTP  (optional) set to 1 to permit a plaintext http://
#                               base URL — local development ONLY (e.g.
#                               http://xcloud.test). Never use over a real network:
#                               the bearer token would travel unencrypted.
#   XCLOUD_VERBOSE              (optional) set to 1 for verbose curl output.
#                               The Authorization header and any occurrence of
#                               the token are redacted from verbose output.
#
# Output: response body to stdout. Exit code 0 on 2xx, non-zero on 4xx/5xx.

set -euo pipefail

if [[ -z "${XCLOUD_API_TOKEN:-}" ]]; then
  cat >&2 <<'EOF'
error: XCLOUD_API_TOKEN is not set.

Step 1 — Create an API token in xCloud:
  xCloud dashboard -> Profile -> API Tokens -> Generate New Token
  -> choose the scopes you need (e.g. read:servers) -> copy it (shown only once).

Step 2 — Store it persistently for Claude Code:
  a. Open  ~/.claude/settings.json   (e.g.  nano ~/.claude/settings.json )
  b. Add an "env" block with your token:
       {
         "env": {
           "XCLOUD_API_TOKEN": "your-token-here",
           "XCLOUD_API_BASE_URL": "https://app.xcloud.host"
         }
       }
  c. Restart Claude Code (quit + reopen) so it loads.

Do NOT use '! export ...' in the prompt — it runs in a throwaway subshell and
will not persist to the next call. See reference/auth.md for the full guide
(and the claude.ai-app alternative).
EOF
  exit 64
fi

BASE_URL="${XCLOUD_API_BASE_URL:-https://app.xcloud.host}"

# Refuse to send the bearer token over plaintext HTTP unless explicitly allowed
# for local development (e.g. http://xcloud.test).
case "${BASE_URL}" in
  https://*) ;;
  http://*)
    if [[ "${XCLOUD_ALLOW_INSECURE_HTTP:-0}" != "1" ]]; then
      cat >&2 <<EOF
error: XCLOUD_API_BASE_URL is plaintext http:// (${BASE_URL}).
The bearer token would be sent unencrypted. Use an https:// URL, or — for
LOCAL DEVELOPMENT ONLY (e.g. http://xcloud.test) — set:
  XCLOUD_ALLOW_INSECURE_HTTP=1
EOF
      exit 64
    fi
    ;;
  *)
    echo "error: XCLOUD_API_BASE_URL must start with https:// (got: ${BASE_URL})" >&2
    exit 64
    ;;
esac

METHOD="${1:?usage: xcloud.sh <METHOD> <PATH> [JSON_BODY|-]}"
RAW_PATH="${2:?usage: xcloud.sh <METHOD> <PATH> [JSON_BODY|-]}"
BODY="${3:-}"

# Normalize path: ensure it starts with /api/v1
if [[ "${RAW_PATH}" == /api/v1/* ]]; then
  PATH_PART="${RAW_PATH}"
elif [[ "${RAW_PATH}" == /* ]]; then
  PATH_PART="/api/v1${RAW_PATH}"
else
  PATH_PART="/api/v1/${RAW_PATH}"
fi

URL="${BASE_URL}${PATH_PART}"

CURL_OPTS=(
  -sS
  -X "${METHOD}"
  -H "Authorization: Bearer ${XCLOUD_API_TOKEN}"
  -H "Accept: application/json"
  -H "Content-Type: application/json"
  -w '\n%{http_code}'
)

if [[ "${XCLOUD_VERBOSE:-0}" == "1" ]]; then
  CURL_OPTS+=(-v)
fi

# The token must never appear on curl's stderr (verbose traces print request
# headers). Literal string replacement — no regex, so any token content is safe.
redact_stderr() {
  local line
  while IFS= read -r line; do
    printf '%s\n' "${line//"${XCLOUD_API_TOKEN}"/[REDACTED]}"
  done
}

# The body is always delivered to curl on stdin (--data-binary @-), never in
# curl's argv. `-` as the body argument reads the wrapper's own stdin.
if [[ "${BODY}" == "-" ]]; then
  CURL_OPTS+=(--data-binary @-)
  RESPONSE=$(curl "${CURL_OPTS[@]}" "${URL}" 2> >(redact_stderr >&2))
elif [[ -n "${BODY}" ]]; then
  CURL_OPTS+=(--data-binary @-)
  RESPONSE=$(printf '%s' "${BODY}" | curl "${CURL_OPTS[@]}" "${URL}" 2> >(redact_stderr >&2))
else
  RESPONSE=$(curl "${CURL_OPTS[@]}" "${URL}" < /dev/null 2> >(redact_stderr >&2))
fi

HTTP_CODE=$(printf '%s' "${RESPONSE}" | tail -n1)
BODY_OUT=$(printf '%s' "${RESPONSE}" | sed '$d')

printf '%s\n' "${BODY_OUT}"

if (( HTTP_CODE >= 400 )); then
  echo "" >&2
  echo "HTTP ${HTTP_CODE} from ${METHOD} ${PATH_PART}" >&2
  exit 1
fi
