# xCloud Agent Scenarios

Real-world use cases for autonomous agents using the xCloud Public API.

---

## 📋 Common Agent Types & Their Use Cases

This document shows scenarios for different agent specializations. Adapt these patterns to your specific agent architecture.

---

## 🚀 Infrastructure & Deployment Automation

### 1. Auto-Provision Staging Sites on Code Push

**Trigger:** Code push to feature branch or PR created  
**Task:** Provision temporary WordPress site for testing  
**Result:** Preview URL auto-posted to PR/commit  

```python
from xcloud_sdk import XCloudAPI, XCloudDeployer

def provision_staging_site(pr_number, server_uuid):
    deployer = XCloudDeployer()
    
    # Create staging site
    site = deployer.create_site_with_poll(
        domain=f"pr-{pr_number}.staging.example.com",
        server_uuid=server_uuid,
        timeout=600
    )
    
    print(f"✅ Staging site ready: https://{site['domain']}")
    return site['domain']

# Called on PR creation
staging_url = provision_staging_site(
    pr_number=42,
    server_uuid="your-server-uuid"
)
# Post to GitHub/GitLab as comment
```

### 2. Deploy Containerized Applications

**Trigger:** New container image pushed  
**Task:** Deploy to xCloud-hosted server  
**Result:** Application running and verified healthy  

```python
from xcloud_sdk import XCloudAPI
from xcloud_async import AsyncPoller

def deploy_container(site_uuid, docker_image, docker_compose):
    api = XCloudAPI()
    poller = AsyncPoller(api)
    
    # Get SSH config
    ssh_config = api.get_site_ssh_config(site_uuid)
    
    # Deploy via SSH
    deploy_via_ssh(ssh_config, docker_image, docker_compose)
    
    # Verify health
    try:
        site = poller.poll_until_ready("site", site_uuid)
        print(f"✅ Container deployed: {site['domain']}")
    except TimeoutError:
        print(f"❌ Deployment timeout")
        return False
    
    return True
```

### 3. Automated Backup Before Deployments

**Trigger:** Deployment pipeline starts  
**Task:** Create backup of all production sites  
**Result:** Safe rollback point established  

```python
from xcloud_sdk import XCloudDeployer

def backup_before_deployment(server_uuid=None):
    deployer = XCloudDeployer()
    
    # Backup all sites (optionally filtered by server)
    results = deployer.backup_all_sites(server_uuid=server_uuid)
    
    # Report status
    successful = [r for r in results if r['status'] == 'backup_triggered']
    failed = [r for r in results if r['status'] == 'backup_failed']
    
    print(f"✅ Backups triggered: {len(successful)}")
    if failed:
        print(f"⚠️  Failed: {len(failed)}")
    
    return len(failed) == 0
```

### 4. Build System Status Dashboard

**Trigger:** CI/CD pipeline or monitoring cron  
**Task:** Collect real-time infrastructure health  
**Result:** Status page or dashboard data  

```python
from xcloud_sdk import XCloudDeployer
import json

def get_infrastructure_status():
    deployer = XCloudDeployer()
    health = deployer.get_fleet_health()
    
    status = {
        "timestamp": health['timestamp'],
        "servers": {
            "total": health['servers']['total'],
            "healthy": health['servers']['provisioned'],
            "utilization": health['servers']['provisioned'] / max(health['servers']['total'], 1)
        },
        "sites": {
            "total": health['sites']['total'],
            "by_type": health['sites']['by_type'],
            "by_status": health['sites']['by_status']
        }
    }
    
    return status

# Use in dashboard or status page
status = get_infrastructure_status()
print(json.dumps(status, indent=2))
```

---

## 📊 Infrastructure Monitoring & Analysis

### 1. Fleet Capacity Planning

**Trigger:** Weekly/monthly analysis  
**Task:** Analyze server utilization and costs  
**Result:** Recommendations for consolidation/scaling  

```python
from xcloud_sdk import XCloudAPI

def analyze_capacity():
    api = XCloudAPI()
    servers = api.list_servers(per_page=100)['items']
    
    capacity_report = []
    
    for server in servers:
        # Get all sites on this server
        sites = api.list_sites(server_uuid=server['uuid'])['items']
        
        # Calculate utilization
        site_count = len(sites)
        utilization = "high" if site_count > 20 else "medium" if site_count > 5 else "low"
        
        capacity_report.append({
            "server": server['name'],
            "location": server['location'],
            "sites": site_count,
            "utilization": utilization,
            "recommendation": "consolidate" if site_count < 3 else "healthy" if site_count > 15 else "monitor"
        })
    
    # Generate report
    for item in capacity_report:
        print(f"{item['server']}: {item['sites']} sites ({item['utilization']}) → {item['recommendation']}")
    
    return capacity_report
```

### 2. Disaster Recovery Planning

**Trigger:** Weekly/quarterly review  
**Task:** Verify all sites have recent backups  
**Result:** DR readiness report  

