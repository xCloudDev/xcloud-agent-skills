# Security policy — xCloud Agent Skills

## Package and trust boundary

This package contains Markdown instructions, public manifests/references, branding assets and `plugins/xcloud/scripts/xcloud.sh`, a Bash/curl REST wrapper. Installation does not execute API requests or grant access. The host agent, connected MCP server and xCloud permissions enforce access; skill prose is not a technical sandbox.

The nine areas cover Deploy, Troubleshoot, Performance, Servers, Sites, WordPress, SSL, Billing and Account. Invoking write operations can change production infrastructure, delete data, interrupt services or spend money. A security review should consider these capabilities—not dismiss them as false positives because the package is mostly documentation.

## Authentication and network destinations

- MCP uses the client-managed connection to `https://app.xcloud.host/mcp`, with OAuth or an authorized bearer token.
- The REST wrapper reads `XCLOUD_API_TOKEN` and defaults to `https://app.xcloud.host/api/v1`.
- `XCLOUD_API_BASE_URL` can override that host. Only the operator may configure a trusted destination; an untrusted host would receive the token.
- HTTPS is required by default. `XCLOUD_ALLOW_INSECURE_HTTP=1` deliberately permits plaintext for local development; never enable it for production credentials or untrusted networks.
- The package ships no credentials, telemetry client or install-time network hook. API requests and authorized deployments themselves do transmit data to xCloud, and deployments fetch the selected repository/build dependencies.

Store credentials in the host secret store/environment, not chat, repository files or reports. Do not ask users to paste production API tokens into a conversation. If secure credential injection is unavailable, explain the limitation and stop authenticated work.

## Executable behavior and limitations

The shell wrapper enforces **GET only, exactly two arguments, and no request body** before network I/O. POST, PUT, PATCH, DELETE, other methods and extra arguments exit 64. There is no write opt-in, environment override, or approval-token bypass. Offline tests assert rejected calls never reach an echo server. Use read-scoped credentials as an independent server-side boundary.

All modifications, deployments and payments must go through the connected xCloud MCP tool with the required user approval and server confirmation. If that operation or confirmation is unavailable, stop and use the dashboard; never bypass the restriction with direct curl, the repository's legacy SDK, another script, or by modifying the wrapper. Historical endpoint examples remain API reference material, not permission to execute REST writes.

The wrapper redacts tokens in stderr and validates team/idempotency headers. The Authorization header is passed in curl arguments, so a trusted, process-isolated runtime is required. Read responses can contain sensitive account data; filter them before sharing. GET-only enforcement is not an endpoint authorization system: use least-privilege read scopes and the correct team. MCP and the service enforce write permissions; this skill does not itself implement the remote confirmation mechanism or guarantee every client supports it.

## Deployment and billing risks

- Git deployment can run repository build/start scripts and replace the site checkout (`git reset --hard` / `git clean -df`). Inspect the target, source and impact first.
- Private repositories need authorized access; never bypass failed detection by forcing an app type.
- Server-wide runtime changes can affect other sites. Disclose this scope.
- Preview/dry run, then obtain approval for concrete creates, retries, redeploys, destructive changes and charges.
- Reuse idempotency keys only for the same supported operation/body. Payments and add-ons do not all support idempotency; investigate uncertain results before retrying.
- Poll async operations and verify the public URL/SSL. A model or API status alone is not proof of a successful deployment.

## File roles

| Files | Purpose |
|---|---|
| `SKILL.md` | Marketplace router and runtime/path setup |
| `README.md`, `CHANGELOG.md`, `LICENSE.txt` | User documentation, history and MIT license |
| `plugins/xcloud/skills/**`, `plugins/xcloud/reference/**` | Capability workflows, endpoint references and safety conventions |
| `plugins/xcloud/scripts/xcloud.sh` | Explicit REST request wrapper described above |
| `plugins/xcloud/resources/**` | Branding assets, not executable code |
| `SHA256SUMS.txt`, `.clawhubsafe` | Integrity manifests; not registry review exemptions |
| Repository `docs/`, `dist/`, `src/`, tests and build scripts | Development/alternate distributions, excluded from the minimal ClawHub artifact |

## Verification and reporting

Verify the downloaded `SHA256SUMS.txt`, inspect the published file list, run offline tests from the source repository, and read the registry's actual review result. Do not treat this policy as a clean verdict or conceal capabilities to avoid review. Extensionless/dotfiles may be omitted by marketplace clients, so the license and checksum manifest also have visible `.txt` forms.

Report reproducible security issues privately to security@xcloud.host without including live credentials. Maintainer: [xCloudDev](https://github.com/xCloudDev).
