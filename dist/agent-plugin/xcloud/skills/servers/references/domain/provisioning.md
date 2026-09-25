# Buying a server

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scopes `read:servers` /
`write:servers`; checking the card on file needs `read:billing`.

| Operation | Operation id | Method + path |
|---|---|---|
| Plans this team can buy (specs, price per period, regions) | `servers.plans` | `GET /servers/plans` |
| Public price list | `catalog.pricing.index` | `GET /catalog/pricing` |
| App minimum sizes | `catalog.apps.index` | `GET /catalog/apps` |
| Card on file (masked) | `billing.payment-methods.index` | `GET /billing/payment-methods` |
| **Buy and provision a server** | `servers.store` | `POST /servers` |
| Provisioning checklist | `servers.provisioning-progress` | `GET /servers/{uuid}/provisioning-progress` |
| Authoritative status | `servers.show` | `GET /servers/{uuid}` |

`POST /servers` buys an **xCloud-managed (Vultr)** server on the team's billing
account and charges the team's default card. Connecting a machine from the
user's own Hetzner, DigitalOcean, AWS or other account — and enrolling a
self-managed server — is dashboard-only (**Servers → Create server → Bring and
Manage Your Own Server**).

## "Create a server on the smallest plan in Singapore — show me the price first"

1. **Check what they already have.** `GET /servers` — "it fits on the server you
   already pay for" beats a new plan when the app's minimum size allows it
   (`catalog.apps.index`). Agentic servers never take a second site.
2. **Quote.** `GET /servers/plans` → pick the plan(s) that match the request and
   offer the region; show slug, vCPU/RAM/disk, price for the renewal period, and
   region. Say which app minimum you sized against, if any.
3. **Card check.** `GET /billing/payment-methods` — no card means `402` before
   anything is created; send the user to **Account → Billing → Bills & Payment**.
4. **Approve.** Restate name, plan, region, stack (`nginx` or `openlitespeed`),
   database (`none`, `mysql8`, `mysql84`, `mariadb10`, `mariadb11`, …), renewal
   period (`monthly`, `yearly`, `two_yearly`) and price. Wait for a yes.
5. **Buy once.** Send the body with an `Idempotency-Key` (and `confirm: true` on
   MCP). The key is what makes a retry safe: without one, a second call is a
   second paid server — after a dropped response, read `GET /servers` before
   trying again.
6. **Follow it.** `202` → poll `provisioning-progress` (`percent_complete`,
   `stages[].tasks[].status`) for the human-readable progress and `GET
   /servers/{uuid}` for the authoritative status: `new` → `provisioning` →
   `provisioned`, or `provisioning_failed`. Report the IP and `dashboard_url`
   when it is ready, and offer the next step (deploy an app: the `deploy` skill).

```bash
"$XC" GET /servers/plans \
  | jq '.data.plans | map({slug, name, specs, pricing, regions: [.regions[].id]})'
KEY=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')   # keep it: a retry must reuse this key
NEW=$(jq -n '{name:"sg-app-1", size:"vc2-1c-1gb", region:"sgp", stack:"nginx",
              database_type:"mysql8", renewal_period:"monthly", backups:false}' \
  | XCLOUD_IDEMPOTENCY_KEY="$KEY" "$XC" POST /servers -)
printf '%s' "$NEW" | jq '.data | {uuid, name, status, ip_address, region}'
SERVER_UUID=$(printf '%s' "$NEW" | jq -er '.data.uuid') \
  || echo "create failed or no response — read GET /servers, then retry with the same KEY"
"$XC" GET "/servers/$SERVER_UUID/provisioning-progress" | jq '.data | {percent_complete}'
```

A declined card or a 3-D Secure challenge leaves an unpaid invoice: settle it
with the `billing` skill (`payments.pay`), which takes no idempotency key — read the
invoice first and never fire it blind.
