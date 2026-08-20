# Security Policy - xCloud Agent Skills

## Overview

This repository packages the official xCloud Public API skills for AI agents. The ClawHub package contains Markdown skill instructions, marketplace metadata, runtime references, assets, and a small shell wrapper. Repository-only docs, generated builds, legacy source helpers, and smoke tests are excluded from the marketplace artifact.

The package does not include real API tokens and does not run API calls during installation. Network requests occur only when a user or agent explicitly invokes an xCloud skill with `XCLOUD_API_TOKEN` configured in the runtime.

## Why ClawHub May Flag This Package

ClawHub's scanner may flag this package because:

1. It documents API token setup and includes placeholder environment variables such as `XCLOUD_API_TOKEN`.
2. It includes shell examples and a curl-based helper script for the xCloud Public API.
3. It contains security documentation with token-pattern grep examples.

Verdict: false positive when the package contains no real credentials. The token strings are placeholders or pattern examples, not secrets.

## File-by-File Analysis

| Path | Purpose | Security note |
|---|---|---|
| `SKILL.md` | Root marketplace skill summary for ClawHub and skills.mp.com indexing | Documentation only; no executable code |
| `README.md` | Public install, setup, support, and xCloud positioning | Documentation only; token examples use placeholders |
| `CHANGELOG.md` | Release history | Documentation only |
| `LICENSE` | MIT license | Documentation only |
| `.clawhubinfo.json` | ClawHub listing metadata | Public metadata only |
| `.claude-plugin/marketplace.json` | Claude plugin marketplace metadata | Public metadata only |
| `plugins/xcloud/.claude-plugin/plugin.json` | Plugin manifest | Public metadata only |
| `plugins/xcloud/skills/*/SKILL.md` | Domain skill instructions | Documentation and command examples; no credentials |
| `plugins/xcloud/reference/*.md` | Shared auth and API conventions | Documentation only; token values are placeholders |
| `plugins/xcloud/scripts/xcloud.sh` | Explicit API wrapper used by the skills | Reads `XCLOUD_API_TOKEN`; does not store or exfiltrate tokens |
| `docs/**`, `dist/**`, `src/**`, `WORK_STEP_GUIDES.md`, test scripts | Repository-only development and support material | Excluded from the ClawHub package by `.clawhubignore` |

## What This Package Does

- Teaches agents how to route xCloud operations into focused domains.
- Provides a shared wrapper for explicit xCloud Public API calls.
- Documents safe token setup, scoped tokens, pagination, rate limits, and async operations.
- Points users to the official xCloud website, dashboard, API docs, and repository.

## What This Package Does Not Do

- Does not collect credentials.
- Does not include real API tokens.
- Does not make unauthorized network requests.
- Does not run API calls on install.
- Does not send tokens to third-party services.
- Does not modify servers or sites unless a user explicitly asks an agent to invoke a write operation with a configured xCloud token.

## Credential Handling

The package expects users to create an xCloud API token at:

https://app.xcloud.host/settings/api-tokens

Tokens should be supplied through the runtime environment:

```bash
export XCLOUD_API_TOKEN="your-token-here"
```

Recommended practices:

- Use scoped tokens instead of `*` for routine automation.
- Store tokens in the host or agent runtime secret store.
- Rotate tokens regularly.
- Revoke exposed tokens immediately from the xCloud dashboard.
- Avoid logging raw command output when it could include credentials.

## Verification Instructions

Run these checks before publishing:

```bash
# Confirm required marketplace files exist.
test -f SKILL.md
test -f README.md
test -f CHANGELOG.md
test -f LICENSE
test -f SECURITY.md
test -f .clawhubignore
test -f .clawhubsafe

# Confirm version alignment.
VERSION=$(awk '/^version:/{print $2; exit}' SKILL.md)
test -n "$VERSION"
grep "version-$VERSION" README.md
grep "$VERSION" .clawhubinfo.json .claude-plugin/marketplace.json plugins/xcloud/.claude-plugin/plugin.json CHANGELOG.md .clawhubsafe

# Look for common real-secret patterns.
git ls-files -z | grep -zv -E '^(README.md|SECURITY.md)$' \
  | xargs -0 grep -E "(github_pat_|sk-[A-Za-z0-9]{20,}|[0-9]+\\|[A-Za-z0-9]{40,})" || true

# Verify checksums.
sha256sum -c .clawhubsafe
```

Expected result: required files exist, versions match, no real credentials are found, and all checksums pass.

## Reporting Security Issues

Report xCloud security issues privately:

- Email: security@xcloud.host
- Website: https://xcloud.host

Please include the affected file or endpoint, reproduction steps, impact, and suggested mitigation when available.

## Maintainer

xCloudDev - https://github.com/xCloudDev
