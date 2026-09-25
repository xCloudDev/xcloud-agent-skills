#!/usr/bin/env bash
# wrapper-test.sh — offline tests for scripts/xcloud.sh (no live API needed).
#
# Covers the hardening acceptance criteria:
#   - plaintext http:// base URLs are refused without XCLOUD_ALLOW_INSECURE_HTTP=1
#   - non-http(s) base URLs are refused
#   - verbose mode never prints the bearer token (fake token, redacted)
#   - non-GET methods and request bodies are blocked before network I/O
#   - non-verbose behavior (envelope, exit codes) is unchanged
#   - X-Team-Id / Idempotency-Key are sent only when set, and CR/LF or other
#     unexpected characters in them are refused (no header injection)
#   - a set-but-empty XCLOUD_TEAM_ID / XCLOUD_IDEMPOTENCY_KEY stops the call
#
# Usage: ./wrapper-test.sh   (exit 0 = all pass)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XC="${SCRIPT_DIR}/../xcloud.sh"
FAKE_TOKEN='fake-token-1234|WithSpecial+Chars/=='
PASS=0; FAIL=0
ok(){ echo "PASS $1"; PASS=$((PASS+1)); }
bad(){ echo "FAIL $1" >&2; FAIL=$((FAIL+1)); }

# --- tiny local echo server -------------------------------------------------
PORT_FILE="$(mktemp)"; LOG_FILE="$(mktemp)"
python3 - "$PORT_FILE" "$LOG_FILE" <<'PY' &
import json, sys, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

port_file, log_file = sys.argv[1], sys.argv[2]

class H(BaseHTTPRequestHandler):
    def _reply(self):
        n = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(n).decode() if n else ""
        with open(log_file, 'a') as f:
            f.write(json.dumps({"path": self.path, "method": self.command, "body": body}) + "\n")
        code = 404 if self.path.endswith('/missing') else 200
        out = json.dumps({"success": code == 200, "echo": body,
                          "team": self.headers.get('X-Team-Id'),
                          "idem": self.headers.get('Idempotency-Key')}).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(out)))
        self.end_headers()
        self.wfile.write(out)
    do_GET = _reply; do_POST = _reply; do_PUT = _reply; do_DELETE = _reply
    def log_message(self, *a): pass

srv = HTTPServer(('127.0.0.1', 0), H)
with open(port_file, 'w') as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
PY
SERVER_PID=$!
trap 'kill "${SERVER_PID}" 2>/dev/null' EXIT
for _ in $(seq 1 50); do [[ -s "${PORT_FILE}" ]] && break; sleep 0.1; done
PORT="$(cat "${PORT_FILE}")"
[[ -n "${PORT}" ]] || { echo "test server failed to start" >&2; exit 1; }
LOCAL_URL="http://127.0.0.1:${PORT}"

# --- 1. plaintext http refused without the override (#14) --------------------
if out=$(XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
         "${XC}" GET /user 2>&1); then
  bad "http-refused: wrapper accepted plaintext http without override"
else
  echo "${out}" | grep -q 'XCLOUD_ALLOW_INSECURE_HTTP' \
    && ok "http-refused (clear override hint)" \
    || bad "http-refused: error lacks override hint"
fi

# --- 2. non-http(s) scheme refused (#14) -------------------------------------
if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="ftp://example.com" \
   "${XC}" GET /user >/dev/null 2>&1; then
  bad "bad-scheme-refused"
else
  ok "bad-scheme-refused"
fi

# --- 3. verbose mode redacts the token (#15) ---------------------------------
verr=$(XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
       XCLOUD_ALLOW_INSECURE_HTTP=1 XCLOUD_VERBOSE=1 \
       "${XC}" GET /user 2>&1 >/dev/null)
if printf '%s' "${verr}" | grep -qF "${FAKE_TOKEN}"; then
  bad "verbose-redaction: token leaked to verbose output"
else
  printf '%s' "${verr}" | grep -q '\[REDACTED\]' \
    && ok "verbose-redaction (token replaced with [REDACTED])" \
    || ok "verbose-redaction (token absent)"
fi

