import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { DatabaseSync } from 'node:sqlite';

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const WS_ID = 'cc095c556477ec81d2f10f0fc17d9fa4';
const WS = path.join(process.env.APPDATA, 'Cursor/User/workspaceStorage', WS_ID, 'state.vscdb');

const db = new DatabaseSync(GLOBAL, { readOnly: true });
const headers = JSON.parse(
  db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get()?.value ?? '{}',
);
const all = headers.allComposers ?? [];
const target = all.filter((c) => {
  const ext = c.workspaceIdentifier?.uri?.external ?? '';
  const fsPath = c.workspaceIdentifier?.uri?.fsPath ?? '';
  const id = c.workspaceIdentifier?.id ?? '';
  return (
    ext.toLowerCase().includes('1jari') ||
    fsPath.toLowerCase().includes('1jari') ||
    id === WS_ID
  );
});

console.log('Global headers total:', all.length);
console.log('Tagged to 1jari:', target.length);

const sample = target[0];
if (sample) {
  console.log('\nSample header keys:', Object.keys(sample));
  console.log('Sample workspaceIdentifier:', JSON.stringify(sample.workspaceIdentifier, null, 2));
}

const byId = {};
for (const c of all) {
  const id = String(c.workspaceIdentifier?.id ?? 'none');
  byId[id] = (byId[id] ?? 0) + 1;
}
console.log('\nBy workspace id:', Object.entries(byId).sort((a, b) => b[1] - a[1]).slice(0, 12));

// composerData sample for repo fields
const ba = db.prepare("SELECT value FROM cursorDiskKV WHERE key='composerData:ba351e43-e44b-4221-a8f1-7ec22087ed1b'").get();
if (ba) {
  const data = JSON.parse(String(ba.value));
  const interesting = {};
  for (const k of Object.keys(data)) {
    if (/repo|git|remote|workspace|folder|project/i.test(k)) interesting[k] = data[k];
  }
  console.log('\nba351 composerData repo-ish fields:', JSON.stringify(interesting, null, 2).slice(0, 1500));
}

if (fs.existsSync(WS)) {
  const wdb = new DatabaseSync(WS, { readOnly: true });
  const keys = wdb
    .prepare("SELECT key FROM ItemTable WHERE key LIKE '%composer%' OR key LIKE '%agent%' OR key LIKE '%repo%'")
    .all();
  console.log('\nWorkspace keys:', keys.map((k) => k.key));
  const cd = wdb.prepare("SELECT value FROM ItemTable WHERE key='composer.composerData'").get();
  if (cd) {
    const parsed = JSON.parse(String(cd.value));
    console.log('Workspace composer.composerData keys:', Object.keys(parsed));
    console.log('selectedComposerIds count:', parsed.selectedComposerIds?.length ?? 0);
    console.log('allComposers count:', parsed.allComposers?.length ?? 0);
  }
  wdb.close();
}

// Search ItemTable keys related to agents/repos
const agentKeys = db
  .prepare("SELECT key, length(value) len FROM ItemTable WHERE key LIKE '%agent%' OR key LIKE '%repo%' OR key LIKE '%github%'")
  .all();
console.log('\nGlobal agent/repo keys:', agentKeys.slice(0, 30));

db.close();
