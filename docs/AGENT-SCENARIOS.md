# xCloud Agent Scenarios
Real-world use cases for AI agents using the xCloud Public API skill.

---

## 🏗️ Tank — Infrastructure Developer

**Role:** Provisioning, deployment automation, CI/CD integration  
**Superpowers:** Code writing, infrastructure-as-code, debugging  
**xCloud Tasks:**

### 1. Auto-Provision Staging Sites on Feature Branches

```python
# When: GitHub PR created → Tank triggered
# What: Provision staging site on xCloud
# Result: Preview URL posted to PR

from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()
site = deployer.create_site_with_poll(
    domain=f"pr-{pr_number}.staging.example.com",
    server_uuid="matrix-zion-uuid",
    timeout=300  # Wait 5 min for provisioning
)

print(f"✅ Staging site ready: https://{site['domain']}")
github.create_pr_comment(f"Preview: {site['domain']}")
```

### 2. Deploy Docker Containers to xCloud Sites

```python
# When: New docker-compose repo pushed to xCloud server
# What: Auto-deploy latest image
# Result: Container running, health-check passing

from xcloud_sdk import XCloudAPI

api = XCloudAPI()
site = api.get_site(site_uuid="...")

# Pull latest image, deploy via site SSH config
ssh_config = api.get_site_ssh_config(site['uuid'])
deploy_via_ssh(ssh_config, docker_compose_file)

# Verify it's healthy
status = poller.poll_until_ready("site", site['uuid'])
assert status['provisioned'] and check_http_status(site['domain']) == 200
```

### 3. Automated Backup Before Every Deployment

```python
# When: Deployment pipeline runs
# What: Trigger backup before deploying
# Result: Safe rollback point

from xcloud_sdk import XCloudAPI
from xcloud_async import AsyncPoller

api = XCloudAPI()
poller = AsyncPoller(api)

# Backup all sites on this server
sites = api.list_sites(server_uuid=server_uuid)
for site in sites['items']:
    api.trigger_backup(site['uuid'])

# Wait for backups to complete (poll events)
for site in sites['items']:
    events = api.get_site_events(site['uuid'])
    if events and events[0]['type'] == 'backup':
        print(f"✅ Backup complete: {site['domain']}")
```

### 4. Build System Status Dashboard

```python
# When: CI/CD pipeline needs status page
# What: Aggregate server/site health from xCloud
# Result: Real-time dashboard of infrastructure

from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()
health = deployer.get_fleet_health()

print(f"Servers: {health['servers']['provisioned']}/{health['servers']['total']}")
print(f"Sites: {health['sites']['total']}")
for site_type, count in health['sites']['by_type'].items():
    print(f"  - {site_type}: {count}")
```

---

## 🏛️ Morpheus — Architect & Strategic Planning

**Role:** Fleet management, capacity planning, cost optimization  
**Superpowers:** Systems thinking, strategic planning, data analysis  
**xCloud Tasks:**

### 1. Fleet Capacity Planning

```python
# When: Monthly planning cycle
# What: Analyze server utilization, identify under-utilized servers
# Result: Recommendation to consolidate or spin down servers

from xcloud_sdk import XCloudAPI

api = XCloudAPI()
servers = api.list_servers(per_page=100)['items']

for server in servers:
    # Get all sites on this server
    sites = api.list_sites(server_uuid=server['uuid'])['items']
    
    print(f"{server['name']}: {len(sites)} sites")
    if len(sites) < 3:
        print(f"  ⚠️  Consolidation candidate (underutilized)")

# Generate capacity report
report = {
    "total_servers": len(servers),
    "total_sites": sum(len(api.list_sites(server_uuid=s['uuid'])['items']) for s in servers),
    "utilization_score": calculate_utilization(servers),
    "recommendations": ["Consolidate RackNerd-1GB", "Upgrade Hetzner-4GB"]
}
```

### 2. Disaster Recovery Planning

```python
# When: Quarterly DR review
# What: Verify all sites have recent backups
# Result: Recovery time objective (RTO) compliance report

from xcloud_sdk import XCloudAPI
from datetime import datetime, timedelta

api = XCloudAPI()
sites = api.list_sites(per_page=100)['items']

backup_compliance = []
for site in sites:
    backups = api.get_site_backups(site['uuid'])
    
    if not backups:
        backup_compliance.append({
            "domain": site['domain'],
            "status": "NO_BACKUP",
            "risk": "CRITICAL"
        })
    else:
        oldest = parse_datetime(backups[0]['created_at'])
        age_days = (datetime.now() - oldest).days
        
        status = "OK" if age_days < 7 else "STALE" if age_days < 30 else "MISSING"
        backup_compliance.append({
            "domain": site['domain'],
            "last_backup_age": age_days,
            "status": status,
            "risk": "LOW" if status == "OK" else "MEDIUM" if status == "STALE" else "HIGH"
        })

# Report
critical = [b for b in backup_compliance if b['risk'] == 'CRITICAL']
print(f"DR Compliance: {len(critical)} sites at risk")
```

### 3. Cost Optimization Analysis

