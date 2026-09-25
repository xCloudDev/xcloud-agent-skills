# Email add-ons: mailboxes and mail delivery

> **Packaged REST boundary (v4.4.2):** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="$SKILL_ROOT/scripts/xcloud.sh"` · scopes `read:addons` /
`write:addons`; purchases need the `addon:create` team permission, deletion
`addon:delete`.

| Operation | Operation id | Method + path |
|---|---|---|
| Mailbox plans | `addons.mailbox.plans` | `GET /addons/mailbox/plans` |
| List / get mailboxes | `addons.mailbox.index` · `.show` | `GET /addons/mailbox` · `GET /addons/mailbox/{mailbox}` |
| Buy a mailbox | `addons.mailbox.purchase` | `POST /addons/mailbox/purchase` |
| Verify the domain's DNS | `addons.mailbox.verify-dns` | `POST /addons/mailbox/{mailbox}/verify-dns` |
| IMAP / POP / SMTP settings | `addons.mailbox.imap` · `.pop` · `.smtp` | `GET /addons/mailbox/{mailbox}/{imap,pop,smtp}` |
| Delete a mailbox | `addons.mailbox.destroy` | `DELETE /addons/mailbox/{mailbox}` |
| Mail delivery plans | `addons.mail-delivery.plans` | `GET /addons/mail-delivery/plans` |
| List / get subscriptions | `addons.mail-delivery.index` · `.show` | `GET /addons/mail-delivery` · `GET /addons/mail-delivery/{mailDelivery}` |
| Buy mail delivery | `addons.mail-delivery.purchase` | `POST /addons/mail-delivery/purchase` |

## "Buy a mailbox for hello@example.com, then tell me what DNS to add"

1. `addons.mailbox.plans` → show slug, storage and price (the free tier cannot
   be bought).
2. Collect the address and a password (at least 8 characters, one digit;
   `postmaster@` is reserved). Ask the user to set the password themselves —
   never invent one they did not see, never repeat it back.
3. Restate address, plan, price, and that the team's default card is charged;
   on yes, purchase (body `email`, `password`, `plan`, optional `site_id`).
   Send the body on stdin so the password never reaches the process list.
4. Already-verified domain → the mailbox is `active` with a `webmail_url`.
   Otherwise it is `pending_verification` with `records` to add: list each
   record (type, name, value) as a table the user can copy into their DNS.
5. When the user says the records are in, run `addons.mailbox.verify-dns` and
   report which records are still unverified.

```bash
jq -n --arg e "hello@example.com" --arg p "$MAILBOX_PASSWORD" --arg plan "mailbox_8gb" \
  '{email:$e, password:$p, plan:$plan}' \
  | "$XC" POST /addons/mailbox/purchase - | jq '.data | {uuid, email, status, records, webmail_url}'
```

## Client settings

`imap`, `pop` and `smtp` return host, port, encryption and username — and the
mailbox **password**. Give the user the connection settings; do not print the
password unless they explicitly ask, and never repeat it later. A mailbox's SMTP
has a daily send limit (the response says how much); for bulk or app email,
point to mail delivery.

## Mail delivery (transactional SMTP)

`addons.mail-delivery.purchase` takes a paid `plan` slug and a `label`, charges
the default card, and returns the subscription **with its sending
credentials** — show them once, advise storing them in the app's secret store,
never repeat them. Several subscriptions per team are allowed and every purchase
tops up the same credit pool, so **a repeated purchase is a second charge**:
after a dropped response, list subscriptions before retrying.

## Deleting a mailbox

Irreversible: removes the mailbox and its DNS at the provider (the domain too if
it was the last mailbox), with no refund for the current period. The call
requires `acknowledged_data_loss: true` — only set it after the user has
confirmed the exact address in this conversation.
