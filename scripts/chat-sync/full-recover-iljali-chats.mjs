#!/usr/bin/env node
/**
 * FULL RECOVERY — Cursor must be CLOSED.
 * Restores iljali-app / D:\1jari chats into Glass Agents Repositories view.
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { DatabaseSync } from 'node:sqlite';
import { execSync } from 'node:child_process';

const REPO_URL = 'github.com/yjch01/iljali-app';
const WS_ID = 'cc095c556477ec81d2f10f0fc17d9fa4';
const WS_FS = 'd:\\1jari';
const WS_EXTERNAL = 'file:///d%3A/1jari';
const ILJALI_PROJECT_ID = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const PROJECTS_ROOT = path.join(os.homedir(), '.cursor', 'projects');

const GLOBAL_DIR = path.join(process.env.APPDATA, 'Cursor/User/globalStorage');
const GLOBAL_DB = path.join(GLOBAL_DIR, 'state.vscdb');
const WS_DB = path.join(process.env.APPDATA, 'Cursor/User/workspaceStorage', WS_ID, 'state.vscdb');

const TARGET_URI = { $mid: 1, fsPath: WS_FS, _sep: 1, external: WS_EXTERNAL, path: '/D:/1jari', scheme: 'file' };
const TARGET_ID = { id: WS_ID, uri: TARGET_URI };
const AGENT_LOC = { type: 'local', environment: TARGET_ID, status: 'active' };

function isCursorRunning() {
  try {
    const out = execSync('tasklist /FI "IMAGENAME eq Cursor.exe" /NH', { encoding: 'utf8' });
    return out.toLowerCase().includes('cursor.exe');
  } catch {
    return false;
  }
}

function killCursor() {
  try {
    execSync('taskkill /F /IM Cursor.exe /T', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function checkpointWal(dbPath) {
  const wal = dbPath + '-wal';
  if (!fs.existsSync(wal)) return;
  const db = new DatabaseSync(dbPath);
  db.exec('PRAGMA wal_checkpoint(FULL)');
  db.close();
}

function loadJson(db, key, table = 'ItemTable') {
  const row = db.prepare(`SELECT value FROM ${table} WHERE key = ?`).get(key);
  if (!row?.value) return null;
  return JSON.parse(String(row.value));
}

function isIljali(c, composerData, transcriptIds) {
  const id = c.composerId ?? c;
  if (transcriptIds.has(id)) return true;
  const uri = JSON.stringify(c.workspaceIdentifier ?? composerData?.workspaceIdentifier ?? '');
  if (/1jari|iljali|empty-window/i.test(uri)) return true;
  if (/^\d{13}$/.test(String(c.workspaceIdentifier?.id ?? ''))) return true;
  const repos = c.trackedGitRepos ?? composerData?.trackedGitRepos ?? [];
  return repos.some((r) => String(r.repoPath ?? r.repoUrl ?? '').toLowerCase().includes('1jari'));
}

function collectTranscriptIds() {
  const ids = new Set();
  for (const p of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    const dir = path.join(PROJECTS_ROOT, p, 'agent-transcripts');
    if (!fs.existsSync(dir)) continue;
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.isDirectory()) ids.add(e.name);
    }
  }
  return ids;
}

function patchEntry(entry, composerData) {
  entry.agentLocation = structuredClone(AGENT_LOC);
  entry.workspaceIdentifier = structuredClone(TARGET_ID);
  const branch = composerData?.trackedGitRepos?.[0]?.branches?.[0]?.branchName
    ?? entry.trackedGitRepos?.[0]?.branches?.[0]?.branchName
    ?? 'main';
  entry.trackedGitRepos = [{
    repoPath: WS_FS,
    repoUrl: REPO_URL,
    branches: [{ branchName: branch, lastInteractionAt: entry.lastUpdatedAt ?? Date.now() }],
  }];
  if (entry.isArchived === undefined) entry.isArchived = false;
  entry.isDraft = false;
}

function verify(db) {
  const h = loadJson(db, 'composer.composerHeaders');
  let loc = 0, repo = 0, iljali = 0;
  for (const c of h.allComposers ?? []) {
    if (isIljali(c, null, new Set())) iljali++;
    if (c.agentLocation?.environment?.id === WS_ID) loc++;
    if (JSON.stringify(c.trackedGitRepos ?? '').includes('iljali-app')) repo++;
  }
  const mem = loadJson(db, 'glass.localAgentProjectMembership.v1') ?? {};
  const memCount = Object.values(mem).filter((v) => v === ILJALI_PROJECT_ID).length;
  const ba351 = db.prepare("SELECT length(value) len FROM cursorDiskKV WHERE key='composerData:ba351e43-e44b-4221-a8f1-7ec22087ed1b'").get();
  const bubbles = db.prepare("SELECT count(*) c FROM cursorDiskKV WHERE key LIKE 'bubbleId:ba351e43-%'").get().c;
  return { headers: h.allComposers?.length ?? 0, iljali, agentLoc: loc, repoUrl: repo, membership: memCount, ba351Bytes: ba351?.len ?? 0, ba351Bubbles: bubbles };
}

function main() {
  const force = process.argv.includes('--force-kill');
  if (isCursorRunning()) {
    if (force) {
      console.log('Killing Cursor...');
      killCursor();
      for (let i = 0; i < 10; i++) {
        if (!isCursorRunning()) break;
        execSync('timeout /t 1 /nobreak >nul', { shell: true, stdio: 'ignore' });
      }
    } else {
      console.error('ERROR: Cursor is running. Close Cursor completely, then run:');
      console.error('  node full-recover-iljali-chats.mjs --force-kill');
      process.exit(1);
    }
  }

  if (!fs.existsSync(GLOBAL_DB)) {
    console.error('Global DB missing:', GLOBAL_DB);
    process.exit(1);
  }

  checkpointWal(GLOBAL_DB);
  const backup = path.join(GLOBAL_DIR, `state.vscdb.pre-full-recover-${Date.now()}`);
  fs.copyFileSync(GLOBAL_DB, backup);
  console.log('Backup:', backup);

  const transcriptIds = collectTranscriptIds();
  console.log('Transcript folders:', transcriptIds.size);

  const db = new DatabaseSync(GLOBAL_DB);
  const headers = loadJson(db, 'composer.composerHeaders') ?? { allComposers: [] };
  const membership = loadJson(db, 'glass.localAgentProjectMembership.v1') ?? {};
  const projects = loadJson(db, 'glass.localAgentProjects.v1') ?? [];
  const sidebar = loadJson(db, 'cursor/glassSidebarSettings') ?? {};

  let patched = 0;
  const iljaliComposerIds = [];

  for (const c of headers.allComposers) {
    const dataRow = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${c.composerId}`);
    const composerData = dataRow ? JSON.parse(String(dataRow.value)) : null;
    if (!isIljali(c, composerData, transcriptIds)) continue;

    patchEntry(c, composerData);
    iljaliComposerIds.push(c.composerId);
    patched++;

    if (composerData) {
      patchEntry(composerData, composerData);
      db.prepare('INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)').run(
        `composerData:${c.composerId}`,
        JSON.stringify(composerData),
      );
    }
    membership[c.composerId] = ILJALI_PROJECT_ID;
  }

  // Also scan composerData-only blobs not in headers
  const dataKeys = db.prepare("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'").all();
  for (const { key } of dataKeys) {
    const id = key.replace('composerData:', '');
    if (iljaliComposerIds.includes(id)) continue;
    const composerData = JSON.parse(String(db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(key).value));
    if (!isIljali({ composerId: id }, composerData, transcriptIds)) continue;
    if (!headers.allComposers.find((c) => c.composerId === id)) {
      headers.allComposers.push({
        composerId: id,
        name: composerData.name ?? '(recovered)',
        createdAt: composerData.createdAt ?? Date.now(),
        lastUpdatedAt: composerData.lastUpdatedAt ?? Date.now(),
        unifiedMode: composerData.unifiedMode ?? 'agent',
        isArchived: false,
        isDraft: false,
      });
    }
    const entry = headers.allComposers.find((c) => c.composerId === id);
    patchEntry(entry, composerData);
    patchEntry(composerData, composerData);
    db.prepare('INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)').run(key, JSON.stringify(composerData));
    membership[id] = ILJALI_PROJECT_ID;
    iljaliComposerIds.push(id);
    patched++;
  }

  const proj = projects.find((p) => p.id === ILJALI_PROJECT_ID);
  if (proj) {
    proj.name = 'iljali-app';
    proj.workspace = structuredClone(TARGET_ID);
    proj.lastUpdatedAt = Date.now();
  }

  sidebar.groupBy = sidebar.groupBy ?? 'repository';
  sidebar.sectionOrderByGroupBy = sidebar.sectionOrderByGroupBy ?? {};
  const repoKey = `repo:${REPO_URL}`;
  if (!sidebar.sectionOrderByGroupBy.repository?.includes(repoKey)) {
    sidebar.sectionOrderByGroupBy.repository = [repoKey, ...(sidebar.sectionOrderByGroupBy.repository ?? [])];
  }

  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'composer.composerHeaders',
    JSON.stringify(headers),
  );
  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'glass.localAgentProjectMembership.v1',
    JSON.stringify(membership),
  );
  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'glass.localAgentProjects.v1',
    JSON.stringify(projects),
  );
  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
    'cursor/glassSidebarSettings',
    JSON.stringify(sidebar),
  );

  // Workspace DB — selectedComposerIds for IDE fallback
  if (fs.existsSync(WS_DB)) {
    checkpointWal(WS_DB);
    fs.copyFileSync(WS_DB, WS_DB + `.backup-${Date.now()}`);
    const wdb = new DatabaseSync(WS_DB);
    const cd = loadJson(wdb, 'composer.composerData') ?? {};
    cd.selectedComposerIds = iljaliComposerIds.slice(0, 50);
    cd.lastFocusedComposerIds = [iljaliComposerIds[0] ?? 'ba351e43-e44b-4221-a8f1-7ec22087ed1b'];
    cd.hasMigratedComposerData = true;
    wdb.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
      'composer.composerData',
      JSON.stringify(cd),
    );
    wdb.close();
  }

  db.exec('PRAGMA wal_checkpoint(FULL)');
  const after = verify(db);
  db.close();

  console.log('\n=== RECOVERY COMPLETE ===');
  console.log('Patched composers:', patched);
  console.log('Verification:', JSON.stringify(after, null, 2));
  console.log('\n>>> Cursor를 다시 열고 Agents > Repositories > iljali-app 확인');
  console.log('>>> 메인 대화: Pinned 또는 iljali-app > "Flutter app project structure and UI design"');
}

main();
