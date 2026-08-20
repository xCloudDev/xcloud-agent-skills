# Make `xcloud:deploy-app` an orchestrator over the existing Public API, not a second deployment engine

**Status:** accepted

[Issue #34](https://github.com/xCloudDev/xcloud-agent-skills/issues/34) proposed
a sixth skill so an agent in Lovable, Replit, or another coding panel could
handle "deploy this application to xCloud." Two independent reviews of that
plan converged on the same finding before any code was written: the plan
duplicated capabilities the Public API already ships, and rested on one
incorrect premise. [Issue #35](https://github.com/xCloudDev/xcloud-agent-skills/issues/35)
records the merged revision this ADR implements.

## Decision

`xcloud:deploy-app` calls `POST /git/detect`, `POST
/servers/{uuid}/sites/git/auto`, and `POST /servers/{uuid}/sites/git/docker`
rather than reimplementing framework/build/port detection or a
native-vs-Docker routing table client-side. It owns only what those endpoints
cannot see: the local working tree, the Git handoff, and secret
classification.

## What #34 got wrong

- **`.xcloud/.xcloud-config.yaml` is not a customer-repository contract.** It
  is the OneClick catalog template manifest (category, icon, generated
  credentials, post-install messages) consumed by the curated
  `xCloudDev/app-templates` catalog. The Git-Docker deploy path reads
  `git_info.compose_file` from site metadata and writes its own compose file
  server-side — it never reads a repository-committed `.xcloud-config.yaml`.
  Placing that manifest into an ordinary customer repository would have been
  the new, competing format the issue said to avoid.
- **The capability gate it asked to audit already exists.** `git/auto` already
  performs detect-then-deploy and already routes Dockerfile/Compose
  repositories on Docker servers (`compatibility.docker_deployable` /
  `deploy_via: docker_compose`). `git/detect` already returns the routing
  verdict (`repository_access.status`, `detection.supported`,
  `compatibility`) that the issue proposed writing as a client-side decision
  table. No new Public API operation was required.
- **`lovable` needed no separate audit.** In the xCloud application,
  `GitSiteMigrationJob` treats `isNodejs()` and `isLovable()` as one branch;
  the only divergence is that `lovable` suppresses xCloud's provisioned
  database. The rule is fixed, not an open research question:
  `reference/site-type.md`.
- **The plan's own out-of-scope line ("no duplicate deployment engines") was
  violated by its own body**, which specified client-side detection and a
  Lovable routing table.

## What #34 got right, and is preserved

- MCP OAuth as the default first-run connection path.
- The requirement that live deployment, secret submission, and destructive
  operations get explicit confirmation naming the target.
- Reuse-before-generate for Docker/Compose files, and the constraint list for
  any generated stack (private DB ports, named volumes, working health
  checks, no committed secrets, immutable tags).

## What #34 was missing, and is added here

- **The repository synchronization gate**
  (`plugins/xcloud/skills/deploy-app/reference/repo-sync.md`). MCP deploys
  from a Git repository, not from uncommitted files in a coding panel. None of
  #34's five phases addressed the handoff from an open Lovable/Replit
  workspace into a repository xCloud can read — this is the most likely
  failure point for the literal request "deploy the application currently
  open," and it now runs before detection, not implied inside another step.
- **The secrets contract**
  (`plugins/xcloud/skills/deploy-app/reference/secrets.md`). `env_file_content`
  makes bulk-forwarding a local `.env` easy, which is exactly why the skill
  states what may be forwarded (values the user supplies this turn) versus
  what must not be (an automatic `.env` dump), rather than defaulting to
  convenience.

## Consequences

- `xcloud:servers` gains three documented endpoints
  (`docs/API-COVERAGE.md`) it already implicitly covered through
  `POST /servers/{uuid}/sites/git`; `xcloud:deploy-app` calls them and is
  documented as a caller, not an owner — consistent with
  [ADR 0001](0001-capability-domain-skills.md)'s rule that cross-links are
  load-bearing.
- Docker/Compose **generation** (as opposed to reuse of an existing file) and
  Lovable/Replit platform adapters are deliberately out of this change — they
  are Phase 3/4 in issue #35, gated on Phase 1's one genuine open question:
  verifying skill installation and remote MCP OAuth inside the real Lovable
  and Replit products.
