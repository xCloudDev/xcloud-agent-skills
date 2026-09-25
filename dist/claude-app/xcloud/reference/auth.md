# Authentication (shared)

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Shared by every `xcloud-*` domain skill.

## Two ways to connect — MCP first

1. **xCloud MCP (recommended).** If `mcp__xcloud__*` tools are available in
   the session, the account is already connected via OAuth — **no token setup is
   needed** and the rest of this file does not apply. Use the MCP tools directly;
   see `reference/mcp.md` for the transport rule, tool naming, and the
   confirm-before-destructive contract. If the user has no connection yet,
   onboard them with the MCP connect instructions in `reference/mcp.md`
   **before** falling back to a raw API token.
2. **REST API token (fallback).** For agents without MCP support, and for the
   REST-only operations (`/health`, API-token list/revoke). The Public API
   authenticates via [Sanctum personal access tokens](https://laravel.com/docs/sanctum)
   (Bearer auth) — everything below covers this path.

## Environment variables

```bash
export XCLOUD_API_TOKEN="..."                         # required
export XCLOUD_API_BASE_URL="https://app.xcloud.host"  # default (live)
# Local development (plaintext http needs the explicit override):
export XCLOUD_API_BASE_URL="http://xcloud.test"
export XCLOUD_ALLOW_INSECURE_HTTP=1
# Per call, optional:
XCLOUD_TEAM_ID="team-uuid"      # run against a non-default granted team (X-Team-Id)
XCLOUD_IDEMPOTENCY_KEY="$KEY"   # make a create safe to retry (Idempotency-Key)
```

A token can be granted several teams when it is created; `GET /teams` lists
them, and `XCLOUD_TEAM_ID` selects one per call. Set both per call (prefix the
command), not globally, so a later request never runs against the wrong team or
reuses a key.

Make the idempotency key **once per create and keep it** — a retry after a
timeout must send the same key, or it is a second create. Generate it with
tools every supported runtime has (no `uuidgen` needed):

```bash
KEY=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
```

The wrapper refuses a set-but-empty `XCLOUD_IDEMPOTENCY_KEY` or
`XCLOUD_TEAM_ID` (exit 64), so a failed generation or lookup stops the write
instead of silently dropping the header.

The base URL is the **only** thing that changes between local and live — never
hardcode a host in a skill body.

## Proactive token onboarding

If `XCLOUD_API_TOKEN` is missing or a request returns `401`, stop before any
write operation and guide the user through setup. **Offer the xCloud MCP
connector first** (`reference/mcp.md` → Connecting) — OAuth, no secret to
store. Only if MCP isn't an option for their client, walk them through the
token path below. Be proactive and helpful, but do **not** ask the user to
paste a raw production token into the chat by default. Direct them to the
runtime's environment, settings file, or secret store.

Use this wording pattern:

```text
☁️ **xCloud · Setup**

xCloud needs an API token before it can inspect or manage your hosting account.
Create a scoped token in the xCloud dashboard, store it in your agent runtime as
`XCLOUD_API_TOKEN`, restart the agent if needed, then ask me to check the xCloud
connection.

_via xcloud:account_
```

After setup, verify with `GET /health` and `GET /user` before continuing the
original task.

## Setting the token (Claude Code / CLI)

**Step 1 — generate the token first.** In the xCloud dashboard:
**Profile → API Tokens → Generate New Token** → choose the scopes you need (e.g.
`read:servers`) → copy it immediately (shown only once). Always tell the user to
create the token *before* the storage steps below.

**Step 2 — store it.** The token must live in the **environment Claude Code uses
for the Bash tool**. The reliable, persistent way is the user `settings.json` —
guide the user through this exact path:

**Recommended — `~/.claude/settings.json`** (loads on every session):

1. Open the file (exact path `~/.claude/settings.json`, i.e.
   `/Users/<you>/.claude/settings.json`). For example:
   ```bash
   nano ~/.claude/settings.json
   ```
2. Add an `env` block with the token (and optionally the base URL). If the file
   is empty, paste the whole object; if it already has keys, add `env` alongside
   them — don't duplicate the outer braces:
   ```json
   {
     "env": {
       "XCLOUD_API_TOKEN": "your-token-here",
       "XCLOUD_API_BASE_URL": "https://app.xcloud.host"
     }
   }
   ```
3. Save, then **restart Claude Code** (quit + reopen) so the new env is applied.

**Do NOT tell the user to run `! export XCLOUD_API_TOKEN=…` in the prompt** — that
executes in a throwaway subshell and does **not** persist to the next Bash call,
so the very next request still sees no token. Always direct them to
`settings.json`.

Alternative — shell profile (only affects terminals the user launches manually):
```bash
echo "export XCLOUD_API_TOKEN='your-token-here'" >> ~/.zshrc && source ~/.zshrc
```

> **Browser/chat-only agents:** use the xCloud MCP connector or the host secret store. Never request production credentials in chat. If secure credential injection is unavailable, stop authenticated work and explain how to connect securely.
>
> **If a token is exposed (pasted in the wrong place, shared transcript,
> committed):** revoke it immediately — xCloud dashboard → **Profile → API
> Tokens** → delete it, or via the API: `GET /user/tokens` to find its `uuid`,
> then `DELETE /user/tokens/{tokenUuid}` (`xcloud:account`; needs a `*`-scope
> token). Then generate a fresh scoped token and update the runtime. Rotate
> routinely, not only after incidents.

## Generating a token

xCloud dashboard → **Profile → API Tokens → Generate New Token** → choose scopes
→ copy immediately (shown once).

## Scopes (Sanctum abilities)

| Scope | Grants |
|---|---|
| `read:sites` | All `GET` under `/sites/*` and `/ssl-certificates/*` |
| `write:sites` | All write methods under `/sites/*` |
| `read:servers` | All `GET` under `/servers/*` |
| `write:servers` | All write methods under `/servers/*` (incl. buying a server) |
| `read:billing` | Plan, overview, invoices, bills, subscriptions, payment methods |
| `read:addons` | Mailbox and mail-delivery reads |
| `write:addons` | Add-on purchases and deletion, paying an invoice |
| `*` | Full access (incl. token management) |

## Fine-grained authorization

Scopes are coarse; each request also passes a per-resource policy check. A `403`
with a valid token means the user lacks a required team permission (e.g.
`site:manage-ssl` for SSL renewal), not that the token is wrong.

## Verifying auth

```bash
scripts/xcloud.sh GET /user
```

`401` → token missing/expired/revoked. `403` → scope or team-permission gap.
