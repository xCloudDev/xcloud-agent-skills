#!/usr/bin/env python3
"""Build the portable Agent Plugins 1.0.0 distribution."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "plugins" / "xcloud"
OUT = ROOT / "dist" / "agent-plugin" / "xcloud"
AREAS = ("servers", "sites", "wordpress", "ssl", "account")
SHARED_REFERENCES = ("auth.md", "conventions.md", "mcp.md")
PLUGIN_SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
MCP_SCHEMA = "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json"

PORTABLE_TOKEN_SECTION = """## Setting the token in a portable client

**Step 1 — generate the token.** In the xCloud dashboard, open **Profile → API
Tokens → Generate New Token**. Select the narrowest required scopes and copy the
token immediately.

**Step 2 — store the token.** Put `XCLOUD_API_TOKEN` in the client environment or
its secure secret store. Do not put a token in `plugin.json`, `mcp.json`, a skill
file, source control, or chat. Set `XCLOUD_API_BASE_URL` only for a non-default
xCloud host.

For a temporary terminal session:

```bash
export XCLOUD_API_TOKEN="..."
export XCLOUD_API_BASE_URL="https://app.xcloud.host"
```

Use the client's documented environment or secret configuration for persistent
storage. Restart the client if it does not reload environment changes.

"""

PORTABLE_MCP_CONNECTING_SECTION = """## Connecting

This package declares the `xcloud` Streamable HTTP server in its root `mcp.json`.
A compatible Agent Plugins client loads that connection and manages OAuth. If
the client requests authorization, grant **Read** (`mcp:read`) or **Read & write**
(`mcp:write`) for the required task.

If automatic authorization discovery fails, open the client's MCP or plugin
settings and connect `https://app.xcloud.host/mcp` manually. For headless use,
store an API token with `mcp:invoke` and the required granular scopes in the
client's secret store. Do not add credentials to the portable package.

