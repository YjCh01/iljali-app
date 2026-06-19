#!/usr/bin/env node
/**
 * FULL RECOVERY: attach all iljali/1jari chats to Agents > Repositories > iljali-app
 * MUST run with Cursor fully quit.
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { DatabaseSync } from 'node:sqlite';
import { execSync } from 'node:child_process';

const REPO_URL = 'github.com/yjch01/iljali-app';
const WS_ID = 'cc095c556477ec81d2f10f0fc17d9fa4';
const WS_FS = 'd:\\1jari';
const WS_EXT = 'file:///d%3A/1jari';
const ILJALI_PROJECT = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const PROJECTS = path.join(os.homedir(), '.cursor', 'projects');

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const WS_DB = path.join(process.env.APPDATA, 'Cursor/User/workspaceStorage', WS_ID, 'state.vscdb');

const URI = { $mid: 1, fsPath: WS_FS, _sep: 1, external: WS_EXT, path: '/D:/1jari', scheme: 'file' };
const IDENT = { id: WS_ID, uri: URI };
const AGENT_LOC = { type: 'local', environment: IDENT, status: 'active' };

function isIljali(id, c, data) {
  const blob = JSON.stringify(c ?? data ?? '');
  if (/1jari|iljali|empty-window|daanggeun/i.test(blob)) return true;
  if (/^\d{13}$/.test(String(c?.workspaceIdentifier?.id ?? ''))) return true;
  for (const p of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    if (fs.existsSync(path.join(PROJECTS, p, 'agent-transcripts', id))) return true;
  }
  return false;
}

function trackedRepos(existing) {
  const branch = existing?.[0]?.branches?.[0]?.branchName ?? 'main';
  return [{ repoPath: WS_FS, repoUrl: REPO_URL, branches: [{ branchName: branch, lastInteractionAt: Date.now() }] }];
}

function patchEntry(e, data) {
  e.workspaceIdentifier = structuredClone(IDENT);
  e.agentLocation = structuredClone(AGENT_LOC);
  e.trackedGitRepos = trackedRepos(e.trackedGitRepos ?? data?.trackedGitRepos);
  if (!e.name && data?.name) e.name = data.name;
  if (!e.createdAt && data?.createdAt) e.createdAt = data.createdAt;
  if (!e.lastUpdatedAt) e.lastUpdatedAt = data?.lastUpdatedAt ?? Date.now();
  if (!e.unifiedMode) e.unifiedMode = data?.unifiedMode ?? 'agent';
  e.isArchived = false;
}

function killCursor() {
  try {
    execSync('taskkill /F /IM Cursor.exe /T', { stdio: 'pipe' });
    console.log('Cursor processes terminated.');
    return true;
  } catch {
    console.log('Cursor not running (or already stopped).');
    return false;
  }
}

function checkpoint(dbPath) {
  try {
    const db = new DatabaseSync(dbPath);
    db.exec('PRAGMA wal_checkpoint(TRUNCATE)');
    db.close();
  } catch { /* ignore */ }
}

