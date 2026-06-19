import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const globalDir = path.join(process.env.APPDATA, 'Cursor/User/globalStorage');
const backups = fs.readdirSync(globalDir)
  .filter((f) => f.startsWith('state.vscdb'))
  .map((f) => {
    const p = path.join(globalDir, f);
    const st = fs.statSync(p);
    return { name: f, mb: (st.size / 1024 / 1024).toFixed(1), mtime: st.mtime.toISOString() };
  })
  .sort((a, b) => b.mtime.localeCompare(a.mtime));

console.log('=== BACKUPS ===');
for (const b of backups) console.log(b.name, b.mb + 'MB', b.mtime);

function analyzeDb(dbPath, label) {
  try {
    const db = new DatabaseSync(dbPath, { readOnly: true });
    const row = db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get();
    if (!row) {
      console.log(label, 'NO composer.composerHeaders');
      db.close();
      return;
    }
    const h = JSON.parse(String(row.value));
    const all = h.allComposers ?? [];
    let iljari = 0;
    let withLoc = 0;
    let ba351 = false;
    for (const c of all) {
      const s = JSON.stringify(c);
      if (/1jari|iljali/i.test(s)) iljari++;
      if (c.composerId === 'ba351e43-e44b-4221-a8f1-7ec22087ed1b') ba351 = true;
      if (c.agentLocation?.environment?.id === 'cc095c556477ec81d2f10f0fc17d9fa4') withLoc++;
    }
    const mem = db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjectMembership.v1'").get();
    const membership = mem ? JSON.parse(String(mem.value)) : {};
    const iljaliProject = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
    const memCount = Object.values(membership).filter((v) => v === iljaliProject).length;
    const composerDataCount = db.prepare("SELECT count(*) c FROM cursorDiskKV WHERE key LIKE 'composerData:%'").get().c;
    console.log(label, '| headers:', all.length, '| iljari-ish:', iljari, '| agentLoc 1jari:', withLoc, '| ba351 in headers:', ba351, '| glass membership iljali project:', memCount, '| composerData blobs:', composerDataCount);
    db.close();
  } catch (e) {
    console.log(label, 'ERROR', e.message);
  }
}

analyzeDb(path.join(globalDir, 'state.vscdb'), 'CURRENT');
for (const b of backups.slice(0, 5)) {
  analyzeDb(path.join(globalDir, b.name), b.name);
}
