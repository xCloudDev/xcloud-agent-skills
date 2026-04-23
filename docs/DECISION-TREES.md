# DECISION-TREES: Choosing the Right Approach

Decision trees to help agents select the right deployment type, server, and configuration.

---

## 1. Deployment Type Selection

```
What do you need to deploy?
│
├─ WordPress website
│   ├─ Has custom domain? → Deploy Live WP (docs/DEPLOY.md #1)
│   └─ Testing/preview? → Deploy Demo WP (docs/DEPLOY.md #2)
│
├─ Containerized app (Docker)
│   └─ → SSH + Docker Compose (docs/DEPLOY.md #5)
│
├─ Static site
│   └─ → SSH + Nginx config
│
├─ Custom PHP app
│   └─ → WordPress site → override public_html
│
└─ Multiple sites from template
    └─ Has blueprint? → Blueprint deploy (docs/DEPLOY.md #4)
        No blueprint? → Manual deploy per site
```

---

## 2. Server Selection

```
How many existing sites on available servers?
│
├─ 0-30 sites → Use that server (room for growth)
├─ 30-40 sites → Evaluate disk usage first
│   ├─ Disk < 70% → Use that server
│   └─ Disk ≥ 70% → Provision new server first (docs/SETUP.md #1)
└─ 40+ sites → Provision new server first

Preferred server characteristics:
├─ Newest OS version
├─ Highest PHP version (8.2+)
├─ Lowest disk usage
└─ Lowest site count
```

---

## 3. PHP Version Selection

```
What PHP version?
│
├─ New WordPress site → 8.2 (recommended, best performance)
├─ Legacy WordPress site → 8.1 (compatibility, still supported)
├─ Plugin compatibility issues → 8.0 (fallback)
├─ Very old plugins → 7.4 (last resort, EOL)
└─ Custom PHP app → Match app's tested PHP version

Rule: Never go below 8.0 for new deployments
Rule: Upgrade all existing 7.4 sites → 8.1 within 90 days
```

---

## 4. SSL Provider Selection

```
What SSL should I use?
│
├─ Standard domain (*.com, *.org, etc.)
│   └─ → letsencrypt (free, auto-renews)
│
├─ Wildcard domain (*.example.com)
│   └─ → Requires DNS challenge support
│       ├─ Cloudflare DNS → letsencrypt with Cloudflare API
│       └─ Other DNS → Manual cert upload
│
└─ Internal/test domain
    └─ → Self-signed or no SSL
```

---

## 5. Cache Strategy

```
What caching should I enable?
│
├─ New WordPress site → Full page + Object cache (both enabled)
├─ WooCommerce / Dynamic content → Object cache only
├─   (Full page cache breaks cart/checkout)
├─ Member-only site → Object cache only
│   (Full page serves cached pages to logged-in users)
├─ Development site → No cache (see changes immediately)
└─ API-heavy WordPress → Object cache only

After any config change: Always purge cache (docs/CONFIGURE.md #4)
```

---

## 6. SSH Authentication Mode

```
What SSH authentication to use?
│
├─ Automated deployments (CI/CD)
│   └─ → public_key
│       Add deployment machine's public key
│
├─ Manual developer access
│   └─ → public_key
│       Add each developer's public key
│
├─ Temporary access (support/debugging)
│   └─ → password
│       Generate strong random password, share securely
│
└─ No access needed (API-managed only)
    └─ → public_key with empty key list
        (Effectively disable access but keep mode consistent)
```

---

## 7. Backup Strategy

```
How often to backup?
│
├─ Production site (active traffic) → Daily automated backups
├─ Staging site → Weekly, or before major changes
├─ Development site → Before changes (manual trigger)
└─ New site (first hour) → Immediately after provisioning

Before destructive operations:
├─ PHP version change → Backup
├─ Domain change → Backup  
├─ Plugin/theme update → Backup
├─ Database migration → Backup
└─ Server reboot → Optional (no data change)
```

---

## 8. Monitoring Alert Thresholds

```
When to alert?
│
├─ HTTP status != 200 for > 2 checks → Alert (may be transient)
├─ Disk usage > 80% → Warn
├─ Disk usage > 90% → Critical alert
├─ SSL expires in < 30 days → Warn
├─ SSL expires in < 7 days → Critical
├─ SSL expired → Critical (auto-renew triggered)
├─ CPU > 90% sustained 5 min → Warn
├─ Memory > 90% → Warn
└─ Site status = "failed" → Critical
```

---

## 9. Troubleshooting Decision Tree

```
Site not working?
│
├─ API says status != "provisioned"
│   ├─ status = "provisioning" + <20 min → Wait
│   ├─ status = "provisioning" + >20 min → Cancel + redeploy
│   └─ status = "failed" → Check events → See TROUBLESHOOT.md #8
│
├─ API says status = "provisioned" but site not accessible
│   ├─ HTTP 502 → See TROUBLESHOOT.md #1 (502 Recovery)
│   ├─ HTTP 404 → Check domain routing
│   ├─ DNS not resolving → See TROUBLESHOOT.md #2
│   └─ Certificate error → See TROUBLESHOOT.md #3
│
└─ Site accessible but slow
    ├─ Cache disabled? → Enable cache (CONFIGURE.md #4)
    ├─ PHP old version? → Upgrade PHP (CONFIGURE.md #3)
    └─ Server overloaded? → Check monitoring → Add server
```

---

## 10. API Error Decision Tree

```
API returned error?
│
├─ 401 Unauthorized
│   ├─ Check XCLOUD_API_TOKEN is set → `echo $XCLOUD_API_TOKEN`
│   ├─ Token may be expired → Create new token in dashboard
│   └─ Token format correct? → Must be Bearer token, not API key
│
├─ 403 Forbidden
│   ├─ Token lacks required scope
│   ├─ Endpoint requires write:sites → Verify token scope
│   └─ Create new token with correct scopes → See SKILL.md Scopes
│
├─ 404 Not Found
│   ├─ UUID is wrong → Verify UUID from list endpoint
│   ├─ Resource deleted → Check in dashboard
│   └─ Typo in UUID → Re-check character by character
│
├─ 422 Unprocessable Entity
│   ├─ Missing required field → Check API docs
│   ├─ Field validation failed → Check error.errors for details
│   └─ Conflicting options → Check constraints in SKILL.md
│
├─ 429 Too Many Requests
│   ├─ Slow down requests (max 60/min)
│   ├─ Add sleep between API calls
│   └─ Check Retry-After header for wait time
│
└─ 5XX Server Error
    ├─ API issue on xCloud side
    ├─ Retry after 30 seconds
    └─ If persistent → Check https://status.xcloud.host
```

---

## 11. Choosing Python SDK vs curl

```
Which interface to use?
│
├─ One-off query (find UUID, check status)
│   └─ → curl (faster to type)
│
├─ Complex workflow with multiple steps
│   └─ → Python SDK (cleaner code, error handling built-in)
│
├─ Background automation / cron job
│   └─ → Bash script with src/xcloud-api.sh wrapper
│
├─ Interactive terminal session
│   └─ → src/xcloud-cli.sh tool
│
└─ Existing Python codebase
    └─ → Python SDK (integrates cleanly)
```