Access is team-scoped. Verify the connection with `user_show` ("who am I on
xCloud?").

"""


PORTABLE_WRAPPER_TOKEN_SECTION = """Step 2 — Store it in the agent runtime:
  Put XCLOUD_API_TOKEN in the runtime environment or secure secret store.
  Optionally set XCLOUD_API_BASE_URL for a non-default xCloud host.
  Restart the runtime if it does not reload environment changes.

Do not paste a production token into chat or commit it to source control.
See the xCloud authentication reference for client-specific storage guidance.
"""


def portable_text(text: str, domain_files: set[str], area: str) -> str:
    """Rewrite client-specific source text for a portable skill package."""
    if area == "servers":
        text = text.replace(
            "see `xcloud:sites` (`reference/cron-jobs.md`).",
            "load the `sites` skill.",
        )
        text = text.replace(
            "via xcloud:sites (reference/git.md)",
            "with the `sites` skill",
        )
    elif area == "sites":
        text = text.replace(
            "`xcloud:servers` (`reference/cron-jobs.md`).",
            "the `servers` skill.",
        )

    text = re.sub(
        r'\\?"\$\{CLAUDE_PLUGIN_ROOT\}\\?"/scripts/xcloud\.sh',
        '"$SKILL_ROOT/scripts/xcloud.sh"',
        text,
    )
    text = text.replace(
        "${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh",
        "$SKILL_ROOT/scripts/xcloud.sh",
    )

    for filename in SHARED_REFERENCES:
        text = re.sub(
            rf'\\?"\$\{{CLAUDE_PLUGIN_ROOT\}}\\?"/reference/{re.escape(filename)}',
            f"references/shared/{filename}",
            text,
        )
        text = text.replace(
            f"${{CLAUDE_PLUGIN_ROOT}}/reference/{filename}",
            f"references/shared/{filename}",
        )

    for filename in sorted(domain_files, key=len, reverse=True):
        text = text.replace(f"reference/{filename}", f"references/domain/{filename}")
    for filename in SHARED_REFERENCES:
        text = text.replace(f"reference/{filename}", f"references/shared/{filename}")
    text = text.replace("`reference/`", "`references/domain/`")
    text = text.replace("`scripts/xcloud.sh`", "`$SKILL_ROOT/scripts/xcloud.sh`")
    text = text.replace(
        "Shared by every `xcloud-*` domain skill.",
        "Shared by every xCloud domain skill.",
    )

    text = text.replace(
        "`mcp__xcloud__*` tools",
        "tools from the MCP server named `xcloud`",
    )
    text = re.sub(
        r"`mcp__xcloud__([a-z0-9_*]+)`",
        r"`\1` MCP",
        text,
    )
    text = text.replace("`xcloud:*` domain skill", "xCloud domain skill")
    text = re.sub(
        r"(?m)_via [^\n]+_",
        lambda match: re.sub(
            r"xcloud:([a-z-]+)", r"xCloud/\1", match.group(0)
        ),
        text,
    )
    text = re.sub(
        r"\b([Tt]he) +`xcloud:([a-z-]+)`",
        r"\1 `\2` skill",
        text,
    )
    text = re.sub(r"`xcloud:([a-z-]+)`", r"the `\1` skill", text)
    text = re.sub(r"xcloud:([a-z-]+)", r"\1", text)

    text = re.sub(
        r"Step 2 — Store it persistently for Claude Code:\n.*?"
        r"\(and the claude\.ai-app alternative\)\.\n",
        PORTABLE_WRAPPER_TOKEN_SECTION,
        text,
        flags=re.S,
    )

    text = re.sub(
        r"## Setting the token \(Claude Code / CLI\)\n.*?(?=> \*\*Browser/chat-only agents:\*\*)",
        PORTABLE_TOKEN_SECTION,
        text,
        flags=re.S,
    )
    text = re.sub(
        r"## Connecting \(tell the user, per client\)\n.*?(?=## REST-only operations)",
        PORTABLE_MCP_CONNECTING_SECTION,
        text,
        flags=re.S,
    )

    text = text.replace(
        "# Shared by every xcloud-* domain skill. Skills invoke it via\n"
        "# \"$SKILL_ROOT/scripts/xcloud.sh\" — one copy, no per-skill duplication.\n",
        "# Bundled with this portable skill. Resolve SKILL_ROOT from its SKILL.md.\n"
        "# Invoke the wrapper as \"$SKILL_ROOT/scripts/xcloud.sh\".\n",
    )
    return text


def add_skill_root_contract(text: str) -> str:
    marker = '```bash\nXC="$SKILL_ROOT/scripts/xcloud.sh"\n```'
    replacement = """Resolve the absolute directory that contains this `SKILL.md` before running
shell commands. Do not resolve scripts from the user's current working directory:

```bash
SKILL_ROOT="/absolute/path/to/this/skill"
XC="$SKILL_ROOT/scripts/xcloud.sh"
```"""
    if marker not in text:
        raise ValueError("skill wrapper marker was not generated")
    return text.replace(marker, replacement, 1)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    claude_manifest = json.loads((SOURCE / ".claude-plugin" / "plugin.json").read_text())
    write_json(
        OUT / "plugin.json",
        {
            "$schema": PLUGIN_SCHEMA,
            **claude_manifest,
            "repository": "https://github.com/xCloudDev/xcloud-agent-skills",
        },
    )
    write_json(
        OUT / "mcp.json",
        {
            "$schema": MCP_SCHEMA,
            "mcpServers": {
                "xcloud": {
                    "type": "streamable-http",
                    "url": "https://app.xcloud.host/mcp",
                }
            },
        },
    )

    for area in AREAS:
        source_skill = SOURCE / "skills" / area
        target_skill = OUT / "skills" / area
        shared_refs = target_skill / "references" / "shared"
        domain_refs = target_skill / "references" / "domain"
        scripts = target_skill / "scripts"
        shared_refs.mkdir(parents=True)
        scripts.mkdir(parents=True)

        source_domain_refs = source_skill / "reference"
        domain_files = (
            {path.name for path in source_domain_refs.glob("*.md")}
            if source_domain_refs.exists()
            else set()
        )

        skill_text = portable_text((source_skill / "SKILL.md").read_text(), domain_files, area)
        (target_skill / "SKILL.md").write_text(add_skill_root_contract(skill_text))

        for source_ref in sorted((SOURCE / "reference").glob("*.md")):
            text = portable_text(source_ref.read_text(), domain_files, area)
            (shared_refs / source_ref.name).write_text(text)

        if domain_files:
            domain_refs.mkdir(parents=True)
            for source_ref in sorted(source_domain_refs.glob("*.md")):
                text = portable_text(source_ref.read_text(), domain_files, area)
                (domain_refs / source_ref.name).write_text(text)

        wrapper = portable_text((SOURCE / "scripts" / "xcloud.sh").read_text(), domain_files, area)
        wrapper_path = scripts / "xcloud.sh"
        wrapper_path.write_text(wrapper)
        wrapper_path.chmod(0o755)

    print(f"Built Agent Plugins package at {OUT}")


if __name__ == "__main__":
    main()