```python
from xcloud_sdk import XCloudAPI
from datetime import datetime, timedelta

def verify_backup_readiness():
    api = XCloudAPI()
    sites = api.list_sites(per_page=100)['items']
    
    dr_status = {
        "verified": [],
        "stale": [],
        "missing": []
    }
    
    for site in sites:
        backups = api.get_site_backups(site['uuid'])
        
        if not backups:
            dr_status['missing'].append(site['name'])
        else:
            # Check age of most recent backup
            latest = backups[0]  # Most recent first
            backup_age = datetime.fromisoformat(latest['created_at'].replace('Z', '+00:00'))
            days_old = (datetime.now(backup_age.tzinfo) - backup_age).days
            
            if days_old < 7:
                dr_status['verified'].append((site['name'], days_old))
            else:
                dr_status['stale'].append((site['name'], days_old))
    
    # Report
    print(f"✅ Verified: {len(dr_status['verified'])} sites")
    print(f"⚠️  Stale: {len(dr_status['stale'])} sites")
    print(f"❌ Missing: {len(dr_status['missing'])} sites")
    
    return dr_status
```

### 3. Cost Optimization Analysis

**Trigger:** Monthly cost review  
**Task:** Identify inefficient resource usage  
**Result:** Cost reduction recommendations  

```python
from xcloud_sdk import XCloudAPI

def analyze_costs():
    api = XCloudAPI()
    servers = api.list_servers(per_page=100)['items']
    
    cost_analysis = []
    
    for server in servers:
        sites = api.list_sites(server_uuid=server['uuid'])['items']
        site_count = len(sites)
        
        # Simple cost model (adjust to your pricing)
        # Example: $20/month base + $1 per site
        monthly_cost = 20 + (site_count * 1)
        cost_per_site = monthly_cost / max(site_count, 1)
        
        # Identify opportunities
        if site_count < 3:
            recommendation = "consolidate_to_other_server"
        elif cost_per_site > 5:
            recommendation = "upgrade_to_larger_server"
        else:
            recommendation = "healthy"
        
        cost_analysis.append({
            "server": server['name'],
            "sites": site_count,
            "monthly_cost": monthly_cost,
            "cost_per_site": round(cost_per_site, 2),
            "recommendation": recommendation
        })
    
    # Sort by cost efficiency
    cost_analysis.sort(key=lambda x: x['cost_per_site'], reverse=True)
    
    for item in cost_analysis:
        print(f"{item['server']}: ${item['monthly_cost']}/mo ({item['sites']} sites) → {item['recommendation']}")
    
    return cost_analysis
```

---

## 🛡️ Security & Monitoring

### 1. Site Health Checks with Auto-Recovery

**Trigger:** Hourly monitoring cron  
**Task:** Check all sites are responding  
**Result:** Alert if unhealthy, auto-fix if possible  

```python
from xcloud_sdk import XCloudAPI
from xcloud_async import AsyncPoller
import requests

def monitor_site_health():
    api = XCloudAPI()
    poller = AsyncPoller(api)
    
    sites = api.list_sites(per_page=100)['items']
    issues = []
    
    for site in sites:
        # Check provisioning status
        status = api.get_site_status(site['uuid'])
        
        if not status.get('provisioned'):
            print(f"⏳ {site['domain']}: Still provisioning")
            try:
                ready = poller.poll_until_ready("site", site['uuid'], timeout=300)
                print(f"✅ {site['domain']}: Now ready")
            except TimeoutError:
                issues.append((site['domain'], "timeout_provisioning"))
            continue
        
        # Check HTTP response
        try:
            response = requests.head(f"https://{site['domain']}", timeout=10, allow_redirects=True)
            if response.status_code == 200:
                print(f"✅ {site['domain']}: Healthy")
            else:
                print(f"⚠️  {site['domain']}: HTTP {response.status_code}")
                issues.append((site['domain'], f"http_{response.status_code}"))
        except requests.exceptions.RequestException as e:
            print(f"❌ {site['domain']}: Unreachable")
            issues.append((site['domain'], "unreachable"))
    
    return issues
```

### 2. SSL Certificate Monitoring

**Trigger:** Weekly check  
**Task:** Verify SSL certificates  
**Result:** Alert if expired or expiring soon  

```python
from xcloud_sdk import XCloudAPI
import ssl
import socket
from datetime import datetime, timedelta

def check_ssl_expiry():
    api = XCloudAPI()
    sites = api.list_sites(per_page=100)['items']
    
    ssl_status = []
    
    for site in sites:
        domain = site.get('domain') or site.get('name')
        
        try:
            # Get SSL certificate
            cert = ssl.create_default_context().check_hostname = False
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            
            with socket.create_connection((domain, 443), timeout=5) as sock:
                with context.wrap_socket(sock, server_hostname=domain) as ssock:
                    cert = ssock.getpeercert()
                    
                    # Parse expiry date
                    not_after = cert['notAfter']
                    # Parse SSL date format
                    expiry = datetime.strptime(not_after, '%b %d %H:%M:%S %Y %Z')
                    days_left = (expiry - datetime.now()).days
                    
                    if days_left < 0:
                        status = "expired"
                    elif days_left < 30:
                        status = "expiring_soon"
                    else:
                        status = "valid"
                    
                    ssl_status.append({
                        "domain": domain,
                        "expiry": not_after,
                        "days_left": days_left,
                        "status": status
                    })
                    
                    print(f"{domain}: {status} ({days_left} days)")
        
        except Exception as e:
            print(f"❌ {domain}: SSL check failed ({e})")
            ssl_status.append({
                "domain": domain,
                "status": "check_failed",
                "error": str(e)
            })
    
    return ssl_status
```

