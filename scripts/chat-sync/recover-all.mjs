#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execSync } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';

const REPO_URL = 'github.com/yjch01/iljali-app';
const TARGET_WS = 'cc095c556477ec81d2f10f0fc17d9fa4';
const TARGET_FS = 'd:\\1jari';
const TARGET_EXTERNAL = 'file:///d%3A/1jari';
const ILJALI_PROJECT_ID = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const PROJECTS_ROOT = path.join(os.homedir(), '.cursor', 'projects');
const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');

const TARGET_URI = { $mid: 1, fsPath: TARGET_FS, _sep: 1, external: TARGET_EXTERNAL, path: '/D:/1jari', scheme: 'file' };
const TARGET_ID = { id: TARGET_WS, uri: TARGET_URI };
const TARGET_LOC = { type: 'local', environment: TARGET_ID, status: 'active' };

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function killCursor() {
  try {
    execSync('taskkill /F /IM Cursor.exe /T', { stdio: 'pipe' });
    console.log('Cursor terminated.');
  } catch {
    console.log('Cursor was not running.');
  }
  sleep(4000);
}

function isIljali(c, data, id) {
  const uri = JSON.stringify(c?.workspaceIdentifier ?? data?.workspaceIdentifier ?? '');
  if (/1jari|iljali/i.test(uri)) return true;
  if (/^\d{13}$/.test(String(c?.workspaceIdentifier?.id ?? ''))) return true;
  for (const p of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    if (fs.existsSync(path.join(PROJECTS_ROOT, p, 'agent-transcripts', id))) return true;
  }
  const repos = c?.trackedGitRepos ?? data?.trackedGitRepos ?? [];
  return repos.some((r) => String(r.repoPath ?? '').toLowerCase().includes('1jari'));
}

function tracked(existing) {
  const branch = existing?.[0]?.branches?.[0]?.branchName ?? 'main';
  return [{ repoPath: TARGET_FS, repoUrl: REPO_URL, branches: [{ branchName: branch, lastInteractionAt: Date.now() }] }];
}

function patch(entry, data) {
  let ch = false;
  if (!entry.agentLocation || entry.agentLocation.environment?.id !== TARGET_WS) {
    entry.agentLocation = structuredClone(TARGET_LOC);
    ch = true;
  }
  const repos = tracked(entry.trackedGitRepos ?? data?.trackedGitRepos);
  if (JSON.stringify(entry.trackedGitRepos ?? null) !== JSON.stringify(repos)) {
    entry.trackedGitRepos = repos;
    ch = true;
  }
  if (entry.workspaceIdentifier?.id !== TARGET_WS) {
    entry.workspaceIdentifier = structuredClone(TARGET_ID);
    ch = true;
  }
  if (entry.isArchived) { entry.isArchived = false; ch = true; }
  return ch;
}

function title(data) {
  if (data?.name) return data.name;
  for (const h of data?.fullConversationHeadersOnly ?? []) {
    if (h.type === 1 && h.text) return String(h.text).slice(0, 80);
  }
  return '(recovered chat)';
}

killCursor();

const backup = `${GLOBAL}.backup-recover-${Date.now()}`;
fs.copyFileSync(GLOBAL, backup);
console.log('Backup:', backup);

const db = new DatabaseSync(GLOBAL);
try { db.exec('PRAGMA wal_checkpoint(FULL)'); } catch { /* ok */ }

const headers = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value));
const membership = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjectMembership.v1'").get()?.value ?? '{}'));
const projects = JSON.parse(String(db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjects.v1'").get()?.value ?? '[]'));

const ids = db.prepare("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'").all().map((r) => r.key.slice(13));
const byId = new Map((headers.allComposers ?? []).map((c) => [c.composerId, c]));

let added = 0, patchedH = 0, patchedD = 0, mem = 0;

for (const id of ids) {
  const row = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${id}`);
  if (!row) continue;
  const data = JSON.parse(String(row.value));
  if (!isIljali(byId.get(id), data, id)) continue;

  let h = byId.get(id);
  if (!h) {
    h = {
      composerId: id,
      name: title(data),
      createdAt: data.createdAt ?? Date.now(),
      lastUpdatedAt: data.lastUpdatedAt ?? Date.now(),
      unifiedMode: data.unifiedMode ?? 'agent',
      type: 'head',
      isArchived: false,
    };
    headers.allComposers.push(h);
    byId.set(id, h);
    added++;
  }
  if (patch(h, data)) patchedH++;
  if (patch(data, data)) {
    db.prepare('INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)').run(`composerData:${id}`, JSON.stringify(data));
    patchedD++;
  }
  if (membership[id] !== ILJALI_PROJECT_ID) { membership[id] = ILJALI_PROJECT_ID; mem++; }
}

headers.allComposers.sort((a, b) => (b.lastUpdatedAt ?? 0) - (a.lastUpdatedAt ?? 0));

const proj = projects.find((p) => p.id === ILJALI_PROJECT_ID);
if (proj) {
  proj.name = 'iljali-app';
  proj.workspace = structuredClone(TARGET_ID);
  proj.lastUpdatedAt = Date.now();
  proj.isArchived = false;
}

const sidebarRow = db.prepare("SELECT value FROM ItemTable WHERE key='cursor/glassSidebarSettings'").get();
if (sidebarRow) {
  const s = JSON.parse(String(sidebarRow.value));
  s.groupBy = 'repository';
  s.filter ??= { show: [] };
  const show = new Set([...(s.filter.show ?? []), 'local', 'cloud', 'done', 'draft', 'running', 'needs_attention']);
  s.filter.show = [...show];
  s.sectionOrderByGroupBy ??= { repository: [] };
  const order = s.sectionOrderByGroupBy.repository ?? [];
  for (const w of [`workspace:${TARGET_WS}`, `repo:${REPO_URL}`]) if (!order.includes(w)) order.unshift(w);
  s.sectionOrderByGroupBy.repository = order;
  db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run('cursor/glassSidebarSettings', JSON.stringify(s));
}

db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run('composer.composerHeaders', JSON.stringify(headers));
db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run('glass.localAgentProjectMembership.v1', JSON.stringify(membership));
db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run('glass.localAgentProjects.v1', JSON.stringify(projects));

let loc = 0, repo = 0, iljali = 0;
for (const c of headers.allComposers) {
  if (!isIljali(c, null, c.composerId)) continue;
  iljali++;
  if (c.agentLocation?.environment?.id === TARGET_WS) loc++;
  if (JSON.stringify(c.trackedGitRepos ?? '').includes('iljali-app')) repo++;
}

const memTotal = Object.values(membership).filter((v) => v === ILJALI_PROJECT_ID).length;
const ba351 = db.prepare('SELECT count(*) c FROM cursorDiskKV WHERE key LIKE ?').get('bubbleId:ba351e43-e44b-4221-a8f1-7ec22087ed1b:%').c;

db.close();

console.log(JSON.stringify({ iljaliChats: iljali, agentLocationSet: loc, repoUrlSet: repo, glassMembership: memTotal, addedHeaders: added, patchedHeaders: patchedH, patchedData: patchedD, ba351Bubbles: ba351 }, null, 2));
console.log('\nRECOVERY COMPLETE. Re-open Cursor -> D:\\1jari -> Agents sidebar.');
