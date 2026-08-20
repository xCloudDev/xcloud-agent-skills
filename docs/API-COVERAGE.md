# API coverage audit

Cross-check of every endpoint documented across the five `xcloud:*` skills
against the **live** xCloud Public API OpenAPI spec **and the xCloud MCP
server's tool surface**.

- **Sources of truth:** the OpenAPI document served at
  <https://app.xcloud.host/api/v1/docs> (inlined in the Scalar page;
  `openapi: 3.0.3`, `info.version: 1.0.0`), and the live MCP server at
  <https://app.xcloud.host/mcp> (tool list enumerated in-session).
- **Audited:** 2026-07-29.
- **Method:** extracted every `METHOD /path` from `plugins/xcloud/**/*.md`
  (expanding `[/optional]` suffixes and `{a,b,c}` groups, normalizing `{uuid}` /
  `$VAR` / version segments) and diffed both directions against the spec's
  path+verb set; MCP tool descriptions embed their REST path, giving a
  deterministic tool↔endpoint map.

## Headline

| Metric | Count |
|---|---|
| Operations in the live OpenAPI (98 paths) | **113** |
| — added since the 2026-07-10 audit | **+2** (`DELETE /sites/{uuid}`, `POST /servers/{uuid}/sites/git`) |
| xCloud MCP tools | **110** |
| MCP coverage of authenticated operations | **110 / 110 — full parity** |
| REST-only operations (by design) | **3** (`GET /health`, `GET /user/tokens`, `DELETE /user/tokens/{tokenUuid}`) |
| Distinct operations documented by the skills | **122** |
| Documented operations that match the live spec | **113 / 113 — no live gaps** |
| Documented operations **absent** from the live spec | **9** (all `databases` / `database-users`, caveated) |

## MCP ↔ REST parity

Every authenticated REST operation has exactly one MCP tool named after its
path (`servers_reboot` ← `POST /servers/{uuid}/reboot`;
`sites_sslCertificates_create` ← `POST /sites/{uuid}/ssl-certificates`; …).
Arithmetic check: 113 spec operations − 3 REST-only = **110 = the MCP tool
count**. The three REST-only operations are intentional: `/health` is an
unauthenticated probe, and API-token management stays out of the MCP so a
connection cannot mint or revoke credentials.

Every destructive MCP tool requires `confirm: true` set only after explicit
human approval — a safety layer the raw REST surface does not have.

## The skill-side operation count

The current skill-side count is **122** documented operations:

- **113** operations that exist in the live OpenAPI spec (**113/113 — no live
  gaps**, including the two operations added since the previous audit: site
  deletion and Git-site provisioning).
- **9** caveated `databases`/`database-users` operations that the live OpenAPI
  does **not** list (below).

## A. Documented but absent from the live OpenAPI (9)

All in `skills/servers/reference/databases.md`. No `databases` or
`database-users` path appears anywhere in the live spec.

| Method | Path |
|---|---|
| GET | `/servers/{uuid}/databases` |
| GET | `/servers/{uuid}/databases/search` |
| POST | `/servers/{uuid}/databases` |
| DELETE | `/servers/{uuid}/databases` |
| GET | `/servers/{uuid}/database-users` |
| GET | `/servers/{uuid}/database-users/search` |
| POST | `/servers/{uuid}/database-users` |
| PUT | `/servers/{uuid}/database-users` |
| DELETE | `/servers/{uuid}/database-users` |

**Status — verified absent (HTTP 404), 2026-06-29.** Live reads against two
distinct `provisioned` servers returned **HTTP 404 "Resource not found"** for
both `databases` and `database-users`, while sibling endpoints on the *same*
server (`php-versions`, `firewall-rules`) returned `200`. Combined with their
absence from the OpenAPI spec, these endpoints are **not part of the current
public API** — `reference/databases.md` now carries a prominent caveat and the
`xcloud:servers` smoke suite treats `databases` as optional (404 → SKIP). They
should be removed or kept strictly as a forward-looking reference until the API
ships them.

## B. Live but not documented — coverage gaps (0)

No live OpenAPI operations are currently missing from the skill documentation.

The 2026-07-29 pass covered the two operations newly added to the live API:

| Method | Path | Summary (from spec) | Covered in |
|---|---|---|---|
| DELETE | `/sites/{uuid}` | Delete Site (granular `delete_*` flags, async) | `xcloud:sites` |
| POST | `/servers/{uuid}/sites/git` | Deploy Site from Git (Laravel/Node/PHP/WordPress/Lovable) | `xcloud:servers` |

