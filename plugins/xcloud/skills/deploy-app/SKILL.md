---
name: deploy-app
description: Deploy the project currently open in this session (a Lovable, Replit, or any other local/uncommitted app) to xCloud end to end — sync it to a Git repository, detect the right deployment path via xCloud's own detector, provision it, and verify the live HTTPS URL. Use for "deploy this app/project to xCloud", "deploy to xCloud", or similar. This skill is an orchestrator, not a second deployment engine: it does not reimplement framework/build detection (that's `POST /git/detect`), site management after provisioning (`xcloud:sites`), SSL (`xcloud:ssl`), or WordPress app management (`xcloud:wordpress`) — it hands off to them once the site exists. Server infrastructure and the actual site-creation call are owned by `xcloud:servers`.
---

# xCloud Deploy App

Orchestrates turning the project open in this session into a live xCloud site.
It owns exactly what the Public API cannot see: the local working tree, the
handoff of that code into a Git repository xCloud can read, and secret
classification. Detection, native-vs-Docker routing, and deployment status stay
server-side — this skill calls them, it does not reimplement them.

Read the shared layer first for auth, base URL, envelope, pagination, and rate
limits:

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/mcp.md` — **prefer `mcp__xcloud__*` tools
  when connected** (`git_detect`, `servers_sites_git_auto`,
  `servers_sites_git_docker`, `servers_index`, `sites_status`); the `$XC` calls
  below are the REST fallback.

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
```

Scopes: `git_detect` needs `read:servers`; provisioning needs `write:servers`.

## Response format

Brand every user-facing reply (see `reference/conventions.md` → **Response
format**): open with `☁️ **xCloud · Deploy** — <repo or domain>`, give the
trimmed result, and close with a `_via xcloud:deploy-app_` line.

Narrate each call (see **Progress narration**): before every local git command
or `$XC`/MCP call, print one line of what xCloud is doing, always led by
`xCloud` — e.g. `☁️ xCloud is checking whether this repository has a remote…`,
`☁️ xCloud is detecting the deployment path for \`acme/storefront\`…`. The first
call of a task opens with `☁️ xCloud is starting a session…`.

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) — once per
conversation.

## Sub-resources (load on demand)

| Sub-resource | Reference file |
|---|---|
| Repository sync gate (uncommitted files, remote, push, private-repo access) | `reference/repo-sync.md` |
| Secrets contract (what may be forwarded vs. what must not) | `reference/secrets.md` |
| `nodejs` vs `lovable` site-type rule | `reference/site-type.md` |

## What this skill does NOT do (yet)