```python
# When: Cost review meeting
# What: Identify expensive servers, underutilized resources
# Result: $$/month savings recommendations

from xcloud_sdk import XCloudAPI

api = XCloudAPI()
servers = api.list_servers(per_page=100)['items']

cost_analysis = []
for server in servers:
    sites = api.list_sites(server_uuid=server['uuid'])['items']
    
    # Rough cost model (replace with real xCloud pricing)
    monthly_cost = estimate_cost(server['provider'], server['location'])
    cost_per_site = monthly_cost / len(sites) if sites else monthly_cost
    
    cost_analysis.append({
        "server": server['name'],
        "provider": server['provider'],
        "sites": len(sites),
        "monthly_cost": monthly_cost,
        "cost_per_site": cost_per_site,
        "optimization": "Consolidate to Hetzner" if server['provider'] == "Other" else None
    })

total_monthly = sum(c['monthly_cost'] for c in cost_analysis)
print(f"Total monthly cost: ${total_monthly}")
print(f"Potential savings: ${estimate_savings(cost_analysis)}")
```

### 4. Infrastructure-as-Code Generation

```python
# When: Documentation/archiving need
# What: Generate Terraform/CloudFormation from live xCloud state
# Result: IaC that matches current infrastructure

from xcloud_sdk import XCloudAPI

api = XCloudAPI()
servers = api.list_servers(per_page=100)['items']

terraform = """
# Auto-generated from xCloud API
"""

for server in servers:
    terraform += f"""
resource "xcloud_server" "{sanitize_name(server['name'])}" {{
  name     = "{server['name']}"
  location = "{server['location']}"
  provider = "{server['provider']}"
  ip_address = "{server['ip_address']}"
}}
"""
    
    sites = api.list_sites(server_uuid=server['uuid'])['items']
    for site in sites:
        terraform += f"""
resource "xcloud_site" "{sanitize_name(site['name'])}" {{
  server_uuid = xcloud_server.{sanitize_name(server['name'])}.id
  domain      = "{site['domain'] or site['name']}"
  type        = "{site['type']}"
}}
"""

print(terraform)
save_to_file("infrastructure.tf", terraform)
```

---

## 🔍 Keymaker — Market Intelligence & Monitoring

**Role:** Competitive intelligence, brand monitoring, trend detection  
**Superpowers:** Research, data gathering, pattern recognition  
**xCloud Tasks:**

### 1. Competitor Site Monitoring

```python
# When: Daily monitoring cycle
# What: Track competitor site changes hosted on xCloud
# Result: Alert if competitor deploys new features

from xcloud_sdk import XCloudAPI
import requests
from hashlib import md5

api = XCloudAPI()
keymaker_state = load_state("competitor-monitoring.json")

# Competitors known to use xCloud
competitors = [
    {"name": "Pylons.ai", "domains": ["pylons.ai"]},
    {"name": "OpenClawd.ai", "domains": ["openclawd.ai"]},
]

for competitor in competitors:
    for domain in competitor['domains']:
        try:
            # Fetch site and compute hash
            response = requests.get(f"https://{domain}", timeout=10)
            current_hash = md5(response.content).hexdigest()
            
            # Compare to last known state
            last_state = keymaker_state.get(domain, {})
            last_hash = last_state.get('hash')
            
            if last_hash and last_hash != current_hash:
                print(f"🚨 CHANGE DETECTED: {domain}")
                alert_keymaker(f"Competitor {competitor['name']} updated website")
            
            # Update state
            keymaker_state[domain] = {
                'hash': current_hash,
                'checked_at': datetime.now().isoformat(),
                'status_code': response.status_code
            }
        except Exception as e:
            print(f"⚠️  Failed to check {domain}: {e}")

save_state("competitor-monitoring.json", keymaker_state)
```

### 2. xCloud Marketplace Malicious Skill Detection

```python
# When: ClawHub security scan
# What: Monitor xCloud-deployed apps for signs of compromise
# Result: Alert if malicious skills or backdoors detected

from xcloud_sdk import XCloudAPI
import subprocess

api = XCloudAPI()

# Get all sites (many deployed via xCloud)
sites = api.list_sites(per_page=100)['items']

security_findings = []
for site in sites:
    ssh_config = api.get_site_ssh_config(site['uuid'])
    
    # SSH into site and run security checks
    checks = [
        "find /var/www -name '*.php' -mtime -1 | wc -l",  # Recently modified PHP
        "grep -r 'eval(' /var/www 2>/dev/null | wc -l",    # eval() usage
        "find /var/www -perm 777 2>/dev/null | wc -l",     # World-writable files
    ]
    
    findings = run_security_checks(ssh_config, checks)
    
    if findings['recently_modified_php'] > 5 or findings['eval_usage'] > 0:
        security_findings.append({
            "site": site['domain'],
            "risk": "HIGH",
            "findings": findings
        })

if security_findings:
    alert_keymaker(f"Security: {len(security_findings)} sites at risk")
```

### 3. Real-Time Brand Mention Alerts

