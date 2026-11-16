# Split the xCloud Public API skill into five capability-domain skills

**Status:** accepted

To expose the xCloud Public API's full operation surface (111 operations in the
live OpenAPI spec; the skills document 108 of those plus conditional
sub-resources) through Claude Code, we
ship **five sibling skills** organized by *capability* — `xcloud:servers`, `xcloud:sites`,
`xcloud:wordpress`, `xcloud:ssl`, `xcloud:account` — rather than one large skill,
one-skill-per-OpenAPI-tag (11), or one-skill-per-sub-resource (~18). Each skill
has a thin `SKILL.md` and loads sub-resource reference files on demand; all five
share a single plugin-level `scripts/xcloud.sh` and `reference/` via
`${CLAUDE_PLUGIN_ROOT}`, so auth/conventions exist once. This shipped as the
`xcloud-public-api` plugin **2.0.0**, replacing the single v1 skill (preserved at
the `1.2.0` tag). In **3.0.0** the plugin was renamed to `xcloud` and the skills
are now invoked as `xcloud:servers`, `xcloud:sites`, `xcloud:wordpress`,
`xcloud:ssl`, and `xcloud:account`.

## Considered options

- **One skill + reference files.** Best context economy, zero trigger ambiguity,
  but no per-domain discoverability — users can't see/invoke a named SSL
  capability. Rejected: discoverability was a stated goal.
- **One skill per OpenAPI tag (11).** Mechanical, but several tags are 1 op
  (wasteful) and SSL spans two tags. Rejected: too many skills, poor boundaries.
- **One skill per sub-resource (~18).** Maximum discoverability, but Claude Code
  truncates descriptions when many skills are present, stripping the
  disambiguating keywords — actively *degrades* trigger precision. Rejected.
- **Keep v1 co-installed.** v1's broad description steals triggers from narrow
  domain skills. Rejected in favor of version-based preservation.
- **A thin "hub" router skill.** A catch-all description re-introduces the exact
  trigger-theft we removed by retiring v1. Rejected.

## Consequences

- Skills are cut by **capability, not URL root**, so they cut *across* the API's
  resource structure (e.g. `/sites/{uuid}/ssl` is owned by `xcloud:ssl`, not
  `xcloud:sites`). Every skill description must declare what it does *not* own
  with explicit `see xcloud:<other>` cross-links — this is load-bearing, not
  decorative. Without it, requests touching shared resources (SSL, cron,
  WordPress, vulnerabilities) route unpredictably.
- `vulnerabilities` and `pagespeed` are site-level endpoints owned by
  `xcloud:wordpress`; non-WordPress sites reach them via the `xcloud:sites`
  cross-link.
- Skills are coupled to the plugin layout via `${CLAUDE_PLUGIN_ROOT}`. Acceptable
  while they ship as one co-versioned plugin; revisit if a domain ever needs
  independent ownership/versioning (would justify its own plugin).