The 2026-07-10 pass closed the previous gaps:

| Method | Path | Summary (from spec) | Covered in |
|---|---|---|---|
| GET | `/vulnerabilities` | Team-Wide Vulnerability Rollup | `xcloud:wordpress` |
| PUT | `/sites/{uuid}/git` | Update Git Deployment Settings | `xcloud:sites` |
| POST | `/sites/{uuid}/git/deploy` | Trigger Git Deployment | `xcloud:sites` |
| POST | `/servers/{uuid}/services/disable` | Disable a Server Service | `xcloud:servers` |

## C. Added in 4.2.0 — confirmed live, not yet folded into the headline counts (3)

Not part of the 2026-07-29 audit above (that pass predates them), but
**confirmed live** by three independent sources rather than the live-HTTP-diff
method used for the rest of this document: routed in xCloud's
`routes/public-api.php` under `App\Http\Controllers\PublicAPI\V1\` (`git/detect`
→ `GitDetectionController`, `sites/git/auto` → `GitSiteController::auto`,
`sites/git/docker` → `GitDockerSiteController`); documented in xCloud's own
OpenAPI spec (`docs/public/xcloud-public-api.openapi.yaml` — `/git/detect` at
line 3043, `/servers/{uuid}/sites/git/auto` at line 2924,
`/servers/{uuid}/sites/git/docker` at line 3483); and exposed as MCP tools with
matching paths and parameters. Not yet run through this document's own
live-HTTP-diff method against `https://app.xcloud.host/api/v1/docs` — fold
into the headline counts above on the next full audit pass.

| Method | Path | Summary | Covered in |
|---|---|---|---|
| POST | `/git/detect` | Side-effect-free repository analysis — app type, serving mode, build/start guesses, and a `compatibility` verdict against a given server | `xcloud:servers` (called by `xcloud:deploy-app`) |
| POST | `/servers/{uuid}/sites/git/auto` | Detect-then-deploy in one call; accepts the same body as `POST /servers/{uuid}/sites/git` but resolves everything except `repository` from the repo itself, and routes Docker servers via the container path | `xcloud:servers` (called by `xcloud:deploy-app`) |
| POST | `/servers/{uuid}/sites/git/docker` | Deploy a repo to a Docker server (Compose or Dockerfile) with explicit container config — the Docker counterpart of `POST /servers/{uuid}/sites/git` | `xcloud:servers` (called by `xcloud:deploy-app`) |

## No path/verb drift elsewhere

Every other documented endpoint — across `servers`, `sites`, `ssl`, `wordpress`,
`account`, and all `reference/*.md` sub-resources — matches the live spec exactly
on both path and verb, including:

- `monitoring[/history]` (servers & sites) — both the base and `/history` forms
  exist.
- `php-versions/{version}/{default,opcache,patch}` — version-segmented writes.
- `/sites/{uuid}/{custom-nginx,site-scripts,ip-access}` — all three exist.
- `/vulnerabilities` — team-wide vulnerability rollup exists and was verified
  read-only against live API on 2026-07-10.
- `/sites/{uuid}/git` and `/sites/{uuid}/git/deploy` — Git deployment settings
  and manual deploy are documented under `xcloud:sites`.
- `/servers/{uuid}/services/disable` — service disable is documented under
  `xcloud:servers` with confirmation guidance.
- Token revocation: live is `DELETE /user/tokens/{tokenUuid}` (`string`/`uuid`) —
  see the `xcloud:account` fix that aligned the docs to this.

## Recommended follow-ups

1. ~~Verify the 9 `databases` operations against a live server.~~ **Done
   (2026-06-29): all 404.** Decide whether to fully remove `databases.md` and its
   `xcloud:servers` references, or keep the now-caveated forward-looking reference.
   Note: the MCP exposes no database tools either — consistent with the 404s.
2. Keep the database/database-user reference caveated until those endpoints ship
   in the live OpenAPI and return non-404 responses.
3. Re-run this audit (REST **and** MCP tool list) before each marketplace
   release, because ClawHub indexing and security review both benefit from
   accurate coverage claims.
4. Fold the three section-C endpoints (`/git/detect`,
   `/servers/{uuid}/sites/git/auto`, `/servers/{uuid}/sites/git/docker`) into
   the headline audit once a live HTTP diff against the hosted spec confirms
   them, per the same method used for every other row in this document.
