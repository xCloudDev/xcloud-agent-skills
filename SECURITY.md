# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in the xCloud Public API skill, please email security@xcloud.host instead of using the public issue tracker.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

## Secure Token Management

### Best Practices

1. **Store tokens securely:**
   ```bash
   # ❌ BAD: Token in environment variable visible to all processes
   export XCLOUD_API_TOKEN="12|..."
   
   # ✅ GOOD: Token in secure credential file
   echo "12|..." > /root/.xcloud/api-token
   chmod 600 /root/.xcloud/api-token
   source /root/.xcloud/api-token
   ```

2. **Rotate tokens regularly:**
   - Generate new token at https://app.xcloud.host/settings/api-tokens
   - Invalidate old token immediately after testing new one
   - Audit token usage logs for suspicious activity

3. **Use scoped tokens:**
   - Don't use tokens with `*` (all scopes) in CI/CD
   - Create separate tokens for each service:
     - CI/CD: `write:sites` (deployment) + `read:servers`
     - Monitoring: `read:servers` + `read:sites`
     - Backup ops: `write:sites` (backup triggering)

4. **Never commit tokens:**
   - Add `.env` to `.gitignore`
   - Use GitHub Secrets for token storage in CI/CD
   - Scan git history for accidentally committed tokens
   ```bash
   # Search for token patterns in history
   git log -p | grep -i "xcloud_api_token\|12|"
   ```

5. **Monitor for exposure:**
   - If token is exposed, revoke immediately at https://app.xcloud.host/settings/api-tokens
   - Monitor API logs for suspicious requests
   - Check for unauthorized site creation or backups

### Environment Variable Security

```python
# ✅ GOOD: Read from secure location
import os
token_file = os.path.expanduser("~/.xcloud/api-token")
if not os.path.exists(token_file):
    raise ValueError("Token file not found")
if oct(os.stat(token_file).st_mode)[-3:] != "600":
    raise ValueError("Token file has insecure permissions")

with open(token_file) as f:
    api_token = f.read().strip()
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Deploy with xCloud
  env:
    XCLOUD_API_TOKEN: ${{ secrets.XCLOUD_API_TOKEN }}
  run: |
    # Token is masked in logs by GitHub
    python deploy.py

# GitLab CI example
deploy:
  script:
    - python deploy.py
  variables:
    XCLOUD_API_TOKEN: $XCLOUD_API_TOKEN
    # Ensure logs are masked
  artifacts:
    expire_in: 1 day
    when: always
```

## API Security

### Authentication

- All endpoints except `/health` require authentication
- Use `Authorization: Bearer <token>` header
- Token format: `<ID>|<SECRET>`
  - ID is public identifier (shown in dashboard)
  - Secret is sensitive (never share)

### HTTPS Only

- Always use `https://` — never plain `http://`
- All API traffic is encrypted in transit
- Certificates are validated (pinning recommended for production)

### Rate Limiting

- **60 requests per minute** (authenticated)
- **10 requests per minute** (unauthenticated)
- Respect `Retry-After` header on 429 responses
- Implement exponential backoff

### Data in Transit

- All payloads are JSON over HTTPS
- SSL certificate pinning recommended:
  ```python
  import requests
  import certifi
  
  session = requests.Session()
  session.verify = certifi.where()  # Verify certificate
  session.cert = ("/path/to/client.crt", "/path/to/client.key")  # Optional client cert
  ```

## Dependency Security

### Python SDK Dependencies

- **requests** — HTTP client (inspect security advisories)
- **backoff** — Retry logic (minimal, audited)
- No other external dependencies

### Vulnerability Scanning

```bash
# Check for known vulnerabilities in dependencies
pip install safety
safety check

# Or use pip-audit
pip install pip-audit
pip-audit
```

## Secure Configuration

### Web Server Security

When deploying sites via xCloud, follow these best practices:

