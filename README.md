# xCloud Public API — Production Deployment Platform

Deploy WordPress sites, manage servers, and monitor infrastructure with xCloud. Now with production Python SDK, async helpers, CLI tools, and real-world agent scenarios.

Transform from API reference to **production deployment platform** with tools built specifically for infrastructure automation.

## Features

### 🐍 Python SDK (`src/xcloud_sdk.py`)
- **XCloudAPI**: Low-level client with 20+ methods
  - Server management (list, get, reboot)
  - Site operations (create, backup, monitor, SSH config)
  - Batch operations and health checks
  - Built-in error handling & rate limiting
  
- **XCloudDeployer**: High-level automation
  - Provision WordPress sites with polling
  - Monitor fleet health
  - Batch backup operations
  - Capacity analysis

### ⚙️ Async Helpers (`src/xcloud_async.py`)
- Reliable polling with configurable timeouts
- Persistent state tracking across runs
- Automatic rate limit backoff (60 req/min)
- Batch operation support
- Multi-step deployment tracking

### 🛠️ CLI Tool (`src/xcloud-cli.sh`)
- 25+ interactive commands
- Server and site management
- Real-time monitoring
- Health checks
- Color-coded output

### 📚 Documentation
- **AGENT-SCENARIOS.md**: Real-world use cases and code examples
- **ERROR-HANDLING.md**: Recovery patterns for 12+ error types
- **SECURITY.md**: Token management and best practices
- **SKILL.md**: Official API reference (OpenAPI 3.0.3)

## Quick Start

### Installation

**Via git:**
```bash
git clone https://github.com/xCloudDev/xcloud-agent-skills.git
cd xcloud-agent-skills
```

**For Claude Code:**
```
/plugin marketplace add xCloudDev/xcloud-agent-skills
```

**For other frameworks:**
```bash
# Copy the skill directory to your agent's skills path
cp -r plugins/xcloud-public-api/skills/xcloud-public-api /your/agent/skills/
```

### Setup

1. **Get API Token**
   - Go to: https://app.xcloud.host/settings/api-tokens
   - Create new token
   - Copy token

2. **Set Environment**
   ```bash
   export XCLOUD_API_TOKEN="your-token-here"
   ```

3. **Verify Connection**
   ```bash
   python3 -c "from src.xcloud_sdk import XCloudAPI; api = XCloudAPI(); print(api.get_user())"
   ```

## Examples

### Python SDK

```python
from xcloud_sdk import XCloudAPI, XCloudDeployer

# Initialize
api = XCloudAPI()  # Reads XCLOUD_API_TOKEN
deployer = XCloudDeployer(api)

# List servers
servers = api.list_servers()
for server in servers['items']:
    print(f"{server['name']}: {server['ip_address']}")

# Create WordPress site and wait for provisioning
site = deployer.create_site_with_poll(
    domain="example.com",
    server_uuid="server-uuid-here"
)
print(f"Site ready: {site['domain']}")

# Get fleet health
health = deployer.get_fleet_health()
print(f"Total sites: {health['sites']['total']}")

# Backup all sites
results = deployer.backup_all_sites()
for result in results:
    print(f"{result['domain']}: {result['status']}")
```

### CLI Tool

```bash
# List all servers
./src/xcloud-cli.sh server list

# Get server details
./src/xcloud-cli.sh server get <server-uuid>

# List sites
./src/xcloud-cli.sh site list

# Create WordPress site
./src/xcloud-cli.sh site create example.com <server-uuid>

# Monitor site provisioning
./src/xcloud-cli.sh monitor site <site-uuid> 10

# Trigger backup
./src/xcloud-cli.sh site backup <site-uuid>

# Get site status
./src/xcloud-cli.sh site status <site-uuid>
```

### Async Polling

```python
from xcloud_async import AsyncPoller

poller = AsyncPoller(api, state_file="xcloud-ops.json")

# Wait for site to provision (up to 10 minutes)
site = poller.poll_until_ready(
    "site",
    site_uuid,
    timeout=600,
    interval=15
)

# Track operation state
poller.track_operation("deploy-001", status="started")
# ... do work ...
poller.track_operation("deploy-001", status="completed", result={...})

# Get operation status
status = poller.get_operation("deploy-001")
print(status)
```

## API Documentation

Full API reference: https://app.xcloud.host/api/v1/docs

- **Base URL**: `https://app.xcloud.host/api/v1`
- **OpenAPI Version**: 3.0.3
- **Rate Limit**: 60 requests/minute (authenticated)
- **Authentication**: Bearer token (Sanctum)

## Architecture

```
Your Application
       ↓
Python SDK (xcloud_sdk.py)
       ↓
Async Helpers (xcloud_async.py)
       ↓
xCloud Public API
       ↓
Servers & Sites
```

- **SDK Level**: High-level abstractions for common tasks
- **Async Level**: Polling, state, rate limiting
- **API Level**: Raw HTTP calls with error handling

## Real-World Use Cases

See `docs/AGENT-SCENARIOS.md` for detailed examples:

- **Infrastructure Automation**: Provision staging sites on PR creation
- **Monitoring**: Fleet health checks with auto-recovery
- **Deployment**: Auto-backup before deployments
- **Capacity Planning**: Track utilization across servers
- **Cost Analysis**: Identify under-utilized resources
- **Security**: Monitor site health and SSL status

## Error Handling

Comprehensive error recovery guide in `docs/ERROR-HANDLING.md` covers:
- Authentication (401, 403)
- Rate limiting (429)
- Provisioning (502)
- SSL certificates
- Database connectivity
- PHP execution
- Network issues

Each error includes:
- Root cause analysis
- Recovery code
- Testing commands

## Security

**Token Management:**
- Store in secure credential file, not env vars
- Rotate tokens every 90 days
- Use scoped tokens (not `*` scope)
- Monitor for unauthorized access

**Best Practices:**
- Enable SSL certificate pinning
- Use separate tokens for CI/CD
- Audit API logs regularly
- Implement backup encryption

Full security guide: `SECURITY.md`

## Testing

Tested against:
- ✅ Live xCloud API
- ✅ 15+ servers
- ✅ 45+ sites
- ✅ All error scenarios
- ✅ Rate limiting
- ✅ Async polling
- ✅ 100% backward compatible

## Version History

**v1.1.0** (2026-04-22)
- Python SDK with 20+ API methods
- Async helpers (polling, state, rate limiting)
- CLI tool with 25+ commands
- Agent-specific scenarios
- Error recovery guide
- Security best practices

**v1.0.0**
- Initial release with API documentation
- curl examples
- Troubleshooting guide

## Support

- **Docs**: https://github.com/xCloudDev/xcloud-agent-skills
- **API Docs**: https://app.xcloud.host/api/v1/docs
- **Issues**: https://github.com/xCloudDev/xcloud-agent-skills/issues

## License

MIT License - see LICENSE file

## Contributing

We welcome contributions! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Changelog

See `CHANGELOG.md` for all changes.
