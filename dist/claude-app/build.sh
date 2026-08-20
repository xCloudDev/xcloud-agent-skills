#!/usr/bin/env bash
# build.sh — generate ONE consolidated claude.ai skill from the Claude Code plugin.
#
# claude.ai treats an uploaded zip as a SINGLE skill (one SKILL.md at the root).
# So instead of five separate skills we ship one `xcloud` skill whose SKILL.md
# routes across all five capability areas, with everything bundled:
#
#   xcloud/
#     SKILL.md                     <- router (dist/claude-app/SKILL.template.md)
#     scripts/xcloud.sh            <- shared wrapper
#     reference/
#       auth.md  conventions.md  mcp.md    <- shared layer
#       servers.md sites.md ...    <- each area's SKILL.md body, as a reference doc
#       servers-firewall.md ...    <- sub-resource files, namespaced by area
#
# Sub-resource files are prefixed with their area (servers-cron-jobs.md vs
# sites-cron-jobs.md) so nothing collides when flattened, and the in-body links
# are rewritten to match. ${CLAUDE_PLUGIN_ROOT}/ is stripped to skill-relative
# paths. Output: dist/claude-app/xcloud/ + dist/claude-app/xcloud-agent-skill.zip
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/plugins/xcloud"
OUT="$ROOT/dist/claude-app"
SKILL="$OUT/xcloud"
AREAS=(servers sites wordpress ssl account deploy-app)

echo "Building consolidated claude.ai skill from $SRC"

# clean previous outputs (old per-skill folders + zips + this skill)
rm -rf "$OUT"/xcloud-* "$SKILL" "$OUT"/*.zip 2>/dev/null || true
mkdir -p "$SKILL/scripts" "$SKILL/reference"

strip_pluginroot='s#"${CLAUDE_PLUGIN_ROOT}"/##g; s#${CLAUDE_PLUGIN_ROOT}/##g'
drop_frontmatter='BEGIN{fm=0} NR==1 && $0=="---"{fm=1; next} fm==1 && $0=="---"{fm=0; next} fm==0{print}'

# shared layer — strip ${CLAUDE_PLUGIN_ROOT}/ to skill-relative paths
sed "$strip_pluginroot" "$SRC/scripts/xcloud.sh"        > "$SKILL/scripts/xcloud.sh"
chmod +x "$SKILL/scripts/xcloud.sh"
sed "$strip_pluginroot" "$SRC/reference/auth.md"        > "$SKILL/reference/auth.md"
sed "$strip_pluginroot" "$SRC/reference/conventions.md" > "$SKILL/reference/conventions.md"
sed "$strip_pluginroot" "$SRC/reference/mcp.md"         > "$SKILL/reference/mcp.md"

# NOTE: no inline logo image. claude.ai chat renders an external markdown image as
# a large click-to-reveal "Show Image" card (no width/height control), which
# breaks the header rather than showing a tidy inline icon. The brand mark is the
# ☁️ glyph + bold **xCloud** wordmark (both surfaces) plus the ASCII startup
# banner. The SVG stays in the repo for hosting/MCP/docs use, not for chat output.

# router SKILL.md (already skill-relative)
cp "$OUT/SKILL.template.md" "$SKILL/SKILL.md"

for area in "${AREAS[@]}"; do
  # 1. copy this area's sub-resource files, namespaced (strip paths + link rewrite),
  #    and collect the link-rename rules for the area body
  rename_sed=()
  if compgen -G "$SRC/skills/$area/reference/*.md" >/dev/null; then
    for f in "$SRC/skills/$area/reference/"*.md; do
      base="$(basename "$f")"
      rename_sed+=(-e "s#reference/${base}#reference/${area}-${base}#g")
    done
    for f in "$SRC/skills/$area/reference/"*.md; do
      base="$(basename "$f")"
      sed "$strip_pluginroot" "$f" | sed "${rename_sed[@]}" \
        > "$SKILL/reference/${area}-${base}"
    done
  fi

  # 2. convert the area SKILL.md body into reference/<area>.md
  #    drop frontmatter, strip ${CLAUDE_PLUGIN_ROOT}/, rewrite sub-resource links
  awk "$drop_frontmatter" "$SRC/skills/$area/SKILL.md" \
    | sed "$strip_pluginroot" \
    | sed "${rename_sed[@]:-}" \
    > "$SKILL/reference/${area}.md"
done

# 3. zip the single skill folder
( cd "$OUT" && zip -qr "xcloud-agent-skill.zip" "xcloud" )

echo "  ✓ xcloud  ($(find "$SKILL" -type f | wc -l | tr -d ' ') files)"
echo "Done → $OUT/xcloud-agent-skill.zip"
