# API coverage audit

Cross-check of every endpoint documented across the five `xcloud:*` skills
against the xCloud Public API OpenAPI spec **and the xCloud MCP server's tool
surface**.

- **Sources of truth:** `docs/public/xcloud-public-api.openapi.yaml` in the
  xCloud application repository (the file the MCP server generates its tools
  from), and the MCP registration loop in `app/Mcp/Servers/XCloudServer.php`.
- **Audited:** 2026-09-08, against xCloud `master` `9ab59ef`.
- **Method:** parsed every `paths.<path>.<method>.operationId` out of the spec,
  derived each tool alias with the server's own rule (every character outside
  `[A-Za-z0-9_-]` → `_`), removed the three operations excluded from tool
  generation, and diffed that set against every `METHOD /path` and tool name
  cited in `plugins/xcloud/**/*.md`.

## Headline

| Metric | Count |
|---|---|
| Operations in the spec | **152** |
| Excluded from MCP tool generation | **3** (`health.check`, `user.tokens.index`, `user.tokens.revoke`) |
| **xCloud MCP tools (`/mcp`)** | **149** |
| — reads (`GET`) | **88** |
| — non-destructive writes | **11** |
| — destructive operations | **50** |
| Tools on the compact surface (`/mcp/v2`) | **4**, reaching the same 149 operations |
| Operations documented by the skills | **149 / 149** |
| Documented operations absent from the spec | **9** (all `databases` / `database-users`, now marked deprecated) |

The previous audit (2026-07-29) reported 113 spec operations and 110 tools. The
API has grown by 39 operations since; the "110 tools" claim was stale
everywhere it appeared and is corrected in this release.

## MCP ↔ REST parity

Every eligible REST operation has exactly one generated tool. The tool name is
the **alias** of the spec's `operationId`; the `operationId` itself, written
with dots, is the **canonical id** the `/mcp/v2` executors accept:

```text
operationId  servers.sites.git.auto    canonical id
tool name    servers_sites_git_auto    alias
REST         POST /servers/{uuid}/sites/git/auto
```

Arithmetic check: 152 spec operations − 3 excluded = **149 = the generated tool
count**. The three exclusions are intentional: `/health` is an unauthenticated
probe, and API-token management stays out of MCP so a connection cannot mint or
revoke credentials (it is additionally gated behind a full-access `*` token).

**Execution classes.** A `GET` is always a read. A mutating operation is
destructive unless the spec marks it `x-destructive: false`. The eleven
explicitly non-destructive writes are `git.detect`, `servers.dns.check`,
`servers.git.deploy-keys.store`, `servers.git.deploy-keys.verify`,
`sites.backup`, `sites.docker.backup`, `sites.cache.purge`,
`sites.cache.purge-all`, `sites.pagespeed.scan`, `sites.vulnerability-scan`,
`sites.wordpress.refresh`. Two operations carry an explicit
`x-destructive: true`: `servers.git.deploy-keys.destroy` and
`sites.docker.backup.destroy`.

A read-only token or an `mcp:read` OAuth grant sees only the 88 reads, on both
surfaces.

## Operations added to the skills in v4.2.0 (39)

Previously undocumented, now covered:

| Area | Operations | Documented in |
|---|---|---|
| Catalog (unauthenticated) | `catalog.apps.index`, `catalog.pricing.index` | `xcloud:account`, `xcloud:servers` (`reference/provisioning.md`) |
| Billing (read-only, `read:billing`) | `billing.plan`, `billing.overview`, `billing.bills.index`, `billing.bills.show`, `billing.invoices.index`, `billing.invoices.show`, `billing.packages.index`, `billing.products.index`, `billing.subscriptions.index`, `billing.payment-methods.index` | `xcloud:account` |
| Git deployment | `git.detect`, `servers.sites.git.auto`, `servers.sites.git.docker` | `xcloud:servers` |
| Git integrations | `integrations.git.index`, `integrations.git.repositories` | `xcloud:account` |
| Deploy keys | `servers.git.deploy-keys.store`, `servers.git.deploy-keys.verify`, `servers.git.deploy-keys.destroy` | `xcloud:servers` |
| DNS | `servers.dns.check` | `xcloud:servers` |
| One-click apps | `oneclickApps.index`, `oneclickApps.show`, `oneclickApps.compatibility`, `oneclickApps.install`, `oneclickApps.status`, `oneclickApps.credentials`, `oneclickApps.lifecycle` | `xcloud:sites` (`reference/oneclick-apps.md`), `xcloud:servers` |
| Docker backups | `sites.docker.backup`, `sites.docker.backups`, `sites.docker.backup.show`, `sites.docker.backup.destroy`, `sites.docker.backupCount`, `sites.docker.backupSettings`, `sites.docker.backupSettings.update` | `xcloud:sites` (`reference/backups.md`) |
| Broken links | `sites.broken-links.index`, `sites.broken-links.show`, `sites.broken-links.scan` | `xcloud:wordpress` |
| Deploy diagnostics | `sites.events.show` | `xcloud:sites` (`reference/troubleshooting.md`) |

Three operations that the previous audit counted as covered were cited only
through collapsed path notation (`monitoring[/history]`,
`{custom-nginx,site-scripts,ip-access}`); they are now listed one per row with
their tool names.

## Documented but absent from the spec (9) — deprecated

All in `plugins/xcloud/skills/servers/reference/databases.md`. No `databases`
or `database-users` path appears in the spec, the routes are present but
commented out in xCloud's `routes/public-api.php` ("TEMPORARILY HIDDEN"), and
live calls return `404` while sibling endpoints on the same server return
`200`. The file is now marked **deprecated** and points at the dashboard
(**Server → Database**) instead. It is kept, not deleted, as a record of the
endpoint shapes for the day they ship.

## Live but not documented — coverage gaps (0)

None. Every operation in the spec is either documented by a skill or one of the
three REST-only operations, which are documented as REST-only in
`plugins/xcloud/reference/mcp.md` and `xcloud:account`.

## Re-running this audit

From a checkout of the xCloud application repository:

```bash
python3 - <<'PY'
import yaml, re
spec = yaml.safe_load(open('docs/public/xcloud-public-api.openapi.yaml'))
excluded = {'health.check', 'user.tokens.index', 'user.tokens.revoke'}
for path, item in spec['paths'].items():
    for method, op in item.items():
        if method not in ('get', 'post', 'put', 'patch', 'delete'):
            continue
        oid = op['operationId']
        alias = re.sub(r'[^A-Za-z0-9_-]', '_', oid)
        cls = ('read' if method == 'get'
               else 'write' if op.get('x-destructive') is False
               else 'destructive')
        print(f"{alias}\t{oid}\t{method.upper()} {path}\t{cls}"
              f"\t{'EXCLUDED' if oid in excluded else ''}")
PY
```

Re-run it before each marketplace release: ClawHub indexing and security review
both depend on accurate coverage claims, and the tool count moves whenever the
spec does.
