#!/usr/bin/env python3
"""Validate generated xCloud Agent Plugins portability invariants."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "xcloud"
AREAS = ("servers", "sites", "wordpress", "ssl", "account")
FORBIDDEN = {
    "client-specific product text": re.compile(r"\b(?:Claude|claude)\b"),
    "client-specific environment path": re.compile(r"CLAUDE_PLUGIN_ROOT|~?/\.claude/"),
    "client-specific MCP namespace": re.compile(r"mcp__"),
    "client-specific skill namespace": re.compile(
        r"xcloud:(?:servers|sites|wordpress|ssl|account)"
    ),
    "stale singular reference path": re.compile(r"reference/"),
}
REFERENCE = re.compile(r"`(references/(?:shared|domain)/[^`\s)]+\.md)`")


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not (ROOT / "plugin.json").is_file() or not (ROOT / "mcp.json").is_file():
        fail("root plugin.json or mcp.json is missing")

    wrappers: list[bytes] = []
    for area in AREAS:
        skill_root = ROOT / "skills" / area
        skill_file = skill_root / "SKILL.md"
        wrapper = skill_root / "scripts" / "xcloud.sh"
        if not skill_file.is_file():
            fail(f"missing {skill_file.relative_to(ROOT)}")
        if not wrapper.is_file() or not wrapper.stat().st_mode & 0o111:
            fail(f"wrapper missing or not executable: {wrapper.relative_to(ROOT)}")
        wrappers.append(wrapper.read_bytes())

        skill_text = skill_file.read_text()
        contract = 'SKILL_ROOT="/absolute/path/to/this/skill"'
        if contract not in skill_text:
            fail(f"skill-root execution contract missing from {skill_file.relative_to(ROOT)}")

        for path in sorted(skill_root.rglob("*")):
            if not path.is_file() or path.suffix not in {".md", ".sh"}:
                continue
            text = path.read_text()
            for label, pattern in FORBIDDEN.items():
                match = pattern.search(text)
                if match:
                    fail(
                        f"{label} in {path.relative_to(ROOT)}: {match.group(0)!r}"
                    )
            if path.suffix == ".md":
                for match in REFERENCE.finditer(text):
                    target = skill_root / match.group(1)
                    if not target.is_file():
                        fail(
                            f"missing referenced file {match.group(1)!r} in "
                            f"{path.relative_to(ROOT)}"
                        )

    if len(set(wrappers)) != 1:
        fail("generated skill-local wrappers are not identical")

    print("portable package invariants: PASS")


if __name__ == "__main__":
    main()