function main() {
  const force = process.argv.includes('--force');
  if (!force) {
    console.error('Run: node recover-all-iljali-chats.mjs --force');
    console.error('This kills Cursor and rewrites globalStorage/state.vscdb');
    process.exit(1);
  }

  killCursor();
  // wait for file handles to release
  execSync('timeout /t 3 /nobreak >nul 2>&1', { shell: true });

  const wal = GLOBAL + '-wal';
  const shm = GLOBAL + '-shm';
  if (fs.existsSync(wal)) fs.unlinkSync(wal);
  if (fs.existsSync(shm)) fs.unlinkSync(shm);

  const backup = `${GLOBAL}.backup-recover-${Date.now()}`;
  fs.copyFileSync(GLOBAL, backup);
  console.log('Backup:', backup);

  const db = new DatabaseSync(GLOBAL);
  const headers = JSON.parse(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value);
  const list = headers.allComposers ?? (headers.allComposers = []);
  const byId = new Map(list.map((c) => [c.composerId, c]));

  let membership = {};
  const memRow = db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjectMembership.v1'").get();
  if (memRow) membership = JSON.parse(String(memRow.value));

  let projects = [];
  const projRow = db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjects.v1'").get();
  if (projRow) projects = JSON.parse(String(projRow.value));

  const allDataIds = db.prepare("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'").all()
    .map((r) => r.key.replace('composerData:', ''));

  const targetIds = new Set([
    ...allDataIds.filter((id) => {
      const row = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${id}`);
      const data = row ? JSON.parse(String(row.value)) : null;
      return isIljali(id, byId.get(id), data);
    }),
    ...Object.entries(membership).filter(([, v]) => v === ILJALI_PROJECT).map(([k]) => k),
  ]);

  console.log('Recovering', targetIds.size, 'conversations...');

  let patchedHeaders = 0;
  let patchedData = 0;

  for (const id of targetIds) {
    const dataRow = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${id}`);
    const data = dataRow ? JSON.parse(String(dataRow.value)) : null;

    let entry = byId.get(id);
    if (!entry) {
      entry = { composerId: id, type: 'head', forceMode: 'edit', hasUnreadMessages: false };
      list.push(entry);
      byId.set(id, entry);
    }
    patchEntry(entry, data);
    patchedHeaders++;

    if (data) {
      patchEntry(data, data);
      data.composerId = id;
      db.prepare('INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)').run(
        `composerData:${id}`, JSON.stringify(data),
      );
      patchedData++;
    }

    membership[id] = ILJALI_PROJECT;
  }

  const proj = projects.find((p) => p.id === ILJALI_PROJECT);
  if (proj) {
    proj.name = 'iljali-app';
    proj.workspace = structuredClone(IDENT);
    proj.lastUpdatedAt = Date.now();
  }

  // workspace DB — allComposers for IDE sidebar fallback
  if (fs.existsSync(WS_DB)) {
    const wdb = new DatabaseSync(WS_DB);
    const composers = [...targetIds].map((id) => {
      const e = byId.get(id);
      return {
        composerId: id,
        name: e?.name ?? '(recovered)',
        createdAt: e?.createdAt ?? Date.now(),
        lastUpdatedAt: e?.lastUpdatedAt ?? Date.now(),
        unifiedMode: e?.unifiedMode ?? 'agent',
        forceMode: 'edit',
      };
    });
    wdb.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
      'composer.composerData',
      JSON.stringify({
        allComposers: composers,
        selectedComposerIds: composers.slice(0, 20).map((c) => c.composerId),
        hasMigratedComposerData: true,
        hasMigratedMultipleComposers: true,
      }),
    );
    wdb.close();
    console.log('Workspace DB updated with', composers.length, 'allComposers');
  }

  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'composer.composerHeaders', JSON.stringify(headers),
  );
  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'glass.localAgentProjectMembership.v1', JSON.stringify(membership),
  );
  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'glass.localAgentProjects.v1', JSON.stringify(projects),
  );

  db.exec('PRAGMA wal_checkpoint(TRUNCATE)');
  db.close();
  checkpoint(GLOBAL);

  // verify
  const vdb = new DatabaseSync(GLOBAL, { readOnly: true });
  const vh = JSON.parse(String(vdb.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value));
  let locOk = 0, repoOk = 0;
  for (const c of vh.allComposers) {
    if (c.agentLocation?.environment?.id === WS_ID) locOk++;
    if (JSON.stringify(c.trackedGitRepos ?? '').includes('iljali-app')) repoOk++;
  }
  vdb.close();

  console.log('\n=== RECOVERY DONE ===');
  console.log('Headers patched:', patchedHeaders);
  console.log('composerData patched:', patchedData);
  console.log('Verify agentLocation:', locOk, '/ repoUrl:', repoOk);
  console.log('\n>>> Cursor를 다시 열고 Agents > Repositories > iljali-app 확인');
  console.log('>>> Pinned에 "Flutter app project..." 클릭하면 메인 697메시지 대화');
}

main();
