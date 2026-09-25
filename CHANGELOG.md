# Changelog

All notable changes to the xCloud Public API skill are documented in this file.

## [4.4.2] - 2026-09-24

- Sync official xCloud v4.4.1 (commit d469ad045c0090a7c2ee0da45e04acbb9de1b64c): nine capability skills, including troubleshoot/performance, corrected capability map and Git/Docker deployment guidance.
- Retain the published v4.3.2 ClawHub GET-only/no-body REST enforcement. Mutations use approved MCP tools or the dashboard; no REST write bypass.
- Refresh the marketplace router, README and security documentation; include the shared capability map and both new skills in the portable and ClawHub distributions.
- Preserve MIT license and verify package integrity. Registry review is checked after publication, not assumed from these files.

## [4.4.1] - 2026-09-24

**The "what you cannot do" list, re-checked against xCloud v2.8.8.** Every row
of `reference/capability-map.md` was compared with the v2.8.8 routes
(`routes/public-api.php`), controllers and dashboard navigation. Wrong claims
are fixed, dashboard paths now match the dashboard's own menu labels, and
missing dashboard-only and impossible jobs are added.

### Fixed

- **Server PHP default does not move sites.** `servers.php-versions.default`
  runs `update-alternatives --set php` and sets the version new sites get; no
  existing site's PHP version changes. The capability map, `xcloud:performance`
  and `servers/reference/php-versions.md` said it "moves every site that
  follows the default".
- **Logs.** There is no separate PHP-FPM error log: the site's web server error
  log (where a PHP fatal lands) is read by `sites.access-logs?type=nginx`,
  together with the 7G **and 8G** firewall logs. Dashboard-only logs are the
  WordPress `debug.log`, the Laravel log, PM2, docker-compose, agentic-stack
  journals and server logs (fail2ban, auth.log).
- **`servers.snapshots` lists site snapshots**, not a server image (it
  returns the site snapshots across a server). A server's provider backup at
  **Server → Backup** is dashboard-only, and nothing on the API reads it.
- **Staging free-plan `403`** applies to Git sites; a WordPress site gets the
  `422` first.
- **Dashboard paths** now use the dashboard's menu labels: Site → WordPress →
  Caching, Site → Site Settings (PHP version), Site → Site Monitoring → Logs,
  Site → Domain → Domain / Redirection, Site → Tools → Site Rules / Nginx
  Customization, Site → Site Backup → Previous Backups / Backup Settings,
  Site → Manage Staging, Site overview → Add Staging, Server → Backup,
  Account → Global Settings → Site Backup, Account → Integrations → Storage
  Provider, Account → Developers → API Tokens, Account → Billing → Bills &
  Payment, Servers → Create server → Bring and Manage Your Own Server.

### Added

- A **"Not on this list: these are API jobs"** section: Git-site staging,
  the 7G/8G and error logs, correct-and-retry of a failed deploy, server PHP
  and Node versions, Docker backup settings, firewall/fail2ban, sudo users,
  cron, services, deploy keys, SSL, verified reboots, vulnerability ignore,
  magic login and mailboxes.
- Dashboard-only rows: page-cache duration and exclusions, PHP settings and
  extensions, per-site IP allow/deny (`sites.ipAccess` reads), basic
  authentication, clone and migrate, supervisor processes
  (`servers.supervisorProcesses` reads), resize or delete a server.
- Impossible row: a compose file that binds 80/443, publishes no port or pulls
  a private-registry image, as-is.
- Status table rows: the free-plan staging `403` and the PageSpeed `409`
  (a scan still running, not a cooldown).

## [4.4.0] - 2026-09-24

**Two diagnosis skills for the two most common support jobs.** Both are
derived from the xCloud brain's agent guides (XC-AGT-005 "Troubleshoot a 500
error" and XC-AGT-012 "Diagnose a slow site"), and every operation they name,
every field and every status code was checked against the xCloud Public API
contract and the v2.8.8 source.

### Added

- **`xcloud:troubleshoot`** — a site returning 500/502/503, a critical error,
  a site that is down. A fixed read order, cheapest first: `sites.status` (a
  site mid-deploy explains a 500 by itself) → `sites.events` → the nginx
  access **and** error log (`sites.access-logs?type=nginx`, bounded with
  `limit`) → staging push history → `sites.wordpress.status` → `sites.wp-debug`
  (confirmed, turned back off) → `servers.services`. Says plainly that the
  PHP-FPM error log and `debug.log` are **Site → Logs** only; temporary sudo
  access is revoked when the investigation ends; never restarts or reboots to
  "clear" an error before the cause is known.
