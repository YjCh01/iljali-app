import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const db = new DatabaseSync(GLOBAL, { readOnly: true });

for (const key of [
  'cursor/glass.additionalProjects',
  'repositoryTracker.paths',
  'workbench.backgroundComposer.workspacePersistentData',
]) {
  const row = db.prepare('SELECT value FROM ItemTable WHERE key = ?').get(key);
  console.log('\n===', key, '===');
  if (!row) {
    console.log('(missing)');
    continue;
  }
  const text = String(row.value);
  try {
    const parsed = JSON.parse(text);
    fs.writeFileSync(path.join(import.meta.dirname, `${key.replace(/[/.]/g, '_')}.json`), JSON.stringify(parsed, null, 2));
    console.log('written, length', text.length);
    if (key === 'cursor/glass.additionalProjects') {
      for (const p of parsed) {
        if (/iljali|1jari/i.test(JSON.stringify(p))) console.log(JSON.stringify(p, null, 2));
      }
    }
    if (key === 'repositoryTracker.paths') {
      console.log(JSON.stringify(parsed, null, 2).slice(0, 3000));
    }
  } catch {
    console.log(text.slice(0, 1000));
  }
}

// workspace persistent data for d-1jari
const WS = path.join(process.env.APPDATA, 'Cursor/User/workspaceStorage/cc095c556477ec81d2f10f0fc17d9fa4/state.vscdb');
if (fs.existsSync(WS)) {
  const wdb = new DatabaseSync(WS, { readOnly: true });
  const row = wdb.prepare("SELECT value FROM ItemTable WHERE key='workbench.backgroundComposer.workspacePersistentData'").get();
  console.log('\n=== workspace backgroundComposer ===');
  console.log(row ? String(row.value).slice(0, 2000) : '(missing)');
  wdb.close();
}

db.close();
