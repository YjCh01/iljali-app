import { DatabaseSync } from 'node:sqlite';
import path from 'node:path';

const db = new DatabaseSync(path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb'), { readOnly: true });
const id = 'ba351e43-e44b-4221-a8f1-7ec22087ed1b';
const data = JSON.parse(String(db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${id}`).value));
const bubbles = db.prepare("SELECT count(*) c FROM cursorDiskKV WHERE key LIKE ?").get(`bubbleId:${id}:%`).c;
const headers = data.fullConversationHeadersOnly?.length ?? 0;
console.log('ba351 name:', data.name);
console.log('headers in composerData:', headers);
console.log('bubble rows:', bubbles);
console.log('status:', data.status);

const h = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value));
const entry = h.allComposers.find((c) => c.composerId === id);
console.log('in composerHeaders:', !!entry, 'name:', entry?.name);
console.log('agentLocation:', entry?.agentLocation ? 'SET' : 'NULL');
console.log('isArchived:', entry?.isArchived);

db.close();