```python
# When: Continuous monitoring (every 30 min)
# What: Monitor web for xCloud brand mentions
# Result: Alert on viral mentions, bad press, competitor FUD

from xcloud_sdk import XCloudAPI
import requests

api = XCloudAPI()
keymaker_state = load_state("brand-mentions.json")

queries = [
    "xcloud.host wordpress hosting",
    "xCloud API agent deployment",
    "best openclaw hosting 2026",
]

for query in queries:
    # Use Brave Search API
    results = requests.get(
        "https://api.search.brave.com/res/v1/web/search",
        params={"q": query},
        headers={"Accept": "application/json", "X-Subscription-Token": brave_token}
    ).json()
    
    # Check for new/interesting mentions
    for result in results['web']:
        mention_id = md5(f"{query}:{result['url']}".encode()).hexdigest()
        last_state = keymaker_state.get(mention_id, {})
        
        # Determine if this is noteworthy
        is_new = mention_id not in keymaker_state
        is_viral = count_social_shares(result['url']) > 100
        is_press = is_major_publication(result['url'])
        
        if is_new or is_viral or is_press:
            print(f"📰 BRAND MENTION: {result['title']}")
            alert_keymaker(f"Mention: {result['title']} ({result['url']})")
        
        keymaker_state[mention_id] = {
            "title": result['title'],
            "url": result['url'],
            "checked_at": datetime.now().isoformat()
        }

save_state("brand-mentions.json", keymaker_state)
```

---

## ✍️ Shuri — Content & Research

**Role:** Content operations, multi-site management  
**Superpowers:** Content creation, bulk operations, research  
**xCloud Tasks:**

### 1. Multi-Site Content Deployment

```python
# When: Publish new blog post across all sites
# What: Deploy WordPress post to all sites simultaneously
# Result: Content live on all platforms in 1 action

from xcloud_sdk import XCloudAPI

api = XCloudAPI()
sites = api.list_sites(site_type="wordpress")['items']

# Connect to each site via SSH and deploy
for site in sites:
    ssh_config = api.get_site_ssh_config(site['uuid'])
    
    # Deploy post via WP-CLI
    deploy_via_ssh(ssh_config, f"""
        wp post create --post_title='New Post' --post_content='...' --post_type=post
        wp cache flush
    """)
    
    print(f"✅ Deployed to {site['domain']}")
```

### 2. Site Health Metrics for Content Ops

```python
# When: Content operations standup
# What: Report on which sites are healthy for deployment
# Result: Deployment readiness matrix

from xcloud_sdk import XCloudDeployer

deployer = XCloudDeployer()
fleet_health = deployer.get_fleet_health()

print("=== Content Deployment Readiness ===")
print(f"Total sites: {fleet_health['sites']['total']}")
print(f"Provisioned: {fleet_health['sites']['by_status'].get('provisioned', 0)}")
print(f"Safe to deploy to: {fleet_health['sites']['by_status'].get('provisioned', 0)} sites")

# Identify unhealthy sites
unhealthy = [s for s in fleet_health['sites'] if s['status'] != 'provisioned']
if unhealthy:
    print(f"⚠️  Cannot deploy to {len(unhealthy)} sites:")
    for site in unhealthy:
        print(f"  - {site['domain']} ({site['status']})")
```

---

## 🤖 Any Agent — General Automation

### Template: Health Check & Auto-Recovery

```python
# When: Hourly monitoring cron
# What: Check all sites, auto-fix common issues
# Result: Self-healing infrastructure

from xcloud_sdk import XCloudAPI
from xcloud_async import AsyncPoller

api = XCloudAPI()
poller = AsyncPoller(api)

sites = api.list_sites(per_page=100)['items']

for site in sites:
    status = api.get_site_status(site['uuid'])
    
    if not status['provisioned']:
        print(f"⚠️  {site['domain']} not ready")
        
        # Wait for provisioning
        try:
            ready = poller.poll_until_ready("site", site['uuid'], timeout=300)
            print(f"✅ {site['domain']} provisioned")
        except TimeoutError:
            print(f"❌ {site['domain']} failed to provision")
            alert_ops(f"Site {site['domain']} stuck in provisioning")
    
    # Check SSL status
    try:
        response = requests.head(f"https://{site['domain']}", timeout=10, verify=True)
        print(f"✅ {site['domain']} SSL OK")
    except requests.exceptions.SSLError:
        print(f"⚠️  {site['domain']} SSL expired or invalid")
        alert_ops(f"SSL issue on {site['domain']}")
    
    # Check HTTP health
    try:
        response = requests.get(f"https://{site['domain']}", timeout=10)
        if response.status_code != 200:
            print(f"⚠️  {site['domain']} returning HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ {site['domain']} unreachable: {e}")
        alert_ops(f"Health check failed: {site['domain']}")
```

---

## 🎯 Next Steps for Agents

1. **Read your scenario** above — it shows exactly what you can build
2. **Import the SDK:** `from xcloud_sdk import XCloudAPI, XCloudDeployer`
3. **Write 3 lines of code** to connect to xCloud
4. **Deploy and iterate** — the API handles the complexity

Any questions? Check `ERROR-HANDLING.md` for common issues.
