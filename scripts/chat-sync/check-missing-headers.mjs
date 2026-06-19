import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const db = new DatabaseSync(path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb'), { readOnly: true });
const h = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value));
const mem = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjectMembership.v1'").get().value));
const proj = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const ids = Object.entries(mem).filter(([, v]) => v === proj).map(([k]) => k);
const byId = new Map(h.allComposers.map((c) => [c.composerId, c]));

let notInHeaders = 0;
let inHeadersNullLoc = 0;
for (const id of ids) {
  const c = byId.get(id);
  if (!c) {
    notInHeaders++;
    const row = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${id}`);
    console.log('MISSING FROM HEADERS:', id.slice(0, 8), row ? 'has composerData' : 'NO DATA');
  } else if (!c.agentLocation) {
    inHeadersNullLoc++;
  }
}
console.log('notInHeaders:', notInHeaders, 'inHeadersNullLoc:', inHeadersNullLoc);
db.close();
