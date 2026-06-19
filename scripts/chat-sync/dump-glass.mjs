import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const OUT = path.resolve(import.meta.dirname, 'glass-dump.json');

const db = new DatabaseSync(GLOBAL, { readOnly: true });
const keys = [
  'glass.localAgentProjects.v1',
  'glass.localAgentProjectMembership.v1',
  'glass.cloudAgentProjects.v1',
  'glass.cloudAgentProjectMembership.v1',
  'cloudAgentRepository.agents',
  'cloudEnvironmentTemplate.githubRepos',
];

const dump = {};
for (const key of keys) {
  const row = db.prepare('SELECT value FROM ItemTable WHERE key = ?').get(key);
  if (!row?.value) {
    dump[key] = null;
    continue;
  }
  try {
    dump[key] = JSON.parse(String(row.value));
  } catch {
    dump[key] = String(row.value).slice(0, 500);
  }
}

fs.writeFileSync(OUT, JSON.stringify(dump, null, 2));
console.log('Wrote', OUT);

// Summarize iljali memberships
const projects = dump['glass.localAgentProjects.v1'];
const membership = dump['glass.localAgentProjectMembership.v1'];
if (projects) {
  console.log('\nlocalAgentProjects count:', Array.isArray(projects) ? projects.length : Object.keys(projects).length);
  const list = Array.isArray(projects) ? projects : Object.values(projects);
  for (const p of list) {
    const label = p.name ?? p.displayName ?? p.repoName ?? p.id ?? JSON.stringify(p).slice(0, 80);
    if (/iljali|1jari/i.test(JSON.stringify(p))) {
      console.log('ILJALI PROJECT:', JSON.stringify(p, null, 2));
    }
  }
}
if (membership) {
  const entries = Array.isArray(membership) ? membership : Object.entries(membership);
  console.log('\nmembership type:', Array.isArray(membership) ? 'array' : typeof membership);
  if (typeof membership === 'object' && !Array.isArray(membership)) {
    for (const [k, v] of Object.entries(membership)) {
      if (/iljali|1jari/i.test(k) || /iljali|1jari/i.test(JSON.stringify(v))) {
        const agents = Array.isArray(v) ? v : v?.agentIds ?? v?.composers ?? v;
        const count = Array.isArray(agents) ? agents.length : (typeof agents === 'object' ? Object.keys(agents).length : '?');
        console.log(`MEMBERSHIP ${k}: count=${count}`);
        console.log(JSON.stringify(v, null, 2).slice(0, 2000));
      }
    }
  }
}

db.close();