---

## 📝 Content & Site Operations

### 1. Multi-Site Bulk Operations

**Trigger:** Admin request or scheduled task  
**Task:** Apply changes across multiple sites  
**Result:** Bulk update completed safely  

```python
from xcloud_sdk import XCloudAPI

def bulk_purge_cache(server_uuid=None, domain_filter=None):
    """Purge cache on all sites matching criteria"""
    api = XCloudAPI()
    
    # Get matching sites
    if server_uuid:
        sites = api.list_sites(server_uuid=server_uuid)['items']
    else:
        sites = api.list_sites()['items']
    
    # Apply filter if provided
    if domain_filter:
        sites = [s for s in sites if domain_filter in s.get('domain', '')]
    
    # Bulk purge
    results = []
    for site in sites:
        try:
            api.purge_cache(site['uuid'])
            results.append({"domain": site['domain'], "status": "purged"})
            print(f"✅ {site['domain']}: Cache purged")
        except Exception as e:
            results.append({"domain": site['domain'], "status": "failed", "error": str(e)})
            print(f"❌ {site['domain']}: {e}")
    
    return results
```

### 2. Site Health Metrics for Operations

**Trigger:** Team standup or reporting  
**Task:** Summarize site health  
**Result:** Readiness matrix  

```python
from xcloud_sdk import XCloudDeployer

def site_readiness_report():
    """Generate site readiness for operations"""
    deployer = XCloudDeployer()
    health = deployer.get_fleet_health()
    
    ready_for_ops = health['sites']['by_status'].get('provisioned', 0)
    total_sites = health['sites']['total']
    
    print("=" * 50)
    print("SITE READINESS REPORT")
    print("=" * 50)
    print(f"Total Sites: {total_sites}")
    print(f"Ready for Deployment: {ready_for_ops}/{total_sites}")
    print(f"Readiness: {round(100 * ready_for_ops / max(total_sites, 1))}%")
    print()
    print("By Type:")
    for site_type, count in health['sites']['by_type'].items():
        print(f"  - {site_type}: {count}")
    print("=" * 50)
    
    return {
        "total": total_sites,
        "ready": ready_for_ops,
        "readiness_percent": round(100 * ready_for_ops / max(total_sites, 1))
    }
```

---

## 🛠️ General Patterns for Any Agent

### Error Recovery Template

```python
from xcloud_sdk import XCloudAPI
from xcloud_async import AsyncPoller, RateLimitManager

def safe_api_operation(operation, max_retries=3):
    """Wrap API operations with retry logic"""
    api = XCloudAPI()
    poller = AsyncPoller(api)
    limiter = RateLimitManager()
    
    for attempt in range(max_retries):
        try:
            # Check rate limit
            limiter.wait_if_needed()
            limiter.record_request()
            
            # Execute operation
            result = operation(api)
            return result
        
        except Exception as e:
            if attempt < max_retries - 1:
                wait_time = 2 ** attempt  # Exponential backoff
                print(f"Attempt {attempt + 1} failed, retrying in {wait_time}s...")
                import time
                time.sleep(wait_time)
            else:
                print(f"Operation failed after {max_retries} attempts")
                raise
```

### State Persistence Template

```python
from xcloud_async import StateManager

def track_long_running_operation(op_id, operation_func):
    """Execute operation with persistent state tracking"""
    state = StateManager("xcloud-ops.json")
    
    # Check if already started
    existing = state.get(op_id)
    if existing and existing.get('status') == 'completed':
        print(f"Operation {op_id} already completed")
        return existing.get('result')
    
    # Start operation
    state.set(op_id, {
        'status': 'started',
        'started_at': datetime.now().isoformat()
    })
    
    try:
        # Execute
        result = operation_func()
        
        # Mark complete
        state.update(op_id, 
            status='completed',
            result=result,
            completed_at=datetime.now().isoformat()
        )
        
        return result
    
    except Exception as e:
        state.update(op_id,
            status='failed',
            error=str(e),
            failed_at=datetime.now().isoformat()
        )
        raise
```

---

## Summary

These scenarios demonstrate common patterns for autonomous agents:

- **Infrastructure**: Provisioning, deployment, backups
- **Monitoring**: Health checks, capacity planning, cost analysis
- **Security**: SSL monitoring, site verification
- **Operations**: Bulk operations, status reporting

Adapt these patterns to your specific agent architecture and requirements.

For detailed error recovery patterns, see `ERROR-HANDLING.md`  
For security best practices, see `SECURITY.md`
