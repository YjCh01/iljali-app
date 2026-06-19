import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const db = new DatabaseSync(GLOBAL, { readOnly: true });
const headers = JSON.parse(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value);

const ba = headers.allComposers.find((c) => c.composerId === 'ba351e43-e44b-4221-a8f1-7ec22087ed1b');
const recent = headers.allComposers.find((c) => c.composerId === '423bac07-a63a-4f7a-a0fc-864c55a39533');
console.log('ba351 agentLocation:', JSON.stringify(ba?.agentLocation, null, 2));
console.log('ba351 trackedGitRepos:', JSON.stringify(ba?.trackedGitRepos, null, 2));
console.log('423 agentLocation:', JSON.stringify(recent?.agentLocation, null, 2));
console.log('423 trackedGitRepos:', JSON.stringify(recent?.trackedGitRepos, null, 2));

const meta = JSON.parse(db.prepare("SELECT value FROM ItemTable WHERE key='workspaceMetadata.entries'").get().value);
const entry = meta.entries.find((e) => e.workspaceId === 'cc095c556477ec81d2f10f0fc17d9fa4');
console.log('\n1jari workspaceMetadata:', JSON.stringify(entry, null, 2));

// count agentLocation types
const locCounts = {};
for (const c of headers.allComposers) {
  const k = JSON.stringify(c.agentLocation ?? null);
  locCounts[k] = (locCounts[k] ?? 0) + 1;
}
console.log('\nagentLocation distribution (top):');
for (const [k, n] of Object.entries(locCounts).sort((a, b) => b[1] - a[1]).slice(0, 8)) {
  console.log(n, k.slice(0, 200));
}

fs.writeFileSync(path.join(import.meta.dirname, 'sample-headers.json'), JSON.stringify([ba, recent], null, 2));
db.close();