# --- mutations and bodies must stop before any network request ---------------
for method in POST PUT PATCH DELETE OPTIONS HEAD get 'GET -X POST'; do
  : > "${LOG_FILE}"
  if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
     XCLOUD_ALLOW_INSECURE_HTTP=1 XCLOUD_ALLOW_WRITE=1 \
     "${XC}" "${method}" /sites/x >/dev/null 2>&1; then
    bad "blocked-method ${method}"
  elif [[ -s "${LOG_FILE}" ]]; then
    bad "blocked-method ${method} sent a network request"
  else
    ok "blocked-method ${method} without network (no env override)"
  fi
done
for body in '{}' '-' ''; do
  : > "${LOG_FILE}"
  if printf '{}' | XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
     XCLOUD_ALLOW_INSECURE_HTTP=1 "${XC}" GET /user "${body}" >/dev/null 2>&1; then
    bad "GET body refused"
  elif [[ -s "${LOG_FILE}" ]]; then bad "GET body sent a request"
  else ok "GET body/extra argument refused before network"; fi
done

# --- 6. non-verbose envelope + exit codes unchanged --------------------------
XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
  XCLOUD_ALLOW_INSECURE_HTTP=1 "${XC}" GET /user >/dev/null 2>&1 \
  && ok "get-2xx-exit-0" || bad "get-2xx-exit-0"
if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
   XCLOUD_ALLOW_INSECURE_HTTP=1 "${XC}" GET /missing >/dev/null 2>&1; then
  bad "get-404-exit-1"
else
  ok "get-404-exit-1"
fi

# --- 7. multi-team + idempotency headers ------------------------------------
TEAM='2ff5443e-42f5-4dfa-a50c-122ca948b00e'
resp=$(XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
       XCLOUD_ALLOW_INSECURE_HTTP=1 XCLOUD_TEAM_ID="${TEAM}" \
       XCLOUD_IDEMPOTENCY_KEY='deploy-7f3a:retry.1' \
       "${XC}" GET /servers 2>/dev/null)
echo "${resp}" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["team"]==sys.argv[1] and d["idem"]=="deploy-7f3a:retry.1" else 1)' "${TEAM}" \
  && ok "team-and-idempotency-headers sent" || bad "team-and-idempotency-headers sent"
resp=$(XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
       XCLOUD_ALLOW_INSECURE_HTTP=1 "${XC}" GET /user 2>/dev/null)
echo "${resp}" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["team"] is None and d["idem"] is None else 1)' \
  && ok "no-team-header-by-default" || bad "no-team-header-by-default"
for bad_value in $'abc\r\nX-Evil: 1' 'team id' 'x;y'; do
  if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
     XCLOUD_ALLOW_INSECURE_HTTP=1 XCLOUD_TEAM_ID="${bad_value}" \
     "${XC}" GET /user >/dev/null 2>&1; then
    bad "team-header-injection refused (${bad_value@Q})"
  else
    ok "team-header-injection refused (${bad_value@Q})"
  fi
done
if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
   XCLOUD_ALLOW_INSECURE_HTTP=1 XCLOUD_IDEMPOTENCY_KEY=$'k\r\nX-Evil: 1' \
   "${XC}" GET /x >/dev/null 2>&1; then
  bad "idempotency-header-injection refused"
else
  ok "idempotency-header-injection refused"
fi

# --- 8. set-but-empty selectors are refused, never silently dropped ----------
# A key generator that is missing leaves an empty value behind; the write must
# stop rather than go out without its Idempotency-Key.
: > "${LOG_FILE}"
if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
   XCLOUD_ALLOW_INSECURE_HTTP=1 \
   XCLOUD_IDEMPOTENCY_KEY="$(no-such-key-generator 2>/dev/null)" \
   "${XC}" GET /servers >/dev/null 2>&1; then
  bad "empty-idempotency-key refused"
else
  [[ -s "${LOG_FILE}" ]] && bad "empty-idempotency-key refused (but the request was sent)" \
    || ok "empty-idempotency-key refused (request never sent)"
fi
if XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
   XCLOUD_ALLOW_INSECURE_HTTP=1 XCLOUD_TEAM_ID='' \
   "${XC}" GET /servers >/dev/null 2>&1; then
  bad "empty-team-id refused (would fall back to the default team)"
else
  ok "empty-team-id refused (no silent default-team fallback)"
fi

echo; echo "Wrapper tests: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
