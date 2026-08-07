# Firewall, fail2ban & IP whitelisting

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

Create body — required `name`, `protocol`, `traffic` (plus `port`, optional
`ip_address` to scope the rule to a source):

```bash
SERVER_UUID='replace-me'
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

```bash
"$XC" POST "/servers/$SERVER_UUID/firewall/whitelist-caller-ip" | jq '.message'
```

- `ip_addresses` (array) is required when banning.
- `traffic` is `allow` | `deny`; `protocol` is `tcp` | `udp`.
