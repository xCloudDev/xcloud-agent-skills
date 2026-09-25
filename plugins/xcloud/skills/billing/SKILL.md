---
name: billing
description: xCloud billing, pricing and paid add-ons — current plan, billing overview, invoices, bills, subscriptions, purchased packages and products, payment methods on file, paying an outstanding invoice, public hosting prices and app requirements, and buying or managing email add-ons (branded mailboxes with DNS verification and IMAP/POP/SMTP settings, and mail-delivery SMTP subscriptions). Use for "what plan am I on", "show last month's invoice", "how much would a server for X cost", "pay invoice 1234", "buy a mailbox for example.com", "verify the mailbox DNS", or "give me the SMTP settings". NOT creating a server (see xcloud:servers), NOT deploying apps (see xcloud:deploy).
---

# xCloud Billing

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


Owns money and paid add-ons. Read the shared layer first:

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/reference/mcp.md` — **prefer the MCP tools when
  connected**: `billing_*`, `catalog_pricing_index`, `catalog_apps_index`,
  `payments_pay`, `addons_mailbox_*`, `addons_mail-delivery_*`; the `$XC` calls
  below are the REST fallback.

```bash
XC="${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh"
```

Scopes: `read:billing` for billing reads, `read:addons` / `write:addons` for
add-ons and invoice payment. Purchases and payments also need the team
permission (`addon:create`, `billing:create`).

## Response format

Brand every user-facing reply (see `reference/conventions.md` →
**Response format**): open with `☁️ **xCloud · Billing** — <team or item>`, give
the trimmed result, and close with a `_via xcloud:billing_` line.

Narrate each call (see **Progress narration**): before every call print one line
of what xCloud is doing, e.g. `☁️ xCloud is fetching your latest invoice…`; the
first call of a task opens with `☁️ xCloud is starting a session…`. **Every
progress line and every action sentence must start with `xCloud` as the actor —
never a bare verb like "Fetching…" or "Buying…". Say `xCloud is fetching…`.**

On the **first** xcloud reply in a conversation, lead with the xCloud startup
banner (see `reference/conventions.md` → **Startup banner**) in a fenced code
block — once per conversation.

## Sub-resources (load on demand)

| Sub-resource | Reference file |
|---|---|
| Mailboxes and mail delivery (plans, purchase, DNS, IMAP/POP/SMTP) | `reference/addons.md` |

## Core endpoints

| Operation | Operation id | Method + path |
|---|---|---|
| Current plan | `billing.plan` | `GET /billing/plan` |
| Billing overview | `billing.overview` | `GET /billing/overview` |
| Invoices (filter `status`, `search`) | `billing.invoices.index` · `.show` | `GET /billing/invoices` · `GET /billing/invoices/{invoiceNumber}` |
| Bills (filter `status`, `service`, `renewal_period`, `active`) | `billing.bills.index` · `.show` | `GET /billing/bills` · `GET /billing/bills/{uuid}` |
| Subscriptions | `billing.subscriptions.index` | `GET /billing/subscriptions` |
| Purchased packages / products | `billing.packages.index` · `billing.products.index` | `GET /billing/packages` · `GET /billing/products` |
| Payment methods (masked) | `billing.payment-methods.index` | `GET /billing/payment-methods` |
| Pay an outstanding invoice | `payments.pay` | `POST /payments/{invoice}/pay` |
| Public hosting prices | `catalog.pricing.index` | `GET /catalog/pricing` |
| App requirements (stacks, minimum size) | `catalog.apps.index` | `GET /catalog/apps` |
| Server plans this team can buy | `servers.plans` | `GET /servers/plans` (buying: `xcloud:servers`) |

## Answering questions

- "What plan am I on / what does it include?" → `billing.plan` +
  `billing.overview`; for plan features the API does not return, use
  `xcloud_docs_search` and answer in product terms.
- "Show last month's invoice and its total" → `billing.invoices.index`, pick by
  date, then `billing.invoices.show` — give number, date, status, total and line
  items, not the raw object.
- "How much would it cost to run X?" → `catalog.apps.index` for X's minimum
  size, `servers.plans` (or `catalog.pricing.index` for public prices), and the
  user's existing servers first — "it fits on the server you already pay for"
  beats a new plan. Say which minimum you used.
- Changing or cancelling a subscription is dashboard-only (**Account →
  Subscriptions**; cards and payment history under **Account → Billing → Bills &
  Payment**).

## Money rules

- **Every purchase and payment is explicit-approval only.** Before
  `payments.pay` or an add-on purchase: name the item, plan, price, renewal
  period, and that it charges the team's **default** card (confirm one exists
  with `billing.payment-methods.index`, masked). Then wait for a yes; on MCP
  send `confirm: true`.
- **No idempotency on payments or add-on purchases.** After a timeout or
  dropped response, read `billing.invoices.index` / the add-on list before
  anything else — a repeated mail-delivery purchase tops up credits again, and a
  repeated `payments.pay` retries the charge.
- A `402` with an `authentication_url` means 3-D Secure: hand the user the link;
  never retry blindly.
- Rate limits: purchases and payments are 10 requests per minute.

## Examples

```bash
"$XC" GET /billing/plan | jq '.data'
"$XC" GET "/billing/invoices?per_page=5" | jq '.data.items | map({number, title, status, amount, currency, due_date, paid_at})'
"$XC" GET /catalog/pricing | jq '.data'
```
