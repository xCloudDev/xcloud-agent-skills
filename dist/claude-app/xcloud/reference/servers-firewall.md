# Firewall, fail2ban & IP whitelisting

> **Packaged REST boundary:** `xcloud.sh` enforces GET-only requests with no body and has no write override. Non-GET examples below describe upstream API operations, not executable commands for this fallback. For mutations, use the corresponding connected xCloud MCP tool only after the required concrete user approval and server confirmation. If that tool/confirmation is unavailable, stop and direct the user to the dashboard; do not bypass this boundary with direct curl, SDKs, alternate scripts or by editing the wrapper. Configure REST credentials with read-only scopes.


`XC="scripts/xcloud.sh"` · scope `read:servers` / `write:servers`.
Server-level security lives here (not in a separate security skill).

## Firewall rules

| Operation | Method + path |
|---|---|
| List | `GET /servers/{uuid}/firewall-rules` |
| Create | `POST /servers/{uuid}/firewall-rules` |
| Delete | `DELETE /servers/{uuid}/firewall-rules/{firewallRuleUuid}` |
| Enable | `POST /servers/{uuid}/firewall-rules/{firewallRuleUuid}/enable` |
| Disable | `POST /servers/{uuid}/firewall-rules/{firewallRuleUuid}/disable` |

A firewall rule changes who can reach the server. A wrong `deny` rule, or an
`allow` rule that opens a port to everyone, can lock the owner out or expose a
service: say the exact port, protocol, direction and source IP, say which
server it is on, and never add a rule that blocks your own SSH port (22), your own IP or the web ports
(80, 443) unless the user names that port. Keep the rule's uuid so the rule
can be disabled or deleted again.

Create body — required `name`, `protocol`, `traffic` (plus `port`, optional
`ip_address` to scope the rule to a source):

```bash
SERVER_UUID='replace-me'
# Preview, then confirm: show the user what will change on server "$SERVER_NAME" and wait for a yes.
# Target named: server "$SERVER_NAME".
"$XC" POST "/servers/$SERVER_UUID/firewall-rules" '{
  "name": "Allow Postgres from office",
  "protocol": "tcp",
  "traffic": "allow",
  "port": "5432",
  "ip_address": "203.0.113.10"
}' | jq '.data'
```

## fail2ban

| Operation | Method + path | Body |
|---|---|---|
| List banned IPs | `GET /servers/{uuid}/fail2ban/banned-ips` | — |
| Ban IPs | `POST /servers/{uuid}/fail2ban/banned-ips` | `{"ip_addresses":["1.2.3.4"]}` |
| Unban an IP | `DELETE /servers/{uuid}/fail2ban/banned-ips/{ip}` | — |

## IP whitelisting / SSH restriction

| Operation | Method + path |
|---|---|
| SSH restriction status | `GET /servers/{uuid}/firewall/ssh-restriction-status` |
| Whitelist caller IP | `POST /servers/{uuid}/firewall/whitelist-caller-ip` |
| Whitelist xCloud infra IPs | `POST /servers/{uuid}/firewall/whitelist-xcloud-ips` |

"Caller IP" is the address the request comes from, which for an agent is the
agent's host, not the user's computer. Ask the user for the address they want
allowed and add it as a firewall rule instead; do not call
`whitelist-caller-ip` on their behalf.

```bash
# Preview, then confirm: show the user the address and the server it is added to, and wait for a yes.
# Target named: server "$SERVER_NAME", address "$ALLOWED_IP".
"$XC" POST "/servers/$SERVER_UUID/firewall-rules" "$(jq -n --arg ip "$ALLOWED_IP" '{name:"Allow office",protocol:"any",traffic:"allow",ip_address:$ip}')" | jq '.data'
```

- `ip_addresses` (array) is required when banning.
- `traffic` is `allow` | `deny`; `protocol` is `tcp` | `udp` | `any`; `port` can be a range.
