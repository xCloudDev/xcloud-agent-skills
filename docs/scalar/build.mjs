#!/usr/bin/env node
/** Generate the guide-only Scalar document. Use --check for offline validation. */
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
export const CAPABILITIES = {
  wordpress: 'WordPress health, plugin/theme updates, vulnerability findings, broken links, PageSpeed, approved debug and temporary login actions',
  troubleshoot: 'Investigate errors using status, events, bounded web-server logs, WordPress health and services',
  performance: 'Diagnose slowness using monitoring, cache state, existing PageSpeed results, traffic and the site’s PHP version',
  sites: 'Site status, domain inspection, backups including Docker, cache purges, access logs, SSH/SFTP, cron and dashboard handoffs',
  ssl: 'Certificate status, HTTPS checks, installation and renewal',
  deploy: 'Supported Git, Docker/Compose and one-click deployments, Git branch staging, new WordPress sites and failed-deploy diagnosis',
  servers: 'Inventory, monitoring, services, Node/PHP versions, firewall/fail2ban, cron, site-snapshot listings and approved reboots or purchases',
  billing: 'Plans, invoices, prices, subscriptions, masked payment methods and approved payments or mailbox/mail-delivery add-ons',
  account: 'Identity, teams, alerts, Git/Cloudflare integrations, WordPress blueprints and API-token guidance',
};

export function buildDocument(root = resolve(HERE, '../..')) {
  const plugin = JSON.parse(readFileSync(join(root, 'plugins/xcloud/.claude-plugin/plugin.json'), 'utf8'));
  const clawhub = JSON.parse(readFileSync(join(root, '.clawhubinfo.json'), 'utf8'));
  if (plugin.version !== clawhub.version) throw new Error('Plugin and ClawHub versions differ.');

  const skillNames = readdirSync(join(root, 'plugins/xcloud/skills'), { withFileTypes: true })
    .filter(entry => entry.isDirectory()).map(entry => entry.name).sort();
  if (JSON.stringify(skillNames) !== JSON.stringify(Object.keys(CAPABILITIES).sort())) {
    throw new Error('Scalar capabilities must match the source skill directories.');
  }
  for (const skill of skillNames) readFileSync(join(root, 'plugins/xcloud/skills', skill, 'SKILL.md'), 'utf8');

  const guide = readFileSync(join(root, 'docs/scalar/guide.md'), 'utf8').trim();
  if (guide.split('{{CAPABILITIES}}').length !== 2) throw new Error('Expected one capabilities placeholder.');
  const table = ['| Skill | What it covers |', '|---|---|',
    ...Object.entries(CAPABILITIES).map(([name, summary]) => `| \`xcloud:${name}\` | ${summary} |`)].join('\n');
  return {
    openapi: '3.1.0',
    info: { title: 'xCloud Agent Skills', version: plugin.version, description: guide.replace('{{CAPABILITIES}}', table) },
    paths: {}, // Guide only; endpoint reference lives at /api/v1/docs.
  };
}

export function renderDocument(root) {
  return JSON.stringify(buildDocument(root), null, 2) + '\n';
}

export function checkDocument(root = resolve(HERE, '../..')) {
  const expected = renderDocument(root);
  const actual = readFileSync(join(root, 'docs/scalar/xcloud-skills.openapi.json'), 'utf8');
  if (actual !== expected) throw new Error('Scalar document is stale. Run node docs/scalar/build.mjs and commit the result.');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    if (args.length > 1 || (args.length === 1 && args[0] !== '--check')) {
      throw new Error('Usage: node docs/scalar/build.mjs [--check]');
    }
    if (args[0] === '--check') {
      checkDocument();
      console.log('Scalar guide is current; plugin/ClawHub versions and all nine capabilities match.');
    } else {
      const outPath = join(HERE, 'xcloud-skills.openapi.json');
      writeFileSync(outPath, renderDocument());
      console.log(`Wrote ${outPath}`);
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
