# Authentication (shared)

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


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

Prefer the MCP connector with browser sign-in: no token to store. Use a token
only for the REST fallback, and give it the narrowest abilities the job needs.

**Step 1: generate the token first.** In the xCloud dashboard:
**Account → Developers → API Tokens** (`https://app.xcloud.host/user/api-tokens`)
→ **Generate New Token** → tick only the abilities you need (for example
`read:servers` and `read:sites`) → copy it immediately (shown once). Never
steer the user to a full-access token. Always have the user create the token
*before* the storage steps.

**Step 2: store it where the Bash tool can read it, not in a shell profile.**
Put it in a file only the user can read, and load it for the session:

```bash
umask 077
mkdir -p ~/.config/xcloud
${EDITOR:-nano} ~/.config/xcloud/token      # paste the token on one line, save
chmod 600 ~/.config/xcloud/token
```

Start Claude Code from a shell that loads it, for example
`XCLOUD_API_TOKEN="$(cat ~/.config/xcloud/token)" claude`, or keep it in the
operating system's secret store and read it from there. Do not paste the token
into the chat, into a command line or into a shell profile (`~/.zshrc`
keeps it in history and in every new terminal). A value typed as
`! export XCLOUD_API_TOKEN=…` in the Claude Code prompt runs in a throwaway
subshell and does not reach the next Bash call.

> **Browser/chat-only agents:** use the xCloud MCP connector or the host secret store. Never request production credentials in chat. If secure credential injection is unavailable, stop authenticated work and explain how to connect securely.
>
> **If a token is exposed (pasted in the wrong place, shared transcript,
> committed):** revoke it immediately: **Account → Developers → API Tokens** →
> delete it. Through the API, listing and revoking tokens use their own
> abilities (`read:tokens`, `write:tokens`; `xcloud:account`), which a token
> only has if the user ticked them. Then generate a fresh, narrowly scoped
> token and update the runtime. Rotate routinely, not only after incidents.

## Abilities (Sanctum scopes)

Tick the narrowest set. Generated from xCloud's own list for the release
named in the capability map.

<!-- facts:scopes:start -->
| Ability | What it allows |
|---|---|
| `read:servers` | Read servers, server sites, logs, monitoring and settings |
| `read:sites` | Read sites, deployments, backups, SSL and WordPress status |
| `read:billing` | Read plan, invoices and subscriptions |
| `read:addons` | Read mailboxes and mail delivery (the mailbox settings reads sit in write:addons) |
| `write:servers` | Change servers: services, firewall, PHP, cron jobs, databases, sudo users, reboot |
| `write:sites` | Change sites: deploy, domain, PHP version, backups and restores, SSL, redirects, WordPress, cache |
| `write:addons` | Buy or change mailboxes and mail delivery |
| `read:tokens` | List API tokens (REST only) |
| `write:tokens` | Revoke API tokens (REST only) |
| `read:email-logs` | Read email logs (opt-in; a wildcard token has it) |
| `commands:run` | Run a command on a site (opt-in; needs two-factor sign-in and the Command Runner permission) |
| `mcp:invoke` | Use the MCP endpoint (opt-in; a wildcard token does not include it) |
| `*` | Full access. Avoid it; pick the narrowest abilities |
<!-- facts:scopes:end -->

A token can also be set to refuse destructive actions on MCP; prefer that for
agents that only need to look and change, not delete.

## Fine-grained authorization

Scopes are coarse; each request also passes a per-resource policy check. A `403`
with a valid token means the user lacks a required team permission (e.g.
`site:manage-ssl` for SSL renewal), not that the token is wrong.

## Verifying auth

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/xcloud.sh GET /user
```

`401` → token missing/expired/revoked. `403` → scope or team-permission gap.
