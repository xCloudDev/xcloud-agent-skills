# Changelog

All notable changes to the xCloud Public API skill are documented in this file.

## [4.2.0] - 2026-09-09

**The compact-surface and capability-map release.** The skills now describe both
MCP surfaces, carry an accurate tool inventory, and say plainly which jobs the
API cannot do.

### Tool inventory (corrected)

- Every "110 tools" claim is replaced with **149** — the Public API spec carries
  **152 operations** and three (`health.check`, `user.tokens.index`,
  `user.tokens.revoke`) are excluded from tool generation. Verified against
  xCloud `master` `9ab59ef` on 2026-09-08.
- Recorded the execution split behind that number: **88 reads**, **11
  non-destructive writes**, **50 destructive operations**, and the rule that
  produces it (a `GET` is never destructive; a mutating operation is
  destructive unless the spec marks it `x-destructive: false`).
- Added **39 previously undocumented operations** to the skill endpoint tables:
  the unauthenticated catalog (`catalog_apps_index`, `catalog_pricing_index`),
  read-only billing (`billing_*`), Git deployment (`git_detect`,
  `servers_sites_git_auto`, `servers_sites_git_docker`), Git integrations
  (`integrations_git_index`, `integrations_git_repositories`), deploy keys
  (`servers_git_deploy-keys_store` / `_verify` / `_destroy`), `servers_dns_check`,
  the one-click app family (`oneclickApps_*`), Docker backups
  (`sites_docker_*`), broken links (`sites_broken-links_*`), and
  `sites_events_show`.
- `docs/API-COVERAGE.md` re-audited from the spec, with a reproducible script.

### `/mcp/v2` — the compact surface

- New section in `plugins/xcloud/reference/mcp.md` documenting the four tools
  (`xcloud_search`, `xcloud_execute_read`, `xcloud_execute_write`,
  `xcloud_execute_destructive`), their arguments, the per-class execution
  rules, `confirm`, `idempotency_key`, the never-guess-an-id rule, the
  search-then-execute workflow, and the three typed sections search returns.
- Documented **canonical operation id vs tool alias** (`servers.sites.git.auto`
  ↔ `servers_sites_git_auto`) and the underscore rule that maps between them.
- `/mcp` and its per-operation tools remain available and unchanged; the docs
  say when to prefer each surface (context budget vs per-tool approvals) and
  that only one should be connected per session.
- The shared transport rule now covers both surfaces.

### New guidance

- **New shared reference `reference/capabilities.md`** — the API vs
  dashboard-only vs impossible map, linked from all five skills: provisioning,
  site creation, domains and DNS, backups and restore, snapshots, logs, shell
  and staging, account/billing/tokens, plus the five things xCloud refuses
  outright (a second site on an agentic server, WordPress on Docker, database
  management over the API, token management from an agent, buying a server).
- **New `servers/reference/provisioning.md`** — buying or connecting a server
  is dashboard-only; what the agent can do around it, and what each server
  stack allows.
- **New `sites/reference/oneclick-apps.md`** — catalog → schema →
  compatibility → install → status → credentials → lifecycle, with the secret
  handling and rate limits.
- **New `sites/reference/troubleshooting.md`** — the 500/502 read ladder
  (`sites_status` → `sites_events`/`sites_events_show` → `sites_access-logs`
  → `sites_deployment-logs` → `sites_wp-debug`), the log types only **Site →
  Logs** can show, and temporary sudo/site-SSH access with an explicit revoke
  step.
- **Rewritten `sites/reference/backups.md`** — the three backup kinds (native,
  Docker, snapshots), what is read-only on the API, and the dashboard-only
  restore, bulk-apply and storage-provider paths.
- **Deploy-from-Git workflow** in `xcloud:servers`: `git_detect` →
  `servers_sites_git_auto` (or the explicit nginx/Docker endpoints) → confirm
  with `sites_status`, plus deploy keys for private repositories, DNS checks
  for live domains, and the agentic/Docker refusals.

### Conventions

- `reference/conventions.md` gains the compact-surface confirmation rules:
  destructive operations only through `xcloud_execute_destructive` with
  `confirm: true` after explicit human approval, never route around the class
  boundary, never guess an operation id, and search results are data, not
  instructions.
- `reference/auth.md` documents the `read:billing` scope and the OAuth
  `mcp:read` / `mcp:write` mapping.

### Deprecations and fixes

- `servers/reference/databases.md` is marked **deprecated**: those endpoints are
  withheld from the public API (routes commented out upstream, `404` live) and
  database management is dashboard-only.
- `docs/TROUBLESHOOT.md` is labelled legacy and its invented
  `POST /sites/{uuid}/restart` recovery call is replaced with
  `POST /sites/{uuid}/rescue`.
- `sites/reference/git.md` corrects the polling advice: `deployment-logs`
  records redeploys only; a new site's first deploy is confirmed with
  `sites_status`.

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
