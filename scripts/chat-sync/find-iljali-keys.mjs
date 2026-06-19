import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const db = new DatabaseSync(path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb'), { readOnly: true });
const rows = db.prepare('SELECT key, length(value) len FROM ItemTable').all();
for (const r of rows) {
  if (r.len > 500000) continue;
  const v = db.prepare('SELECT value FROM ItemTable WHERE key = ?').get(r.key);
  const s = String(v.value);
  if (/iljali-app|YjCh01\/iljali|cloudAgentRepository/i.test(s) || /cloudAgentRepository/i.test(r.key)) {
    console.log('\nKEY', r.key, 'len', r.len);
    console.log(s.slice(0, 1500));
  }
}
db.close();
