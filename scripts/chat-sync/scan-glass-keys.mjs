import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const db = new DatabaseSync(GLOBAL, { readOnly: true });
const rows = db.prepare("SELECT key, length(value) len FROM ItemTable WHERE key LIKE '%cloudAgent%' OR key LIKE '%glass.%' OR key LIKE '%Repository%' OR key LIKE '%iljali%'").all();
for (const r of rows) {
  console.log(r.key, r.len);
  if (r.len < 5000) {
    const v = db.prepare('SELECT value FROM ItemTable WHERE key = ?').get(r.key);
    console.log(String(v.value).slice(0, 800));
    console.log('---');
  }
}
db.close();
