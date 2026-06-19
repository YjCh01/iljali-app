#!/usr/bin/env node
/**
 * Fix Glass Agents sidebar: attach iljali local chats to repo:github.com/yjch01/iljali-app
 * by filling agentLocation + trackedGitRepos on composer headers and composerData.
 *
 * Quit Cursor fully before --apply.
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { DatabaseSync } from 'node:sqlite';

const REPO_URL = 'github.com/yjch01/iljali-app';
const TARGET_WS = 'cc095c556477ec81d2f10f0fc17d9fa4';
const TARGET_FS = 'd:\\1jari';
const TARGET_EXTERNAL = 'file:///d%3A/1jari';
const ILJALI_PROJECT_ID = 'd932dde3-7682-4417-9e8d-9d635272d5cd';
const PROJECTS_ROOT = path.join(os.homedir(), '.cursor', 'projects');

const GLOBAL = path.join(process.env.APPDATA, 'Cursor/User/globalStorage/state.vscdb');
const apply = process.argv.includes('--apply');

const TARGET_URI = {
  $mid: 1,
  fsPath: TARGET_FS,
  _sep: 1,
  external: TARGET_EXTERNAL,
  path: '/D:/1jari',
  scheme: 'file',
};

const TARGET_IDENTIFIER = {
  id: TARGET_WS,
  uri: TARGET_URI,
};

const TARGET_AGENT_LOCATION = {
  type: 'local',
  environment: TARGET_IDENTIFIER,
  status: 'active',
};

function isIljaliComposer(c, composerData) {
  const id = c.composerId;
  const uri = JSON.stringify(c.workspaceIdentifier ?? composerData?.workspaceIdentifier ?? '');
  if (uri.toLowerCase().includes('1jari') || uri.toLowerCase().includes('iljali')) return true;
  if (String(c.workspaceIdentifier?.id ?? '').match(/^\d{13}$/)) return true;
  for (const p of ['d-1jari', 'empty-window', 'd-1jari-v2', 'd-1jari-admin']) {
    if (fs.existsSync(path.join(PROJECTS_ROOT, p, 'agent-transcripts', id))) return true;
  }
  const repos = c.trackedGitRepos ?? composerData?.trackedGitRepos ?? [];
  return repos.some((r) => String(r.repoPath ?? '').toLowerCase().includes('1jari'));
}

function buildTrackedGitRepos(existing) {
  const now = Date.now();
  const branch = existing?.[0]?.branches?.[0]?.branchName ?? 'main';
  return [
    {
      repoPath: TARGET_FS,
      repoUrl: REPO_URL,
      branches: [{ branchName: branch, lastInteractionAt: now }],
    },
  ];
}

function patchComposerEntry(entry, composerData) {
  let changed = false;
  if (!entry.agentLocation || entry.agentLocation.environment?.id !== TARGET_WS) {
    entry.agentLocation = structuredClone(TARGET_AGENT_LOCATION);
    changed = true;
  }
  const repos = buildTrackedGitRepos(entry.trackedGitRepos ?? composerData?.trackedGitRepos);
  const before = JSON.stringify(entry.trackedGitRepos ?? null);
  entry.trackedGitRepos = repos;
  if (before !== JSON.stringify(repos)) changed = true;

  if (entry.workspaceIdentifier?.id !== TARGET_WS) {
    entry.workspaceIdentifier = structuredClone(TARGET_IDENTIFIER);
    changed = true;
  }
  return changed;
}

function main() {
  const db = new DatabaseSync(GLOBAL, apply ? {} : { readOnly: true });
  const headers = JSON.parse(db.prepare("SELECT value FROM ItemTable WHERE key='composer.composerHeaders'").get().value);
  const membership = JSON.parse(
    db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjectMembership.v1'").get()?.value ?? '{}',
  );
  const projects = JSON.parse(
    db.prepare("SELECT value FROM ItemTable WHERE key='glass.localAgentProjects.v1'").get()?.value ?? '[]',
  );

  let headerPatched = 0;
  let dataPatched = 0;
  let membershipAdded = 0;

  for (const c of headers.allComposers) {
    const dataRow = db.prepare('SELECT value FROM cursorDiskKV WHERE key = ?').get(`composerData:${c.composerId}`);
    const composerData = dataRow ? JSON.parse(String(dataRow.value)) : null;
    if (!isIljaliComposer(c, composerData)) continue;

    if (patchComposerEntry(c, composerData)) headerPatched++;

    if (composerData) {
      const dataChanged = patchComposerEntry(composerData, composerData);
      if (dataChanged && apply) {
        db.prepare('INSERT OR REPLACE INTO cursorDiskKV (key, value) VALUES (?, ?)').run(
          `composerData:${c.composerId}`,
          JSON.stringify(composerData),
        );
        dataPatched++;
      } else if (dataChanged) {
        dataPatched++;
      }
    }

    if (membership[c.composerId] !== ILJALI_PROJECT_ID) {
      membership[c.composerId] = ILJALI_PROJECT_ID;
      membershipAdded++;
    }
  }

  const project = projects.find((p) => p.id === ILJALI_PROJECT_ID);
  if (project) {
    project.name = 'iljali-app';
    project.workspace = structuredClone(TARGET_IDENTIFIER);
    project.lastUpdatedAt = Date.now();
  }

  console.log(JSON.stringify({ headerPatched, dataPatched, membershipAdded, totalIljali: Object.values(membership).filter((v) => v === ILJALI_PROJECT_ID).length }, null, 2));

  if (apply) {
    const backup = `${GLOBAL}.backup-glass-${Date.now()}`;
    fs.copyFileSync(GLOBAL, backup);
    console.log('Backup:', backup);
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
    console.log('Applied Glass repo linkage. Restart Cursor completely.');
  } else {
    console.log('Dry run. Quit Cursor, then: node fix-glass-repo-agents.mjs --apply');
  }

  db.close();
}

main();
