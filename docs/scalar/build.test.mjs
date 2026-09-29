import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDocument, checkDocument, renderDocument, CAPABILITIES } from './build.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'xcloud-scalar-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const files = ['plugins/xcloud/.claude-plugin/plugin.json', '.clawhubinfo.json', 'docs/scalar/guide.md'];
  for (const file of files) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), readFileSync(join(root, file)));
  }
  for (const name of Object.keys(CAPABILITIES)) {
    mkdirSync(join(dir, 'plugins/xcloud/skills', name), { recursive: true });
    writeFileSync(join(dir, 'plugins/xcloud/skills', name, 'SKILL.md'), '# Test fixture\n');
  }
  writeFileSync(join(dir, 'docs/scalar/xcloud-skills.openapi.json'), renderDocument(dir));
  return dir;
}

test('committed document is current, guide-only, and covers all nine skills once', () => {
  checkDocument(root);
  const doc = buildDocument(root);
  assert.equal(doc.openapi, '3.1.0');
  assert.deepEqual(doc.paths, {});
  const rows = [...doc.info.description.matchAll(/^\| `xcloud:([^`]+)` \|/gm)].map(match => match[1]);
  assert.equal(rows.length, 9);
  assert.deepEqual(rows.sort(), Object.keys(CAPABILITIES).sort());
});

test('guide retains installation paths and the transport and dashboard boundaries', () => {
  const text = buildDocument(root).info.description;
  for (const required of [
    'clawhub install xcloud', 'clawhub update xcloud',
    '/plugin install xcloud@xcloud-agent-skills', 'dist/agent-plugin/xcloud',
    'mcp:read', 'mcp:write', 'mcp:invoke',
    'GET-only requests with no body', 'no write override',
    'required concrete user approval and server confirmation',
    'Do not bypass this', 'direct curl, SDKs, alternate scripts or edits to the wrapper',
    'token revocation is unavailable',
    'Changing the server PHP default does not move existing sites',
    'API staging creation supports Git sites only',
    'restore needs the dashboard', 'Site → WordPress → Caching',
    'Do not change anything or start new scans',
    'tests passed before asking for production approval',
    'A restore can discard newer orders',
    'confirm a plan that preserves that newer data',
  ]) assert.ok(text.includes(required), `Missing guide boundary or installation instruction: ${required}`);
});

test('--check rejects a stale artifact without rewriting it', t => {
  const dir = fixture(t);
  const artifact = join(dir, 'docs/scalar/xcloud-skills.openapi.json');
  const stale = '{"info":{"version":"3.0.0"}}\n';
  writeFileSync(artifact, stale);
  assert.throws(() => checkDocument(dir), /document is stale/);
  assert.equal(readFileSync(artifact, 'utf8'), stale);
});

test('version drift fails until the artifact is regenerated', t => {
  const dir = fixture(t);
  const pluginPath = join(dir, 'plugins/xcloud/.claude-plugin/plugin.json');
  const clawhubPath = join(dir, '.clawhubinfo.json');
  const plugin = JSON.parse(readFileSync(pluginPath, 'utf8'));
  const clawhub = JSON.parse(readFileSync(clawhubPath, 'utf8'));
  plugin.version = '99.0.0';
  writeFileSync(pluginPath, JSON.stringify(plugin));
  assert.throws(() => checkDocument(dir), /versions differ/);
  clawhub.version = plugin.version;
  writeFileSync(clawhubPath, JSON.stringify(clawhub));
  assert.throws(() => checkDocument(dir), /document is stale/);
  writeFileSync(join(dir, 'docs/scalar/xcloud-skills.openapi.json'), renderDocument(dir));
  checkDocument(dir);
  assert.equal(buildDocument(dir).info.version, '99.0.0');
});

test('source capability additions and removals require a landing-page update', t => {
  const dir = fixture(t);
  const skills = join(dir, 'plugins/xcloud/skills');
  mkdirSync(join(skills, 'new-capability'));
  assert.throws(() => checkDocument(dir), /capabilities must match/);
  rmSync(join(skills, 'new-capability'), { recursive: true });
  rmSync(join(skills, 'wordpress'), { recursive: true });
  assert.throws(() => checkDocument(dir), /capabilities must match/);
});
