#!/usr/bin/env bash
# xcloud.sh — thin curl wrapper for the xCloud Public API.
#
# Shared by every xcloud-* domain skill. Skills invoke it via
# "${CLAUDE_PLUGIN_ROOT}"/scripts/xcloud.sh — one copy, no per-skill duplication.
#
# Usage:
#   ./xcloud.sh GET  /sites
#   ./xcloud.sh GET  '/sites/abc-123/ssl'
#
# This packaged fallback is read-only: GET only, no request bodies.
# Use confirmation-gated xCloud MCP tools for mutations; there is no write
# override flag or environment variable.
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
#   XCLOUD_TEAM_ID              (optional) team uuid for a multi-team token, sent
#                               as X-Team-Id. Omit for the token's default team.
#   XCLOUD_IDEMPOTENCY_KEY      (optional) sent as Idempotency-Key so a retried
#                               create cannot run twice. Use a fresh key per
#                               distinct create; reuse it only to retry the same
#                               request.
#
# Output: response body to stdout. Exit code 0 on 2xx, non-zero on 4xx/5xx.

set -euo pipefail

if [[ -z "${XCLOUD_API_TOKEN:-}" ]]; then
  cat >&2 <<'EOF'
error: XCLOUD_API_TOKEN is not set.

Step 1 — Create an API token in xCloud:
  xCloud dashboard -> Profile -> API Tokens -> Generate New Token
  -> choose read-only scopes only (e.g. read:servers) -> copy it (shown only once).

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

# Enforce the fallback boundary before constructing or sending a request.
# This cannot be bypassed by an environment variable or an approval flag.
if [[ "${METHOD}" != "GET" || "$#" -ne 2 || -n "${BODY}" ]]; then
  echo "error: the bundled REST fallback permits GET with no body only; use confirmation-gated xCloud MCP tools (or the dashboard) for changes" >&2
  exit 64
fi

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

# Header values come from the environment; a strict charset keeps a stray CR/LF
# from injecting extra headers. Set-but-empty is refused, not ignored: it is what
# a failed `$(...)` leaves behind, and silently dropping the header would run the
# call against the default team, or make a "safe to retry" create unsafe.
if [[ -n "${XCLOUD_TEAM_ID+set}" ]]; then
  if [[ ! "${XCLOUD_TEAM_ID}" =~ ^[A-Za-z0-9-]{1,64}$ ]]; then
    echo "error: XCLOUD_TEAM_ID is set but is not a team uuid (letters, digits, hyphens); unset it for the default team" >&2
    exit 64
  fi
  CURL_OPTS+=(-H "X-Team-Id: ${XCLOUD_TEAM_ID}")
fi
if [[ -n "${XCLOUD_IDEMPOTENCY_KEY+set}" ]]; then
  if [[ ! "${XCLOUD_IDEMPOTENCY_KEY}" =~ ^[A-Za-z0-9._:-]{1,255}$ ]]; then
    echo "error: XCLOUD_IDEMPOTENCY_KEY is set but empty or invalid (letters, digits and . _ : - only); refusing to send the write without it" >&2
    exit 64
  fi
  CURL_OPTS+=(-H "Idempotency-Key: ${XCLOUD_IDEMPOTENCY_KEY}")
fi

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

RESPONSE=$(curl "${CURL_OPTS[@]}" "${URL}" < /dev/null 2> >(redact_stderr >&2))

HTTP_CODE=$(printf '%s' "${RESPONSE}" | tail -n1)
BODY_OUT=$(printf '%s' "${RESPONSE}" | sed '$d')

printf '%s\n' "${BODY_OUT}"

if (( HTTP_CODE >= 400 )); then
  echo "" >&2
  echo "HTTP ${HTTP_CODE} from ${METHOD} ${PATH_PART}" >&2
  exit 1
fi