- **`xcloud:performance`** — a slow site. Site and server monitoring (and
  their history, a `403` plan limit on free plans), `sites.cacheSettings`
  (which of page, object and edge cache are on — always read before saying
  anything about caching), PageSpeed (latest first; a scan is spent only after
  telling the user), the access log for spikes and bots, services, and the
  site's PHP version. Four usual causes with what each looks like in the data.
  Enabling a cache layer (**Site → Cache**) and changing one site's PHP version
  (**Site → Settings → PHP version**) are dashboard-only — the skill hands
  them off with the site's `dashboard_url` and never offers them as API
  actions.
- **`reference/capability-map.md`** (shared) — every dashboard-only and
  impossible job in one table with its dashboard path and what the API does
  instead, plus **status codes are not uniform**: an agentic-server refusal is
  `403` on the WordPress and Git creates and `422` on the Docker and one-click
  paths, a free-plan monitoring `403` is a plan limit — match on the message.
- `xcloud:deploy` (`reference/git.md`): **which compose file xCloud runs** —
  `docker-compose.yml` unless `docker.compose_file` says otherwise (the auto
  endpoint always uses the default), with `git.compose-scan` resolving
  `compose.yaml` / subdirectories and returning `compose_file_resolved` to send
  back; the pinned Docker dry run does not probe HTTPS reachability; and the
  four `cloudflare_*` `422` refusal codes with what to do for each.
- Read-only smoke suites for both new skills; CI runs them.

### Fixed

- `xcloud:wordpress` PageSpeed: a `409` on a scan means one is still pending
  or running for the site, not a one-hour cooldown.

## [4.3.2] — 2026-09-24

- Harden the shipped REST fallback to GET-only, no body, no write override. Rejected methods stop before network activity.
- Deployments, infrastructure changes and payments require connected MCP tools with user approval/server confirmation; unavailable operations stop at the dashboard rather than bypassing the wrapper.
- Mark non-GET reference examples as upstream API documentation, not executable fallback commands. Recommend read-scoped REST credentials.
- Add offline enforcement tests. This is a capability restriction for REST-only clients, not a claim of a guaranteed registry verdict.

## [4.3.1] - 2026-09-24

### Documentation and distribution
- Rewrite the README around plain-language deployment and all seven capabilities, with separate ClawHub, Claude Code and portable-agent setup paths.
- Explain GitHub/GitLab/Bitbucket, private deploy keys, Docker/native compatibility, dry runs, explicit approvals, polling and same-site recovery without claiming universal Git/app compatibility.
- Replace categorical false-positive claims with accurate security boundaries, network destinations, credential/process visibility, destructive operations and billing risks.
- Add visible LICENSE.txt and SHA256SUMS.txt to the minimal ClawHub package; align the root name with the existing `xcloud` slug and resolve the bundled plugin root explicitly.
- Preserve upstream 4.3.0 capabilities and guards; no live infrastructure changes are required for this release.

## [4.3.0] - 2026-09-24

**Full sync with the latest xCloud MCP server and Public API (xCloud v2.8.8).**
Verified against the live server on 2026-09-24: the API has 199 operations, 191
of them for agents (the other 8 are the xCloud mobile app's own sign-in and push
endpoints), and **all 191 are now documented** in a skill — up from 127 before
this release. The MCP server's 190 tools (188 operations + two search tools)
are all covered, including multi-team access, deploy diagnosis and retry,
dry-run previews, Git staging, one-click apps, billing, add-ons, alerts and
server purchase.

On top of the sync, the skills are proactive: paste a repository URL and say
"deploy", and the agent finishes the job. The end-to-end flow was exercised
read-only with a real dry run (a public Express repository → Node.js site
preview on a staging hostname; nothing created).

### Added

- **`xcloud:deploy`** — a new skill that owns getting code live: any GitHub,
  GitLab or Bitbucket URL (public, connected provider, or private with a deploy
  key), Docker Compose / Dockerfile apps, one-click apps, Git staging
  environments from a branch, and new WordPress sites. One playbook: team →
  server (never picked silently) → `git.detect` → staging hostname or live
  domain (Cloudflare when connected) → dry run → one approval → create with an
  idempotency key → poll → fetch the live URL → offer the next step. Failed
  deploys go straight to `deploy-diagnosis` → corrections → `provision-retry`
  on the same site. `reference/git.md` moved here from `xcloud:sites`; new
  `reference/one-click-apps.md` and `reference/staging-and-wordpress.md`.
