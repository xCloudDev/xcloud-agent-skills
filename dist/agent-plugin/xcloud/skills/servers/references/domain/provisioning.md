# Getting a server (and what the agent can and cannot do)

`XC="$SKILL_ROOT/scripts/xcloud.sh"` · MCP tools first.

**Buying an xCloud-managed server, or connecting your own cloud provider, is
dashboard-only.** There is no Public API or MCP operation that creates,
purchases or attaches a server. Send the user to **Servers → Create Server**
and pick the work back up once `servers_index` shows the new server.

What the agent *can* do around that:

| Job | MCP tool | Method + path |
|---|---|---|
| List plans, prices, resources, allowed stacks | `catalog_pricing_index` | `GET /catalog/pricing` |
| List every app a site can be created from, with its stacks and minimum resources | `catalog_apps_index` | `GET /catalog/apps` |
| Confirm the new server exists and is provisioned | `servers_index`, `servers_show` | `GET /servers`, `GET /servers/{uuid}` |

The team's own plan and outstanding balance are read through the `account` skill
(`billing_plan`, `billing_overview`).

Both `catalog` endpoints are **unauthenticated** — they work before the user
has a token, which makes them the right answer to "what does xCloud cost?" and
"can xCloud run <app>?".

```bash
"$XC" GET /catalog/pricing | jq '(.data.items // []) | map({uuid, title, price, currency, term: .renewal_term, stacks: .allowed_stacks})'
"$XC" GET /catalog/apps    | jq '(.data.items // []) | map({slug, name, supported_stacks, min_ram_mb: .requirements.min_ram_mb})'
```

`price` is the renewal price. A plan with an introductory discount also carries
`first_purchase_price`, which is what the first bill for that term costs —
never quote it as the ongoing price.

## Server types (stacks), and what each one allows

The stack is chosen at creation and cannot be changed afterwards.

| Stack | Runs | Site limit |
|---|---|---|
| `nginx`, `openlitespeed` | Full xCloud-managed stack: PHP, databases, cache, supervisor | many sites |
| `docker_nginx` | Containers behind nginx; databases live in the user's containers | many sites, **no WordPress** |
| `openclaw`, `paperclip`, `hermes`, `deepseek_harness` (agentic) | nginx as a reverse proxy in front of one server-level agent service. No xCloud-managed database, no PHP, no supervisor | **exactly one site**, created during provisioning |

Consequences the agent must respect:

- **Agentic servers refuse new sites.** Every create endpoint returns `403`
  ("Agentic servers support only the site created during provisioning").
  There is no dashboard workaround; the user needs another server.
- **WordPress is refused on Docker servers** with `422`. Use a Git or one-click
  deployment there instead.
- **Git deploys are endpoint-specific**: `servers_sites_git_create` targets
  nginx/OpenLiteSpeed, `servers_sites_git_docker` targets Docker, and
  `servers_sites_git_auto` picks the right path for either. Calling the wrong
  one returns `422` naming the right endpoint.
- The dashboard offers agentic stacks only on plans with at least **4 GB RAM**
 per the New Server form.
- Match `catalog_apps_index` `requirements` against the plan's resources before
  recommending an app — the install re-checks them and refuses if they are not
  met.

Databases are not on the public API at all — see `references/domain/databases.md`.
