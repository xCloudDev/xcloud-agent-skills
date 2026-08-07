# Agent Plugins distribution

This directory builds the portable [Agent Plugins 1.0.0](https://agent-plugins.org/) package for xCloud.

## Build

```bash
python3 dist/agent-plugin/build.py
python3 dist/agent-plugin/validate.py
```

The generated package is `dist/agent-plugin/xcloud/` and contains:

- root `plugin.json` metadata
- root `mcp.json` for the xCloud Streamable HTTP MCP endpoint
- five immediate Agent Skills under `skills/`
- skill-local references and REST fallback wrappers

The builder copies shared files into each skill because Agent Skills file references are relative to the skill root. Each generated skill tells the agent to resolve `SKILL_ROOT` from the loaded `SKILL.md` before executing its wrapper, so shell commands work from unrelated project directories.

## Local Codex installation

The repository's root marketplace remains Claude Code-specific. This directory has a separate adapter for testing the portable package with Codex:

```bash
codex plugin marketplace add ./dist/agent-plugin
codex plugin add xcloud@xcloud-agent-plugins
codex plugin list
```

The GitHub release asset `xcloud-agent-plugin.zip` is the package for universal-directory submission and clients that support local imports.

## OAuth

OAuth authorization is client-managed under Agent Plugins 1.0.0. The package contains no credentials.

Production currently returns `x-amzn-remapped-www-authenticate` instead of `WWW-Authenticate` on an unauthenticated MCP `401`. Clients that probe the OAuth well-known URLs directly work; strict clients may need the MCP URL added manually until [xCloud#5662](https://github.com/xCloudDev/xCloud/issues/5662) is corrected.

## Validate

```bash
python3 dist/agent-plugin/build.py
python3 dist/agent-plugin/validate.py
for skill in dist/agent-plugin/xcloud/skills/*; do
  npx --yes skills-ref validate "$skill"
done
```

CI also validates both manifests against the official Agent Plugins schemas, rejects generated drift including untracked files, ShellChecks generated wrappers, tests foreign-working-directory execution, and checks ZIP integrity.
