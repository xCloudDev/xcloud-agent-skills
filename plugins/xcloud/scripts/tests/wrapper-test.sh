#!/usr/bin/env bash
# wrapper-test.sh — offline tests for scripts/xcloud.sh (no live API needed).
#
# Covers the hardening acceptance criteria:
#   - plaintext http:// base URLs are refused without XCLOUD_ALLOW_INSECURE_HTTP=1
#   - non-http(s) base URLs are refused
#   - verbose mode never prints the bearer token (fake token, redacted)
#   - JSON bodies reach the API intact via stdin (`-`) and via the argv form,
#     and in both cases the body never appears in curl's argv
#   - non-verbose behavior (envelope, exit codes) is unchanged
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
        out = json.dumps({"success": code == 200, "echo": body}).encode()
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

# --- 4. body via stdin reaches the API intact (#16) --------------------------
BODY='{"password":"p@ss\"word","note":"line1\nline2"}'
resp=$(printf '%s' "${BODY}" | XCLOUD_API_TOKEN="${FAKE_TOKEN}" \
       XCLOUD_API_BASE_URL="${LOCAL_URL}" XCLOUD_ALLOW_INSECURE_HTTP=1 \
       "${XC}" POST /servers/x/sudo-users - 2>/dev/null)
echo "${resp}" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if json.loads(d["echo"])["password"]=="p@ss\"word" else 1)' \
  && ok "stdin-body (intact round-trip incl. quotes)" || bad "stdin-body"

# --- 5. argv body form still works, body absent from curl argv (#16) ---------
resp=$(XCLOUD_API_TOKEN="${FAKE_TOKEN}" XCLOUD_API_BASE_URL="${LOCAL_URL}" \
       XCLOUD_ALLOW_INSECURE_HTTP=1 \
       "${XC}" POST /sites/x/rescue '{"restart_nginx":true}' 2>/dev/null)
echo "${resp}" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if json.loads(d["echo"])["restart_nginx"] is True else 1)' \
  && ok "argv-body-compat" || bad "argv-body-compat"
# the wrapper always hands the body to curl via --data-binary @- (stdin):
grep -q -- '--data-binary @-' "${XC}" && ! grep -q -- '--data-raw' "${XC}" \
  && ok "curl-argv-clean (--data-binary @- only)" || bad "curl-argv-clean"

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

echo; echo "Wrapper tests: ${PASS} passed, ${FAIL} failed"
(( FAIL == 0 ))
