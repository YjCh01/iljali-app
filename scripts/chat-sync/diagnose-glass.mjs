import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const db = new DatabaseSync(path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb'), { readOnly: true });
const h = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value));

const types = {};
for (const c of h.allComposers) {
  const t = c.agentLocation?.type ?? 'null';
  types[t] = (types[t] ?? 0) + 1;
  if (c.agentLocation && t !== 'null' && t !== 'local') {
    console.log('NON-LOCAL', c.composerId.slice(0,8), c.name, JSON.stringify(c.agentLocation).slice(0,300));
  }
}
console.log('agentLocation types:', types);

// show iljali-app repoUrl in trackedGitRepos
let repoUrlCount = 0;
for (const c of h.allComposers) {
  if (JSON.stringify(c.trackedGitRepos ?? '').includes('iljali-app')) repoUrlCount++;
}
console.log('headers with iljali-app repoUrl:', repoUrlCount);

// glass membership for iljali project
const mem = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjectMembership.v1'").get().value));
const proj = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const ids = Object.entries(mem).filter(([,v]) => v === proj).map(([k]) => k);
console.log('membership count:', ids.length);
console.log('sample ids:', ids.slice(0,5));

// which of membership ids have null agentLocation in headers?
const byId = new Map(h.allComposers.map((c) => [c.composerId, c]));
let memNullLoc = 0;
for (const id of ids) {
  const c = byId.get(id);
  if (!c || !c.agentLocation) memNullLoc++;
}
console.log('membership ids missing from headers or null agentLocation:', memNullLoc);

db.close();
