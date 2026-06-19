import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const db = new DatabaseSync(path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb'), { readOnly: true });
const headers = JSON.parse(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value);

for (const c of headers.allComposers) {
  const s = JSON.stringify(c);
  if (s.includes('iljali-app') || s.includes('yjch01') || c.agentLocation?.type === 'cloud') {
    console.log('\n---', c.composerId.slice(0, 8), c.name);
    console.log('agentLocation', JSON.stringify(c.agentLocation));
    console.log('trackedGitRepos', JSON.stringify(c.trackedGitRepos));
  }
}

// also check composerData for repoUrl
for (const id of ['423bac07-a63a-4f7a-a0fc-864c55a39533', 'ba351e43-e44b-4221-a8f1-7ec22087ed1b']) {
  const row = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${id}`);
  if (!row) continue;
  const d = JSON.parse(String(row.value));
  console.log('\ncomposerData', id.slice(0, 8), 'agentLocation', JSON.stringify(d.agentLocation));
  console.log('trackedGitRepos', JSON.stringify(d.trackedGitRepos));
}
db.close();
