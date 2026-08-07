# Agent Plugins distribution

This directory contains the portable [Agent Plugins 1.0.0](https://agent-plugins.org/) package for xCloud.

## Build

```bash
python3 dist/agent-plugin/build.py
```

The generated package is at `dist/agent-plugin/xcloud/`. Load that directory in an Agent Plugins client.

The package contains:

- `plugin.json` for portable identity and version metadata
- `mcp.json` for the xCloud Streamable HTTP MCP endpoint
- five Agent Skills under `skills/`
- skill-local references and the REST fallback wrapper

The builder copies shared files into each skill because Agent Skills file references are relative to the skill root. It also removes the Claude-specific `${CLAUDE_PLUGIN_ROOT}` dependency from the portable output.

OAuth authorization is client-managed under Agent Plugins 1.0.0. A compatible client discovers authorization from `https://app.xcloud.host/mcp`.

## Validate

```bash
python3 dist/agent-plugin/build.py
npx --yes skills-ref validate dist/agent-plugin/xcloud/skills/account
```

CI validates both manifests against the official Agent Plugins schemas and validates every generated skill.
