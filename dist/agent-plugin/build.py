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
PLUGIN_SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
MCP_SCHEMA = "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json"


def portable_text(text: str, domain_files: set[str]) -> str:
    """Rewrite Claude plugin-root paths as Agent Skills root-relative paths."""
    text = re.sub(
        r'\\?"\$\{CLAUDE_PLUGIN_ROOT\}\\?"/scripts/xcloud\.sh',
        "scripts/xcloud.sh",
        text,
    )
    text = text.replace(
        "${CLAUDE_PLUGIN_ROOT}/scripts/xcloud.sh", "scripts/xcloud.sh"
    )
    for filename in ("auth.md", "conventions.md", "mcp.md"):
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
    for filename in ("auth.md", "conventions.md", "mcp.md"):
        text = text.replace(f"reference/{filename}", f"references/shared/{filename}")
    return text


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    claude_manifest = json.loads((SOURCE / ".claude-plugin" / "plugin.json").read_text())
    manifest = {
        "$schema": PLUGIN_SCHEMA,
        **claude_manifest,
        "repository": "https://github.com/xCloudDev/xcloud-agent-skills",
    }
    write_json(OUT / "plugin.json", manifest)
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

        skill_text = portable_text((source_skill / "SKILL.md").read_text(), domain_files)
        (target_skill / "SKILL.md").write_text(skill_text)

        for source_ref in sorted((SOURCE / "reference").glob("*.md")):
            text = portable_text(source_ref.read_text(), domain_files)
            (shared_refs / source_ref.name).write_text(text)

        if domain_files:
            domain_refs.mkdir(parents=True)
            for source_ref in sorted(source_domain_refs.glob("*.md")):
                text = portable_text(source_ref.read_text(), domain_files)
                (domain_refs / source_ref.name).write_text(text)

        wrapper = portable_text((SOURCE / "scripts" / "xcloud.sh").read_text(), domain_files)
        wrapper_path = scripts / "xcloud.sh"
        wrapper_path.write_text(wrapper)
        wrapper_path.chmod(0o755)

    print(f"Built Agent Plugins package at {OUT}")


if __name__ == "__main__":
    main()
