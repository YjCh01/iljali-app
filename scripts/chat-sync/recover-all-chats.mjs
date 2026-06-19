#!/usr/bin/env node
/**
 * FULL RECOVERY: make all iljali/1jari chats visible in Agents > Repositories > iljali-app
 * MUST run with Cursor fully quit.
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { DatabaseSync } from 'node:sqlite';
import { execSync } from 'node:child_process';

const REPO_URL = 'github.com/yjch01/iljali-app';
const TARGET_WS = 'cc095c556477ec81d2f10f0fc17d9fa4';
const TARGET_FS = 'd:\\1jari';
const TARGET_EXTERNAL = 'file:///d%3A/1jari';
const ILJALI_PROJECT_ID = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const PROJECTS_ROOT = path.join(os.homedir(), '.cursor', 'projects');

const GLOBAL_DIR = path.join(process.env.APPDATA, 'Cursor/User/globalStorage');
const GLOBAL_DB = path.join(GLOBAL_DIR, 'state.vscdb');
const WS_DB = path.join(process.env.APPDATA, 'Cursor/User/workspaceStorage', TARGET_WS, 'state.vscdb');

const TARGET_URI = {
  $mid: 1,
  fsPath: TARGET_FS,
  _sep: 1,
  external: TARGET_EXTERNAL,
  path: '/D:/1jari',
  scheme: 'file',
};

const TARGET_IDENTIFIER = { id: TARGET_WS, uri: TARGET_URI };

const TARGET_AGENT_LOCATION = {
  type: 'local',
  environment: TARGET_IDENTIFIER,
  status: 'active',
};

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

function collectTranscriptIds() {
  const ids = new Set();
  for (const project of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    const dir = path.join(PROJECTS_ROOT, project, 'agent-transcripts');
    if (!fs.existsSync(dir)) continue;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) ids.add(entry.name);
    }
  }
  return ids;
}

function isIljaliComposer(c, composerData, transcriptIds) {
  const id = c.composerId ?? c;
  if (transcriptIds.has(id)) return true;
  const uri = JSON.stringify(c.workspaceIdentifier ?? composerData?.workspaceIdentifier ?? '');
  if (/1jari|iljali|empty-window|daanggeun/i.test(uri)) return true;
  if (/^\d{13}$/.test(String(c.workspaceIdentifier?.id ?? ''))) return true;
  const repos = c.trackedGitRepos ?? composerData?.trackedGitRepos ?? [];
  if (repos.some((r) => String(r.repoPath ?? '').toLowerCase().includes('1jari'))) return true;
  const mem = c.name ?? composerData?.name ?? '';
  return false;
}

function patchEntry(entry, composerData) {
  entry.agentLocation = structuredClone(TARGET_AGENT_LOCATION);
  entry.workspaceIdentifier = structuredClone(TARGET_IDENTIFIER);
  const branch =
    entry.trackedGitRepos?.[0]?.branches?.[0]?.branchName ??
    composerData?.trackedGitRepos?.[0]?.branches?.[0]?.branchName ??
    'main';
  entry.trackedGitRepos = [
    {
      repoPath: TARGET_FS,
      repoUrl: REPO_URL,
      branches: [{ branchName: branch, lastInteractionAt: Date.now() }],
    },
  ];
  if (entry.isArchived === undefined) entry.isArchived = false;
  if (entry.isDraft === undefined) entry.isDraft = false;
}

function loadJson(db, key, table = 'ItemTable') {
  const row = db.prepare(`SELECT value FROM ${table} WHERE key = ?`).get(key);
  if (!row?.value) return null;
  return JSON.parse(String(row.value));
}

function main() {
  console.log('=== iljali-app FULL CHAT RECOVERY ===\n');

  if (isCursorRunning()) {
    console.log('Cursor is running — force closing so DB changes stick...');
    killCursor();
    // wait for file handles to release
    execSync('timeout /t 3 /nobreak >nul', { stdio: 'ignore', shell: true });
  }

  if (isCursorRunning()) {
    console.error('ERROR: Close Cursor manually (all windows), then re-run:');
    console.error('  node scripts/chat-sync/recover-all-chats.mjs');
    process.exit(1);
  }

  // Remove WAL so we work on consistent DB
  for (const suffix of ['-wal', '-shm']) {
    const p = GLOBAL_DB + suffix;
    if (fs.existsSync(p)) {
      fs.renameSync(p, p + '.pre-recover-' + Date.now());
      console.log('Moved aside:', path.basename(p));
    }
  }

  const backup = path.join(GLOBAL_DIR, `state.vscdb.pre-recover-${Date.now()}`);
  fs.copyFileSync(GLOBAL_DB, backup);
  console.log('Backup:', backup);

  const db = new DatabaseSync(GLOBAL_DB);
  const transcriptIds = collectTranscriptIds();
  console.log('Transcript folders:', transcriptIds.size);

  const headers = loadJson(db, 'composer.composerHeaders') ?? { allComposers: [] };
  const membership = loadJson(db, 'glass.localAgentProjectMembership.v1') ?? {};
  const projects = loadJson(db, 'glass.localAgentProjects.v1') ?? [];

  const allComposerIds = new Set([
    ...headers.allComposers.map((c) => c.composerId),
    ...db.prepare("SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'").all().map((r) => r.key.replace('composerData:', '')),
    ...transcriptIds,
  ]);

  let patchedHeaders = 0;
  let patchedData = 0;
  let addedToHeaders = 0;
  let membershipSet = 0;

  const headerById = new Map(headers.allComposers.map((c) => [c.composerId, c]));

  for (const composerId of allComposerIds) {
    const dataRow = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${composerId}`);
    const composerData = dataRow ? JSON.parse(String(dataRow.value)) : null;

    let header = headerById.get(composerId);
    const probe = header ?? { composerId, ...(composerData ?? {}) };
    if (!isIljaliComposer(probe, composerData, transcriptIds)) continue;

    if (!header) {
      header = {
        composerId,
        name: composerData?.name ?? '(recovered chat)',
        createdAt: composerData?.createdAt ?? Date.now(),
        lastUpdatedAt: composerData?.lastUpdatedAt ?? Date.now(),
        unifiedMode: composerData?.unifiedMode ?? 'agent',
        type: 'head',
      };
      headers.allComposers.push(header);
      headerById.set(composerId, header);
      addedToHeaders++;
    }

    patchEntry(header, composerData);
    patchedHeaders++;

    if (composerData) {
      patchEntry(composerData, composerData);
      db.prepare('INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)').run(
        `composerData:${composerId}`,
        JSON.stringify(composerData),
      );
      patchedData++;
    }

    if (membership[composerId] !== ILJALI_PROJECT_ID) {
      membership[composerId] = ILJALI_PROJECT_ID;
      membershipSet++;
    }
  }

  // Fix iljali project entry
  let project = projects.find((p) => p.id === ILJALI_PROJECT_ID);
  if (!project) {
    project = {
      id: ILJALI_PROJECT_ID,
      name: 'iljali-app',
      workspace: TARGET_IDENTIFIER,
      createdAt: Date.now(),
      lastUpdatedAt: Date.now(),
      isArchived: false,
    };
    projects.push(project);
  } else {
    project.name = 'iljali-app';
    project.workspace = structuredClone(TARGET_IDENTIFIER);
    project.lastUpdatedAt = Date.now();
  }

  // Sidebar settings — ensure iljali repo section exists
  const sidebar = loadJson(db, 'cursor/glassSidebarSettings');
  if (sidebar) {
    sidebar.groupBy = sidebar.groupBy ?? 'repository';
    sidebar.sectionOrderByGroupBy = sidebar.sectionOrderByGroupBy ?? {};
    sidebar.sectionOrderByGroupBy.repository = sidebar.sectionOrderByGroupBy.repository ?? [];
    const repoKey = `repo:${REPO_URL}`;
    if (!sidebar.sectionOrderByGroupBy.repository.includes(repoKey)) {
      sidebar.sectionOrderByGroupBy.repository.unshift(repoKey);
    }
    db.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
      'cursor/glassSidebarSettings',
      JSON.stringify(sidebar),
    );
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

  // Workspace DB — selectedComposerIds for sidebar fallback
  if (fs.existsSync(WS_DB)) {
    const wdb = new DatabaseSync(WS_DB);
    const wComposer = loadJson(wdb, 'composer.composerData') ?? {};
    const iljaliIds = Object.entries(membership)
      .filter(([, v]) => v === ILJALI_PROJECT_ID)
      .map(([k]) => k);
    wComposer.selectedComposerIds = iljaliIds.slice(0, 50);
    wComposer.lastFocusedComposerIds = iljaliIds.slice(0, 5);
    wComposer.hasMigratedComposerData = true;
    wdb.prepare('INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)').run(
      'composer.composerData',
      JSON.stringify(wComposer),
    );
    wdb.close();
    console.log('Workspace DB: set selectedComposerIds', iljaliIds.length);
  }

  db.close();

  // Verify on fresh read
  const vdb = new DatabaseSync(GLOBAL_DB, { readOnly: true });
  const vh = loadJson(vdb, 'composer.composerHeaders');
  let withLoc = 0;
  let withRepo = 0;
  for (const c of vh.allComposers) {
    if (c.agentLocation?.environment?.id === TARGET_WS) withLoc++;
    if (JSON.stringify(c.trackedGitRepos ?? '').includes('iljali-app')) withRepo++;
  }
  const vmem = Object.values(loadJson(vdb, 'glass.localAgentProjectMembership.v1') ?? {}).filter(
    (v) => v === ILJALI_PROJECT_ID,
  ).length;
  const ba351 = vdb.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get('composerData:ba351e43-e44b-4221-a8f1-7ec22087ed1b');
  const ba351ok = ba351 ? JSON.parse(String(ba351.value)).name : 'MISSING';
  vdb.close();

  console.log('\n=== RECOVERY DONE ===');
  console.log(JSON.stringify({
    patchedHeaders,
    patchedData,
    addedToHeaders,
    membershipSet,
    verify_agentLocation_1jari: withLoc,
    verify_repoUrl: withRepo,
    verify_glass_membership: vmem,
    main_chat_ba351: ba351ok,
    total_headers: vh.allComposers.length,
  }, null, 2));

  console.log('\n>>> Cursor를 다시 켜고 Agents > Repositories > iljali-app 확인');
  console.log('>>> 메인 대화: "Flutter app project structure and UI design" (ba351e43)');
}

main();
