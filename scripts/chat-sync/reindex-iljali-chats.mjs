#!/usr/bin/env node
/**
 * Re-link scattered Cursor 3.0 composer chats to D:\1jari (iljali-app repo).
 * Run with Cursor fully quit. Creates a timestamped backup of state.vscdb first.
 *
 * Usage:
 *   node reindex-iljali-chats.mjs --analyze
 *   node reindex-iljali-chats.mjs --apply
 *   node reindex-iljali-chats.mjs --export-archive
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { DatabaseSync } from 'node:sqlite';

const TARGET = {
  workspaceId: 'cc095c556477ec81d2f10f0fc17d9fa4',
  fsPath: 'd:\\1jari',
  external: 'file:///d%3A/1jari',
  repo: 'https://github.com/YjCh01/iljali-app.git',
};

const CURSOR_USER = path.join(
  process.env.APPDATA ?? path.join(os.homedir(), 'AppData', 'Roaming'),
  'Cursor',
  'User',
);
const GLOBAL_DB = path.join(CURSOR_USER, 'globalStorage', 'state.vscdb');
const PROJECTS_ROOT = path.join(os.homedir(), '.cursor', 'projects');
const REPO_ROOT = path.resolve(path.join(import.meta.dirname, '..', '..'));

const ILJALI_PATH_MARKERS = [
  '1jari',
  'iljali',
  'empty-window',
  'daanggeun_map',
  '1jari_cursor',
  '1jari-v2',
  '1jari-admin',
];

const args = new Set(process.argv.slice(2));
const analyze = args.has('--analyze') || (!args.has('--apply') && !args.has('--export-archive'));
const apply = args.has('--apply');
const exportArchive = args.has('--export-archive');

function decodeUri(uri) {
  if (!uri) return '';
  if (typeof uri === 'string') return decodeURIComponent(uri);
  return decodeURIComponent(uri.external ?? uri.fsPath ?? '');
}

function isIljaliRelated(identifier, composerId) {
  const uri = decodeUri(identifier?.uri ?? identifier);
  const id = String(identifier?.id ?? '');
  if (ILJALI_PATH_MARKERS.some((m) => uri.toLowerCase().includes(m))) return true;
  if (/^\d{13}$/.test(id)) return true;
  for (const project of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    if (composerId && fs.existsSync(path.join(PROJECTS_ROOT, project, 'agent-transcripts', composerId))) {
      return true;
    }
  }
  return false;
}

function targetIdentifier() {
  return {
    id: TARGET.workspaceId,
    uri: {
      fsPath: TARGET.fsPath,
      scheme: 'file',
      external: TARGET.external,
    },
  };
}

function loadJson(db, key, table = 'ItemTable') {
  const row = db.prepare(`SELECT value FROM ${table} WHERE key = ?`).get(key);
  if (!row?.value) return null;
  try {
    return JSON.parse(String(row.value));
  } catch {
    return null;
  }
}

function collectTranscriptIds() {
  const ids = new Set();
  for (const project of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    const dir = path.join(PROJECTS_ROOT, project, 'agent-transcripts');
    if (!fs.existsSync(dir)) continue;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory() && entry.name.length > 8) ids.add(entry.name);
    }
  }
  return ids;
}

function scanComposerDataKeys(db) {
  return db
    .prepare(`SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'`)
    .all()
    .map((r) => r.key.replace('composerData:', ''));
}

function extractTitle(composerData) {
  if (!composerData) return '(untitled)';
  if (composerData.name) return composerData.name;
  const headers = composerData.fullConversationHeadersOnly ?? composerData.conversationHeaders ?? [];
  for (const h of headers) {
    if (h.type === 1 && h.text) return h.text.slice(0, 80);
  }
  return '(untitled)';
}

function ensureHeadersEntry(headersDoc, composerId, composerData, forceRetag) {
  const list = headersDoc.allComposers ?? (headersDoc.allComposers = []);
  let entry = list.find((c) => c.composerId === composerId);
  const identifier = targetIdentifier();
  if (!entry) {
    entry = {
      composerId,
      name: extractTitle(composerData),
      createdAt: composerData?.createdAt ?? Date.now(),
      lastUpdatedAt: composerData?.lastUpdatedAt ?? Date.now(),
      unifiedMode: composerData?.unifiedMode ?? 'agent',
      workspaceIdentifier: identifier,
    };
    list.push(entry);
    return { action: 'added', entry };
  }
  const currentUri = decodeUri(entry.workspaceIdentifier?.uri ?? entry.workspaceIdentifier);
  const targetUri = decodeUri(identifier.uri).toLowerCase();
  const needsRetag =
    forceRetag ||
    (currentUri.toLowerCase() !== TARGET.fsPath.toLowerCase() &&
      currentUri.toLowerCase() !== targetUri);
  if (needsRetag || entry.workspaceIdentifier?.id !== TARGET.workspaceId) {
    entry.workspaceIdentifier = identifier;
    entry.lastUpdatedAt = composerData?.lastUpdatedAt ?? entry.lastUpdatedAt ?? Date.now();
    return { action: 'retagged', entry };
  }
  return { action: 'unchanged', entry };
}

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function writeArchive(headersDoc, transcriptIds) {
  const outDir = path.join(REPO_ROOT, '.cursor', 'chat-archive');
  fs.mkdirSync(outDir, { recursive: true });
  const chats = (headersDoc.allComposers ?? [])
    .filter((c) => transcriptIds.has(c.composerId) || isIljaliRelated(c.workspaceIdentifier, c.composerId))
    .map((c) => ({
      composerId: c.composerId,
      name: c.name,
      createdAt: c.createdAt,
      lastUpdatedAt: c.lastUpdatedAt,
      unifiedMode: c.unifiedMode,
      workspace: decodeUri(c.workspaceIdentifier?.uri ?? c.workspaceIdentifier),
    }))
    .sort((a, b) => (b.lastUpdatedAt ?? 0) - (a.lastUpdatedAt ?? 0));

  fs.writeFileSync(
    path.join(outDir, 'index.json'),
    JSON.stringify(
      {
        repo: TARGET.repo,
        workspace: TARGET.external,
        exportedAt: new Date().toISOString(),
        count: chats.length,
        chats,
      },
      null,
      2,
    ),
  );

  const html = `<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><title>iljali-app Cursor 대화 목록</title>
<style>body{font-family:system-ui;max-width:960px;margin:2rem auto;padding:0 1rem}
table{width:100%;border-collapse:collapse}th,td{border-bottom:1px solid #ddd;padding:.5rem;text-align:left}
tr:hover{background:#f6f6ff}</style></head><body>
<h1>iljali-app — Cursor Agent 대화 (${chats.length})</h1>
<p>Repo: ${TARGET.repo}<br>Workspace: ${TARGET.external}</p>
<table><thead><tr><th>제목</th><th>ID</th><th>마지막 업데이트</th></tr></thead><tbody>
${chats.map((c) => `<tr><td>${escapeHtml(c.name ?? '')}</td><td><code>${c.composerId}</code></td><td>${c.lastUpdatedAt ? new Date(c.lastUpdatedAt).toLocaleString('ko-KR') : ''}</td></tr>`).join('\n')}
</tbody></table></body></html>`;
  fs.writeFileSync(path.join(outDir, 'index.html'), html);
  console.log(`Exported ${chats.length} chats -> ${outDir}`);
}

function main() {
  if (!fs.existsSync(GLOBAL_DB)) {
    console.error('Global DB not found:', GLOBAL_DB);
    process.exit(1);
  }

  const db = new DatabaseSync(GLOBAL_DB, apply ? {} : { readOnly: true });
  const headersDoc = loadJson(db, 'composer.composerHeaders') ?? { allComposers: [] };
  const transcriptIds = collectTranscriptIds();
  const composerIds = new Set([
    ...scanComposerDataKeys(db),
    ...transcriptIds,
    ...(headersDoc.allComposers ?? []).map((c) => c.composerId),
  ]);

  const stats = { added: 0, retagged: 0, unchanged: 0, skipped: 0 };
  const report = [];

  for (const composerId of composerIds) {
    const composerData = loadJson(db, `composerData:${composerId}`, 'cursorDiskKV');
    const headerEntry = (headersDoc.allComposers ?? []).find((c) => c.composerId === composerId);
    const identifier = headerEntry?.workspaceIdentifier ?? composerData?.workspaceIdentifier;
    const related = isIljaliRelated(identifier, composerId) || transcriptIds.has(composerId);
    if (!related) {
      stats.skipped++;
      continue;
    }
    const result = ensureHeadersEntry(headersDoc, composerId, composerData, true);
    if (result.action === 'added') stats.added++;
    else if (result.action === 'retagged') stats.retagged++;
    else stats.unchanged++;
    report.push({
      composerId,
      action: result.action,
      name: result.entry.name,
      from: decodeUri(identifier?.uri ?? identifier),
    });
  }

  console.log('\n=== iljali chat reindex report ===');
  console.log(JSON.stringify(stats, null, 2));
  console.log(`Transcript folders: ${transcriptIds.size}`);
  console.log(`Global composerData keys scanned: ${composerIds.size}`);
  console.log('\nSample (up to 20):');
  for (const row of report.slice(0, 20)) {
    console.log(`- [${row.action}] ${row.name} (${row.composerId.slice(0, 8)}…)`);
  }

  if (exportArchive || apply) {
    writeArchive(headersDoc, transcriptIds);
  }

  if (apply) {
    const backup = `${GLOBAL_DB}.backup-${Date.now()}`;
    fs.copyFileSync(GLOBAL_DB, backup);
    console.log('\nBackup:', backup);
    db.prepare(`INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)`).run(
      'composer.composerHeaders',
      JSON.stringify(headersDoc),
    );
    console.log('Applied composer.composerHeaders update.');
    console.log('>>> Cursor를 완전히 종료했다가 다시 열고, Agents > Repositories > iljali-app 에서 대화 목록을 확인하세요.');
  } else if (analyze) {
    console.log('\nDry-run only. Quit Cursor, then: .\\scripts\\sync-cursor-chats.ps1 -Apply');
  }

  db.close();
}

main();