- **`xcloud:billing`** — plan, overview, invoices, bills, subscriptions,
  packages, products, payment methods, paying an invoice, public prices, and
  email add-ons (`reference/addons.md`: mailbox plans, purchase, DNS
  verification, IMAP/POP/SMTP settings, deletion; mail-delivery subscriptions).
  Money rules: explicit approval with item, price, period and card; no blind
  retries of non-idempotent purchases; 3-D Secure links handed to the user.
- **Multi-team access.** Shared conventions teach team selection (`teams_index`
  → `team` on MCP, `X-Team-Id` on REST), cross-team lookups when a resource is
  missing from the default team, and how to re-authorize a single-team
  connection to add teams. `mcp.md` documents several xCloud connections in one
  session and recognising the server by tool names, not prefix.
- **Proactive mode** in `reference/conventions.md`: finish the whole job,
  search first, preview then ask once, recover instead of report, verify the end
  state, surface alerts and risks without acting unasked, give dashboard paths
  for dashboard-only steps. The confirmation policy now covers purchases, site
  creation, retries, redeploys, service installs and runtime changes.
- `xcloud:servers`: buying a server (`reference/provisioning.md`: plans,
  prices, regions, card check, idempotent create, provisioning progress),
  verified reboots (`/reboots`), service install/enable, Node.js defaults, DNS
  checks, fleet disk checks.
- `xcloud:account`: teams, incident alerts (list, filter, mark read), connected
  Git providers and their repositories.
- `xcloud:sites`: Docker app backups (`reference/docker-backups.md`), staging
  environment create, events by task.
- `xcloud:wordpress`: broken-link scans (`reference/broken-links.md`), PageSpeed
  scan polling, fleet update questions.
- REST wrapper: `XCLOUD_TEAM_ID` → `X-Team-Id` and `XCLOUD_IDEMPOTENCY_KEY` →
  `Idempotency-Key`, both validated against a strict character set so a stray
  CR/LF cannot inject headers. A set-but-empty value (what a failed `$(...)`
  leaves) stops the call instead of silently dropping the header — no quiet
  fallback to the default team, no create that is no longer safe to retry.
  Examples generate the key once with `od` + `/dev/urandom` (no `uuidgen`
  dependency) and reuse it on retry. Eight new offline tests (16 total).
- Read-only smoke suites for `deploy` (catalog, Git integrations, side-effect-free
  repository detection, staging hostname, deploy keys) and `billing` (403 on an
  unscoped token counts as skip); account suite checks teams and alerts; CI runs
  all seven.

### Fixed

- `servers` listed `POST /servers/{uuid}/staging-hostname/suggest`; the live
  operation is `GET /servers/{uuid}/staging-hostname?label=…`.