Tracked separately in [issue #35](https://github.com/xCloudDev/xcloud-agent-skills/issues/35),
Phase 3/4:

- **Generating a new Dockerfile or Compose file.** If the repository already
  has one, `servers_sites_git_auto` picks it up automatically
  (`compatibility.docker_deployable` / `deploy_via: docker_compose`) and this
  skill's flow works unchanged. If none exists and the native path is
  incompatible, **stop and tell the user** — do not synthesize deployment
  files. This is a deliberate scope cut, not an oversight.
- **Lovable- and Replit-specific adapters** (`.replit`/Nix conversion, Lovable
  Supabase env classification, per-panel install instructions). Today this
  skill works the same way regardless of the originating panel: sync → detect
  → provision → verify.

## The flow

One task: *"Deploy this project to xCloud."*

1. **Repository sync gate** — see `reference/repo-sync.md`. Identify the
   remote, detect uncommitted changes, commit/push what's needed with
   approval, confirm xCloud can read the exact commit. **Stop and ask if there
   is no remote or no push credential** — do not fall back to any out-of-band
   transfer.
2. **Secrets check** — see `reference/secrets.md`. Ask for required env values
   by name; never bulk-forward a local `.env`.
3. **Detect** — `git_detect` (`POST /git/detect`) against the chosen server.
   Read `repository_access.status`; if `inaccessible`, follow its
   `next_actions` and stop. Read `detection.supported` and `compatibility`; if
   detection failed and no deployment files exist, ask the user for the app
   type rather than guessing.
4. **Select a server** — `servers_index`; the user chooses. Never pick
   silently, even with only one eligible server.
5. **Confirm**, showing team, server, repository + commit, branch, detected
   site type, domain, and deployment path (native vs. an existing
   Docker/Compose file) — then provision.
6. **Provision** — `servers_sites_git_auto` (`POST
   /servers/{uuid}/sites/git/auto`) with `confirm: true` and an
   `Idempotency-Key`. This is a real, billable site.
7. **Poll** — `sites_status` (`GET /sites/{uuid}/status`) until `terminal`.
   Branch on `deploy_state`. A non-empty `failed_steps` on a `deployed` site is
   a warning to surface, not a failure to report.
8. **Verify** the external HTTPS URL actually responds, then hand the site off
   — further changes (domains, SSL, cache, backups) go through `xcloud:sites`
   / `xcloud:ssl`.

## Core endpoints

| Operation | Method + path | Owner |
|---|---|---|
| Analyse a repository (side-effect-free) | `POST /git/detect` | this skill calls it; endpoint lives under `xcloud:servers` |
| Detect-then-deploy in one call | `POST /servers/{uuid}/sites/git/auto` | `xcloud:servers` |
| Deploy with explicit container config | `POST /servers/{uuid}/sites/git/docker` | `xcloud:servers` |
| List eligible servers | `GET /servers` | `xcloud:servers` |
| Poll deployment status | `GET /sites/{uuid}/status` | `xcloud:sites` |

**Not here:** site settings after go-live, domains, cache, deployment logs →
`xcloud:sites`; certificates → `xcloud:ssl`; WordPress app management →
`xcloud:wordpress`; server infrastructure, firewall, PHP versions →
`xcloud:servers`.

## Detect (preview, no mutation)

```bash
"$XC" POST "/git/detect" '{
  "repository_url": "https://github.com/acme/storefront.git",
  "branch": "main",
  "server_uuid": "'"$SERVER_UUID"'"
}' | jq '.data | {repository_access, detection, compatibility, deploy_via}'
```

Two distinct failures — handle them differently:

- `repository_access.status: "inaccessible"` is an **access** problem. Stop and
  follow `next_actions` (connect a provider, add a deploy key, make the repo
  public). An explicit `site_type` does not bypass this.
- A readable repository with `detection.supported: false` is a **detection**
  gap, not an access problem — ask the user for the app type; do not fall back
  to `servers_sites_git_create` for an access failure.
- On a Docker server, `compatibility.compatible: false` only means the native
  path is closed. If `compatibility.docker_deployable` is true, `git/auto`
  still deploys it (`deploy_via: docker_compose`) — never report that as a
  dead end.

## Deploy (mutating — confirm first)

```bash
"$XC" POST "/servers/$SERVER_UUID/sites/git/auto" '{
  "repository": {"url": "https://github.com/acme/storefront.git", "branch": "main"},
  "confirm": true
}' | jq '.data'
```

Everything except `repository` is optional — omit `site_type`, `domain`,
`port`, etc. unless `git_detect` got something wrong or the user wants to
override it. Pass an `Idempotency-Key` so a retry after a dropped connection
never creates a second site.

## Poll to a terminal state

```bash
SITE_UUID='replace-me'
until STATUS=$("$XC" GET "/sites/$SITE_UUID/status" | jq -r '.data.deploy_state, .data.terminal' | paste -sd' '); \
      [[ "$(echo "$STATUS" | awk '{print $2}')" == "true" ]]; do sleep 5; done
echo "$STATUS"
```

Then verify the domain actually serves before declaring success:

```bash
DOMAIN='replace-me.example.com'
curl -fsSI "https://${DOMAIN}" >/dev/null && echo "reachable" || echo "not reachable yet"
```

## Safety

- Never deploy a commit xCloud cannot read, and never push to the user's
  repository without naming the exact files being committed and getting
  approval first.
- Stop and ask when no remote repository or no push credential exists — do not
  silently skip the sync gate.
- No local `.env` value is transmitted, logged, or committed without explicit
  per-value approval (`reference/secrets.md`).
- Site creation is a real, billable mutation — confirm the team, server,
  domain, repository/branch, and deployment path immediately before the
  `confirm: true` call.
- Report success only after `deploy_state` is terminal **and** the external
  HTTPS URL has been verified — a `deployed` status with a still-cold domain
  is not done yet.

## Pitfalls

- A public HTTPS repo or one on a connected provider needs no extra setup in
  `git_detect`/`git/auto`; a private SSH URL needs a verified `deploy_key_uuid`
  first (`reference/repo-sync.md`).
- `lovable` is not a special deployment path — it is `nodejs` minus xCloud's
  provisioned database (`reference/site-type.md`). Don't Dockerize a project
  just because it originated in Lovable or Replit.
- Writes are async; `success` in the response means "accepted", not "live".
  Always poll `sites_status` to a terminal state.