1. **Keep PHP updated:**
   ```bash
   # Use latest supported PHP version
   xcloud-cli.sh site create example.com <uuid> 8.3  # Latest
   ```

2. **Enable caching:**
   ```python
   api.create_wordpress_site(
       domain=domain,
       cache_full_page=True,      # Protects against some attacks
       cache_object=True          # Speeds up database queries
   )
   ```

3. **Use Let's Encrypt SSL:**
   ```python
   api.create_wordpress_site(
       domain=domain,
       ssl_provider="letsencrypt"  # Free, auto-renewing
   )
   ```

4. **Disable dangerous PHP functions:**
   ```bash
   # Via SSH config
   xcloud-cli.sh site ssh <uuid>
   
   # Add to PHP config
   disable_functions = eval,passthru,shell_exec,system
   ```

5. **Monitor file integrity:**
   ```bash
   # Check for recently modified files
   find /var/www -name '*.php' -mtime -1
   find /var/www -type f -perm 777  # World-writable
   ```

## Known Security Considerations

### API Limitations

1. **No IP whitelisting** — Any network with your token can access API
2. **No request signing** — Only bearer token auth (no HMAC)
3. **No audit logs** — Limited visibility into who/what accessed API
4. **No token expiration** — Tokens valid until manually revoked

### Operational Security

1. **Human access needed** — Some operations (reboot server) are risky
   - Consider requiring approval before executing
   - Use separate tokens for automation vs. manual ops

2. **No encryption at rest** — Sites/databases stored on server
   - Use SFTP to encrypt backup transfers
   - Implement server-side encryption if sensitive data

3. **Shared server risk** — Multiple sites/users on single server
   - Verify server isolation (separate PHP-FPM pools, database users)
   - Don't assume complete isolation

## Security Checklist

Before production deployment:

- [ ] Token stored securely (not in code, not in logs)
- [ ] Token has minimal required scopes (not `*`)
- [ ] Rate limiting implemented (not hitting 429s)
- [ ] Error messages don't expose sensitive data
- [ ] HTTPS only (no plain HTTP API calls)
- [ ] Token rotated within last 90 days
- [ ] Unauthorized API calls monitored
- [ ] Backup encryption enabled
- [ ] SSL certificates are valid and renewed
- [ ] Web server security hardened (disable dangerous PHP functions)
- [ ] Database user has minimal required permissions
- [ ] File permissions are correct (no world-writable PHP files)
- [ ] Recent backups verified and tested
- [ ] Incident response plan documented

## Security Incident Response

If you suspect your account has been compromised:

1. **Immediately revoke the token:**
   - Go to https://app.xcloud.host/settings/api-tokens
   - Click "Revoke" for the compromised token
   - Generate a new token with the same scopes

2. **Audit recent activity:**
   - Check API logs for unauthorized requests
   - Review site creation/modification timestamps
   - Verify backups are intact

3. **Contact xCloud support:**
   - Email security@xcloud.host
   - Include timeline of discovered compromise
   - Provide any suspicious request logs

4. **Notify affected users:**
   - If sites were modified, notify site owners
   - Recommend password resets
   - Offer site restore from backup if needed

## Security Advisories

Subscribe to security updates:
- GitHub: Watch https://github.com/xCloudDev/xcloud-agent-skills/releases
- Email: Subscribe at https://xcloud.host/security-updates
- Twitter: Follow @xCloudDev for announcements

## Third-Party Security

This skill integrates with:
- **xCloud API** — Managed by xCloud (https://xcloud.host/security)
- **Your servers** — Managed by your infrastructure
- **Your sites** — Your responsibility

Ensure all layers are secure:

```
Your Agent
    ↓
Your Network (firewall, VPN?)
    ↓
xCloud API (HTTPS, rate limited)
    ↓
xCloud Servers (Linux, firewall, SSH keys)
    ↓
Your WordPress Sites (PHP, database, backups)
```

Each layer must be secured.