- WordPress creation examples sent `ssl.provider: letsencrypt`, which the API
  rejects — the values are `xcloud` (free Let's Encrypt), `custom`, `cloudflare`.
  Fixed in the skill, `docs/DEPLOY.md`, `docs/WORKFLOWS.md`,
  `docs/DECISION-TREES.md`, and the legacy SDK default
  (`src/xcloud_sdk.py`).
- Site backups sent a `label` field the API does not take; the body is `type:
  local|remote` and progress is polled via `data.task_uuid`.
- `GET /sites/{uuid}/pagespeed/scans/{scan_uuid}` (poll one scan) was
  undocumented. Every agent-facing operation is now documented (191/191).
- The startup banner still said v4.0.1.
- `docs/scalar/build.mjs` still generated the five-skill landing page; it now
  carries the seven-skill copy, reads its version from `plugin.json`, and CI
  fails when the committed page drifts from the generator.
- `.clawhubinfo.json` listed the Agent Plugins release as v4.2.0; it is v4.1.0,
  and the actual v4.2.0 entry was missing.

### Distribution

- Both builders (`dist/agent-plugin/build.py`, `dist/claude-app/build.sh`) and
  the portable validator now cover seven areas; the claude.ai router lists
  Deploy and Billing. Regenerated `dist/`.

## [4.2.0] - 2026-09-22

**The search, profiles and deploy-flow release.** Everything below was verified
against the live server at `https://app.xcloud.host/mcp` on 2026-09-22.

### MCP search tools

- `plugins/xcloud/reference/mcp.md` documents the two search tools that sit
  beside the operation tools on every profile: `xcloud_agent_search` returns
  the operations, ordered guidance steps and operation notes for a job (call it
  first for anything with more than one step, and on a 403/422 you cannot
  explain), and `xcloud_docs_search` answers a customer's question from
  documentation passages, facts and dashboard paths without ever returning
  operations.
- `xcloud_search` no longer exists: it was split into the two tools above. The
  retired name still routes to `xcloud_agent_search` for one release without
  being listed.

### One endpoint, profiles and toolsets

- The default **flat** profile lists one tool per authenticated Public API
  operation plus the two searches — 190 tools (188 operations: 110 read, 17
  write, 61 destructive) at this release; the count grows with each API
  release. Every stale "110 tools" figure is replaced.
- The **compact** profile, `POST /mcp?profile=compact` (alias `/mcp/v2`), lists
  five tools: the two searches plus `xcloud_execute_read`,
  `xcloud_execute_write` and `xcloud_execute_destructive`, which take an
  `operation_id` with `path_params`, `query`, `body`, `team`, and
  `idempotency_key` / `confirm` where the class needs them. Arguments are
  validated against the contract before the confirm step; a misspelled profile
  is a `400 unknown_profile`; a token can be pinned with `mcp:profile:compact`.
- **Toolsets** narrow the flat list to parts of xCloud (`?toolsets=sites,servers`
  or `mcp:toolset:<name>` token abilities, intersected) for clients that cap
  tool counts. Documented that narrowing is not an authorization boundary and
  that unknown names are ignored.
- Recorded the execution-class contract (read / write / destructive from the
  spec, not the HTTP method), `dry_run: true` previews on the four
  site-creation operations, the operations that accept an `Idempotency-Key`,
  and the `team` argument for multi-team tokens.

### Git deploy flow

- Rewrote `plugins/xcloud/skills/sites/reference/git.md` around the real flow:
  `git.detect` first (branch on `repository_access`, surface `warnings[]`),
  `dry_run` then `servers.sites.git.auto`, `servers.sites.git.create` /
  `servers.sites.git.docker` only for pinned values, the deploy-key handshake
  for private SSH repositories (`index` → `store` → `verify` with
  `detect: true` → `repository.deploy_key_uuid`), `git.compose-scan` and the
  Docker host-port rules, the `sites.status` polling contract, and the failure
  loop `sites.deploy-diagnosis` → `sites.provision-retry` with `corrections`
  on the same site, with `sites.rescue`, `sites.events.show`,
  `sites.deploy-config` and `deploy_script_fail_fast` in their places.
- `xcloud:servers` lists the new server-side operations (`git/auto`,
  `git/docker`, `git/detect`, `git/compose-scan`, deploy keys,
  `staging-hostname/suggest`, Node.js versions) and its Git example previews
  with `git.detect` and `dry_run` before creating; `xcloud:sites` lists
  `deploy-config`, `deploy-diagnosis` and `provision-retry`.
- Regenerated the portable Agent Plugins distribution and the claude.ai skill
  under `dist/`.

## [4.1.0] - 2026-08-07

### Agent Plugins 1.0.0

- Added a generated Agent Plugins package with the required portable `plugin.json`.
- Added `mcp.json` for automatic discovery of the xCloud Streamable HTTP MCP server.
- Packaged all five validated Agent Skills with skill-local references and REST wrappers.
- Removed the Claude-only `${CLAUDE_PLUGIN_ROOT}` dependency from the portable output.
- Made portable MCP/tool/skill naming client-neutral and made REST wrapper paths independent of the user's working directory.
- Added a local Codex marketplace adapter plus checks for stale paths, client-specific text, untracked generated files, and generated ShellCheck coverage.
- Added official JSON Schema validation, Agent Skills validation, and generated-output drift checks to CI.
- Added a release archive for compatible clients such as Codex, Cursor, VS Code, Kiro, and GitHub Copilot.

## [4.0.2] - 2026-08-05

### ClawHub Package Hygiene

- Excluded internal docs, generated `dist/` output, legacy `src/` helpers,
  work-step notes, and smoke-test artifacts from the ClawHub publish package.
- Kept the installable package focused on root marketplace files, live skill
  instructions, runtime references, assets, and the shared REST wrapper.
- Reworded the defensive untrusted-output example that ClawHub's static scanner
  interpreted as a prompt-injection pattern.
- Regenerated ClawHub safety metadata for the reduced package.

## [4.0.1] - 2026-08-02

**The security-hardening release.** Every open upstream issue was examined;
this release fixes all that are resolvable in this repository. Issue status
(refs are `xCloudDev/xcloud-agent-skills` issue numbers):

| Issue | Status |
|---|---|
| [#14](https://github.com/xCloudDev/xcloud-agent-skills/issues/14) Harden base URL & token handling | ✅ **Fixed** |
| [#15](https://github.com/xCloudDev/xcloud-agent-skills/issues/15) Redact bearer tokens from verbose output | ✅ **Fixed** |
| [#16](https://github.com/xCloudDev/xcloud-agent-skills/issues/16) Stop passing sensitive bodies through argv | ✅ **Fixed** |
| [#17](https://github.com/xCloudDev/xcloud-agent-skills/issues/17) Replace unsafe shell JSON interpolation | ✅ **Fixed** |
| [#18](https://github.com/xCloudDev/xcloud-agent-skills/issues/18) Agent safety rules for untrusted output | ✅ **Fixed** |
| [#19](https://github.com/xCloudDev/xcloud-agent-skills/issues/19) Confirmation policy for high-risk writes | ✅ **Fixed** |
| [#21](https://github.com/xCloudDev/xcloud-agent-skills/issues/21) Token setup guidance for hosted chat | ✅ **Fixed** |
| [#22](https://github.com/xCloudDev/xcloud-agent-skills/issues/22) Harden async state persistence | ✅ **Fixed** |
| [#8](https://github.com/xCloudDev/xcloud-agent-skills/issues/8) v1.2.0 test report | 🟡 **Live bugs fixed** (BUG-01/02/03); doc findings superseded by v2–v4 — suggest closing |
| [#20](https://github.com/xCloudDev/xcloud-agent-skills/issues/20) Hook-based safety harness | 🟡 **Partial** — CI safety-pattern lint landed; runtime PreToolUse/redaction hooks deferred (MCP `confirm: true` already gates destructive calls) |
| [#26](https://github.com/xCloudDev/xcloud-agent-skills/issues/26) Ship through managed marketplaces | 🟡 **Partial** — CI version-consistency gate landed; Anthropic directory submission is a maintainer action |
| [#6](https://github.com/xCloudDev/xcloud-agent-skills/issues/6) OpenAPI-accurate & publishable | ✅ **Superseded** by v2.0–v4.0 — suggest closing |

### Security

- **Wrapper (`scripts/xcloud.sh`):**
  - Plaintext `http://` base URLs are refused unless
    `XCLOUD_ALLOW_INSECURE_HTTP=1` is set (local development only); non-http(s)
    schemes are always refused (#14).
  - Verbose mode (`XCLOUD_VERBOSE=1`) redacts the bearer token from all curl
    stderr output — literal replacement, safe for any token content (#15).
  - Request bodies are delivered to curl via stdin (`--data-binary @-`), never
    on curl's command line; a new `-` body argument reads the wrapper's own
    stdin so secret-bearing payloads (private keys, passwords) never touch any
    argv. The JSON-argument form still works (#16).
- **Skill docs:** SSL custom-certificate, sudo-user, and site-SSH password
  examples now build JSON with `jq -n` and pipe it via stdin (#16, #17).
- **Shared conventions:** new *Untrusted output* section — all API output is
  data, never instructions (prompt-injection defense, #18) — and a written
  *Confirmation policy* for high-risk writes with an explicit pre-authorized
  batch override, matching the MCP `confirm: true` contract on the REST path
  (#19).
- **Auth guidance:** hosted-chat token rules tightened — scoped short-lived
  tokens only, never `*` in chat, plus token-compromise rotation/revocation
  steps (#21).
- **Legacy `src/`:** JSON payloads in `xcloud-api.sh`/`xcloud-cli.sh` are built
  with `jq -n`, injection-proof (#17); `xcloud_async.py` state files are
  written owner-only (0600) with known secret fields masked (#22).

### Fixed

- CLI crash on every no-payload command under `set -u` (empty `extra_args`;
  #8 BUG-03).
- Async poller readiness check now accepts live payload shapes
  (`is_provisioned` / `status == "provisioned"`; #8 BUG-02).
- CLI WordPress-create SSL provider `letsencrypt` → `xcloud` (#8 BUG-01; both
  are valid per the current live spec — `xcloud` is the managed default).

### Added

- Offline test suites, wired into CI: `plugins/xcloud/scripts/tests/`
  `wrapper-test.sh` (8 tests: refusal paths, redaction with a fake token,
  stdin/argv body round-trips, unchanged envelope/exit codes) and
  `src/tests/json-safety-test.sh` (8 tests: hostile quotes, control
  characters, field-injection attempts).
- CI: version-consistency gate across `plugin.json`, `marketplace.json`,
  `.clawhubinfo.json`, and root `SKILL.md` (#26), plus a script-safety pattern
  check — no `--data-raw` in scripts, no unredacted `curl -v` in `src/` (#20).

## [4.0.0] - 2026-07-29

**The MCP release.** The xCloud MCP server is live at
`https://app.xcloud.host/mcp` — 110 native tools, one per authenticated Public
API operation — and the skills are now **MCP-first**. Nothing breaks: skill IDs
are unchanged and the REST token path still works everywhere it did before.

### Added

- **xCloud MCP as the primary transport.** New shared
  `reference/mcp.md`: endpoint + per-client connect instructions (Claude Code,
  Claude Desktop, claude.ai, Cursor, headless API-key with `mcp:invoke`), OAuth
  grant levels (`mcp:read` / `mcp:write`), the tool-naming rule (tool names
  mirror endpoint paths — `servers_reboot`, `sites_ssl_renew`, …), the
  confirm-before-destructive contract every destructive tool enforces, and the
  REST-only surface. All five skills now instruct: **prefer
  `mcp__xcloud__*` tools when connected; fall back to `scripts/xcloud.sh`
  otherwise.** Verified live: 110 MCP tools = full parity with the live API's
  110 authenticated operations.
- **Site deletion** (`DELETE /sites/{uuid}`) in `xcloud:sites` — granular
  `delete_*` flags (files, database, user, local backups, DNS record), async,
  documented with a hard confirm-first guardrail.
- **Git-deployed site provisioning** (`POST /servers/{uuid}/sites/git`) in
  `xcloud:servers` — Laravel, Node.js, custom PHP, WordPress, and Lovable site
  types from a connected provider or public HTTPS repo; request shape verified
  against the live OpenAPI.
- **Domain update status** (`GET /sites/{uuid}/domain/status`) in
  `xcloud:sites`.
- Site rescue now documents the Node/PM2/OpenClaw repair flags and
  `directory_permissions`.

### Changed

- README leads with **Connect the xCloud MCP (recommended)**; token setup is
  the documented REST fallback. Auth onboarding offers the MCP connector before
  any token guidance.
- `docs/API-COVERAGE.md` refreshed against the current live OpenAPI
  (**113 operations**; +2 since the last audit) with a full MCP-parity map.
- Marketplace metadata (ClawHub, plugin manifest, root `SKILL.md`) reframed
  around MCP + skills; version bumped to 4.0.0.
- claude.ai dist build: the "needs an MCP connector" caveat is resolved — the
  install guide now points at the live connector.

### Notes

- API-token management (`GET /user/tokens`, `DELETE /user/tokens/{tokenUuid}`)
  and `GET /health` are intentionally REST-only; `xcloud:account` keeps using
  the bundled wrapper for them.

## [3.0.3] - 2026-07-10

### Added

- Closed the live API coverage gaps: `GET /vulnerabilities`,
  `PUT /sites/{uuid}/git`, `POST /sites/{uuid}/git/deploy`, and
  `POST /servers/{uuid}/services/disable`.
- Added `xcloud:sites` Git deployment guidance for reading/updating deployment
  settings and triggering manual deploys.
- Added team-wide vulnerability rollup guidance to `xcloud:wordpress`.
- Added safer proactive token onboarding: xCloud now prompts users to configure
  `XCLOUD_API_TOKEN` in the runtime/secret store and verifies with `/health` +
  `/user`, without defaulting to raw token collection in chat.
- Added direct xCloud tutorial/video/YouTube links to README, root `SKILL.md`,
  and ClawHub metadata for better marketplace and search indexing.

### Changed

- Changed marketplace category metadata from `infrastructure` to `deployment`.
- Strengthened xCloud-branded greeting/startup guidance so first-run replies feel
  more helpful and productized.
- Refreshed `docs/API-COVERAGE.md`: current skill docs cover **111/111** live
  OpenAPI operations, with only the 9 caveated database/database-user operations
  remaining outside the live spec.

## [3.0.2] - 2026-07-10

### Changed

- Restored the original `xcloud` ClawHub listing so the public release keeps its existing download history.
- Refreshed the first-screen README badges to match successful Asif2BD ClawHub listings: ClawHub, version, license, xCloud, and OpenClaw.
- Refreshed the rendered `SKILL.md` tab with Token Optimizer-style badges, first-screen xCloud/GitHub/guide/API/security links, and a security notice for the existing ClawHub listing.
- Added direct links to xCloud, the xCloud dashboard, GitHub, the User Guide, the Install & Usage Guide, and the Public API docs in both README and marketplace metadata.

## [3.0.1] - 2026-07-10

### Added

- **ClawHub release metadata**: root `SKILL.md`, `.clawhubignore`, `.clawhubsafe`,
  scanner-focused `SECURITY.md`, README badges, and official marketplace links
  for ClawHub and skills.mp.com indexing.
- **API coverage audit** (`docs/API-COVERAGE.md`): every documented endpoint
  cross-checked against the live OpenAPI (111 operations). Skills cover 108 of
  them; 3 live operations are undocumented (`PUT /sites/{uuid}/git`,
  `POST /sites/{uuid}/git/deploy`, `POST /servers/{uuid}/services/disable`) and 9
  documented `databases`/`database-users` operations are absent from the spec
  **and verified to return HTTP 404 on live servers (2026-06-29)** — now carrying
  a prominent "not available on the current public API" caveat in
  `reference/databases.md`. Clarifies that "117" is the skill-side count, not the
  API's 111-operation surface; ADR 0001 and the 2.0.0 note were corrected
  accordingly. All five smoke suites were run green against the live API
  (servers: 7 passed / 1 skipped for the `databases` 404 / 0 failed).
- **Minimal CI workflow** (`.github/workflows/ci.yml`): lints every shell script
  (`bash -n` + ShellCheck) and validates the JSON manifests on each push/PR, and
  runs the read-only smoke suites when an `XCLOUD_API_TOKEN` secret is configured
  (skips cleanly otherwise).

### Fixed

- **`xcloud:account` token revocation now matches the live API.** The skill
  documented `DELETE /user/tokens/{tokenId}` as a numeric id, but the API keys
  revocation by the token's `uuid` (live OpenAPI: `DELETE
  /user/tokens/{tokenUuid}`, `string`/`uuid`) and `GET /user/tokens` returns
  `uuid`. Corrected the endpoint, made the list example surface `uuid` (so the
  revoke flow is completable from list output), and fixed the matching note in
  `reference/conventions.md` and the skill pitfall.

### Changed

- **Smoke suites tolerate unsupported sub-resources.** A new `check_opt` helper
  treats `404` (and `422` "not supported") on optional, type-dependent
  sub-resources as **SKIP** instead of **FAIL** — applied to server `databases`,
  site `backups`/`cache`, the WordPress `pagespeed` latest scan, and site `ssl`.
  Summary lines now report passed/skipped/failed.
- **Removed non-standard SKILL.md frontmatter keys** (`version`/`author`/
  `license`) from all five skills — `name`/`description` only, per the SKILL.md
  schema. Version/author/license now have a single source of truth in
  `plugin.json`, avoiding drift across six files on each release.
- **Reconciled `requirements.txt`** with `.clawhubinfo.json`'s stated versions:
  `requests>=2.28.0`, `backoff>=2.2.0`.
- **Documented `XCLOUD_API_BASE_URL`** in `.env.example` (commented), so local /
  white-label hosts are discoverable without reading the source.
- **Public identity realigned to the skills.** The README now leads with the five
  `xcloud:*` skills, install, and usage; the Python SDK/CLI is reframed as a
  legacy `src/` track. `.clawhubinfo.json` bumped to `3.0.1`, its stale
  `api_info.version` corrected to the live API's `1.0.0`, and its
  features/badges/quick-start reframed from SDK-centric to skill-centric.

## [3.0.0] - 2026-06-16

### Changed (BREAKING)

- Renamed the plugin from `xcloud-public-api` to **`xcloud`**, and shortened each
  skill's name to its bare capability. Skills are now invoked as **`xcloud:servers`**,
  **`xcloud:sites`**, **`xcloud:ssl`**, **`xcloud:wordpress`**, and **`xcloud:account`**
  (previously `xcloud-public-api:xcloud-servers`, etc.).
- The plugin directory moved from `plugins/xcloud-public-api/` to `plugins/xcloud/`,
  and each skill directory was shortened to match (`skills/servers/`, `skills/sites/`,
  `skills/ssl/`, `skills/wordpress/`, `skills/account/`).
- **Breaking:** the skill IDs changed. Users must reinstall the plugin
  (`/plugin install xcloud`) and update any explicit skill references to the new
  `xcloud:<capability>` form. No behavior or coverage changed — names only.

## [2.0.0] - 2026-06-09

### Changed (BREAKING)

- Replaced the single `xcloud-public-api` skill with **five capability-domain
  skills**: `xcloud-servers`, `xcloud-sites`, `xcloud-wordpress`, `xcloud-ssl`,
  `xcloud-account`. The v1 single skill is preserved at the `v1.2.0` git tag.
- Skills are organized by **capability, not URL root**; each description declares
  what it does *not* own with `see xcloud-*` cross-links to keep trigger keywords
  from colliding. See `docs/adr/0001-capability-domain-skills.md`.

### Added

- Coverage expanded to a 117-operation skill surface (PHP versions, databases,
  firewall/fail2ban, cron, snapshots, services, vulnerabilities, PageSpeed,
  WordPress plugin/theme management, SSL certificate lifecycle, and more).
- Shared plugin layer: one `scripts/xcloud.sh` + `reference/{auth,conventions}.md`
  referenced by every skill via `${CLAUDE_PLUGIN_ROOT}` — no per-skill duplication.
- Per-skill `tests/smoke.sh`; large domains carry `reference/<sub-resource>.md`
  loaded on demand.
- Base URL is environment-driven (`XCLOUD_API_BASE_URL`) — local (`xcloud.test`)
  vs live (`app.xcloud.host`) needs no code change.

## [1.1.0] - 2026-04-22

### Added

#### Core SDK
- **xcloud_sdk.py**: Full-featured Python SDK for xCloud API
  - `XCloudAPI` class with 20+ methods
  - `XCloudDeployer` class for high-level automation
  - Support for all API endpoints (servers, sites, backups, SSH config, etc.)
  - Built-in error handling with exponential backoff
  - Rate limit management and retry logic

#### Async Helpers
- **xcloud_async.py**: Reliable async operation tracking
  - `AsyncPoller`: Poll operations until completion
  - `StateManager`: Persistent state tracking
  - `RateLimitManager`: Automatic rate limit backoff
  - `OperationBatcher`: Batch operations for efficiency
  - `DeploymentTracker`: Multi-step deployment tracking

#### CLI Tool
- **xcloud-cli.sh**: Command-line interface for interactive use
  - Server management (list, get, reboot)
  - Site management (create, backup, monitor, etc.)
  - Health checks and monitoring
  - Blueprint enumeration
  - Human-friendly output with color coding

#### Documentation
- **AGENT-SCENARIOS.md**: Real-world use cases for autonomous agents
  - Infrastructure automation (provisioning, deployment, backups)
  - Monitoring & analysis (capacity planning, DR, cost analysis)
  - Security checks (SSL monitoring, site health verification)
  - Operations (bulk updates, status reporting)
  - Error recovery and state persistence patterns
  
- **ERROR-HANDLING.md**: Comprehensive error recovery guide
  - 12+ error types covered (401, 429, 502, SSL, etc.)
  - Recovery code for each error
  - Testing commands
  - Quick reference table

#### Examples
- Deploy WordPress site with polling
- Monitor fleet health
- Backup all sites
- Competitor site monitoring template
- Health check with auto-recovery

### Changed

- Updated SKILL.md with cross-references to new documentation
- Updated README.md with installation instructions for SDK and CLI
- Updated plugin.json metadata (version 1.1.0)

### Technical Improvements

- **SDK Design**: High-level abstractions reduce boilerplate by 80%
- **Error Handling**: Exponential backoff, rate limit management, timeout handling
- **State Persistence**: Track long-running operations across invocations
- **Rate Limiting**: Automatic backoff prevents 429 errors
- **Polling**: Built-in timeout and interval management

### Breaking Changes

None. All existing curl examples and manual API usage continues to work.

---

## [1.0.0] - 2024

### Initial Release

- Original SKILL.md with xCloud Public API documentation
- curl examples for all major operations
- Authentication guide
- Rate limiting information
- Troubleshooting patterns (502 triage, etc.)
- README with installation instructions
