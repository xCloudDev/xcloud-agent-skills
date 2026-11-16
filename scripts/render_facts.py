#!/usr/bin/env python3
"""Rewrite the generated blocks in the docs from facts/facts.json.

A block sits between `<!-- facts:NAME:start -->` and `<!-- facts:NAME:end -->`.
  python3 scripts/render_facts.py          rewrite stale blocks in place
  python3 scripts/render_facts.py --check  exit 1 when a block is stale (CI)
Standard library only.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = json.load(open(os.path.join(ROOT, 'facts', 'facts.json')))
X = F['xcloud']


def table(head, rows):
    out = ['| ' + ' | '.join(head) + ' |', '|' + '|'.join('---' for _ in head) + '|']
    out += ['| ' + ' | '.join(str(c).replace('|', '\\|') for c in r) + ' |' for r in rows]
    return '\n'.join(out)


def caps(kind):
    return [c for c in F['capabilities'] if c['kind'] == kind]


def b_version():
    return (f"Verified against xCloud v{X['version']} on {X.get('verified', X['date'])}. If the server reports a newer "
            "version, trust `xcloud_agent_search` over this file.")


def b_capability_dashboard():
    return table(['Job', 'Where in the dashboard'], [(c['job'], f"**{c['where']}**") for c in caps('dashboard-only')])


def b_capability_refused():
    return table(['Job xCloud refuses', 'Why'], [(c['job'], c['why']) for c in caps('refused')])


def b_capability_api():
    rows = [(c['job'], ', '.join(f'`{o}`' for o in c['operations']), 'read only' if c['kind'] == 'read-only' else 'read and change')
            for c in caps('api') + caps('read-only')]
    return table(['Job', 'Operations', 'Kind'], rows)


def b_mcp_profiles():
    P = F['mcp']['profiles']
    fl, un, oa = P['flat'], P['unified'], P['openai']
    d = F['mcp']['default_profile']
    rows = [
        (f"`{fl['path']}` (flat" + (', default' if d == 'flat' else '') + ')',
         f"One tool per operation (about {fl['operation_tool_count']}), the dashboard-action tools (about {fl['dashboard_action_tool_count']}) and `xcloud_agent_search`, `xcloud_docs_search`, `report_friction`. A read-only grant lists far fewer (about {F['mcp']['read_only_grant_tool_count']} operation tools) and hides write tools."),
        (f"`{un['path']}` (unified; aliases `compact`, `/mcp/v2`" + (', default' if d == 'unified' else '') + ')',
         f"{un['tool_count']} tools: " + ', '.join(f'`{t}`' for t in un['tools']) + '. Every operation runs through `execute`.'),
        (f"`{oa['path']}` (read-only)", f"{oa['tool_count']} read tools for chat clients that only look."),
    ]
    return table(['Profile', 'What it lists'], rows)


def b_mcp_counts():
    return (f"xCloud v{X['version']} has {F['operation_count']} public API operations. "
            f"{len(F['mcp']['excluded_operations'])} of them have no MCP tool (health, API-token management, native-app sign-in, notifications, one CSV download).")


def b_mcp_toolsets():
    return ', '.join(f'`{t}`' for t in F['mcp']['toolsets'])


def b_mcp_limits():
    L = F['mcp']['limits']
    return f"MCP calls are limited to {L['calls_per_minute']} per minute and {L['calls_per_hour']:,} per hour for each credential."


def b_scopes():
    return table(['Ability', 'What it allows'], [(f"`{s['ability']}`", s['meaning']) for s in F['scopes']])


def b_excluded():
    return ', '.join(f'`{o}`' for o in F['mcp']['excluded_operations'])


def ops_block(tag):
    rows = [(f"`{o['id']}`", o['method'], f"`{o['path']}`", o['class'], f"`{o['scope']}`", o['summary'])
            for o in F['operations'] if re.sub(r'[^a-z0-9]+', '-', o['tag'].lower()).strip('-') == tag]
    return table(['Operation', 'Method', 'Path', 'Class', 'Scope', 'Summary'], rows)


BLOCKS = {'version': b_version, 'capability-dashboard': b_capability_dashboard, 'capability-refused': b_capability_refused,
          'capability-api': b_capability_api, 'mcp-profiles': b_mcp_profiles, 'mcp-counts': b_mcp_counts,
          'mcp-toolsets': b_mcp_toolsets, 'mcp-limits': b_mcp_limits, 'scopes': b_scopes, 'mcp-excluded': b_excluded}

PAT = re.compile(r'(<!-- facts:([a-z0-9:-]+):start -->\n)(.*?)(\n<!-- facts:\2:end -->)', re.S)


def render(name):
    if name.startswith('ops:'):
        return ops_block(name[4:])
    return BLOCKS[name]()


def main():
    check = '--check' in sys.argv
    stale = []
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules')]
        for fn in files:
            if not fn.endswith('.md'):
                continue
            p = os.path.join(base, fn)
            text = open(p, encoding='utf-8').read()
            new = PAT.sub(lambda m: m.group(1) + render(m.group(2)) + m.group(4), text)
            if new != text:
                stale.append(os.path.relpath(p, ROOT))
                if not check:
                    open(p, 'w', encoding='utf-8').write(new)
    if stale and check:
        print('Stale generated blocks (run scripts/render_facts.py):\n  ' + '\n  '.join(stale))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
