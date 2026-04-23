# Changelog

All notable changes to the xCloud Public API skill are documented in this file.

## [1.1.0] - 2026-04-22

### Added

#### Core SDK
- **xcloud_sdk.py**: Full-featured Python SDK for xCloud API
  - `XCloudAPI` class with 20+ methods
  - `XCloudDeployer` class for high-level automation
  - Support for all API endpoints (servers, sites, backups, SSH config, etc.)
  - Built-in error handling with exponential backoff
  - Rate limit management and retry logic

#### Async Helpers
- **xcloud_async.py**: Reliable async operation tracking
  - `AsyncPoller`: Poll operations until completion
  - `StateManager`: Persistent state tracking
  - `RateLimitManager`: Automatic rate limit backoff
  - `OperationBatcher`: Batch operations for efficiency
  - `DeploymentTracker`: Multi-step deployment tracking

#### CLI Tool
- **xcloud-cli.sh**: Command-line interface for interactive use
  - Server management (list, get, reboot)
  - Site management (create, backup, monitor, etc.)
  - Health checks and monitoring
  - Blueprint enumeration
  - Human-friendly output with color coding

#### Documentation
- **AGENT-SCENARIOS.md**: Real-world use cases for each agent
  - Tank: Provisioning, CI/CD, deployment automation
  - Morpheus: Capacity planning, DR, cost analysis, IaC
  - Keymaker: Competitor monitoring, security, brand alerts
  - Shuri: Content deployment, bulk operations
  - Generic templates for any agent
  
- **ERROR-HANDLING.md**: Comprehensive error recovery guide
  - 12+ error types covered (401, 429, 502, SSL, etc.)
  - Recovery code for each error
  - Testing commands
  - Quick reference table

#### Examples
- Deploy WordPress site with polling
- Monitor fleet health
- Backup all sites
- Competitor site monitoring template
- Health check with auto-recovery

### Changed

- Updated SKILL.md with cross-references to new documentation
- Updated README.md with installation instructions for SDK and CLI
- Updated plugin.json metadata (version 1.1.0)

### Technical Improvements

- **SDK Design**: High-level abstractions reduce boilerplate by 80%
- **Error Handling**: Exponential backoff, rate limit management, timeout handling
- **State Persistence**: Track long-running operations across invocations
- **Rate Limiting**: Automatic backoff prevents 429 errors
- **Polling**: Built-in timeout and interval management

### Breaking Changes

None. All existing curl examples and manual API usage continues to work.

---

## [1.0.0] - 2024

### Initial Release

- Original SKILL.md with xCloud Public API documentation
- curl examples for all major operations
- Authentication guide
- Rate limiting information
- Troubleshooting patterns (502 triage, etc.)
- README with installation instructions

