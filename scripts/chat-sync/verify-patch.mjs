import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const db = new DatabaseSync(path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb'), { readOnly: true });
const h = JSON.parse(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value);
let withLoc = 0;
let withRepo = 0;
for (const c of h.allComposers) {
  if (c.agentLocation?.environment?.id === 'cc095c556477ec81d2f10f0fc17d9fa4') withLoc++;
  if (JSON.stringify(c.trackedGitRepos ?? '').includes('iljali-app')) withRepo++;
}
console.log('with agentLocation 1jari:', withLoc);
console.log('with repoUrl iljali-app:', withRepo);
console.log('total headers:', h.allComposers.length);
db.close();
