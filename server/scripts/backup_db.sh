#!/usr/bin/env bash
# 서버에서 실행 — Postgres(db 컨테이너) 전체 덤프를 타임스탬프 파일로 저장하고
# 오래된 백업을 정리한다. 실행 방식(택1):
#   1) 수동: ssh 서버 접속 후 이 스크립트 직접 실행
#   2) 정기 실행: crontab -e 에 아래 한 줄 추가(매일 새벽 3시)
#        0 3 * * * ILJARI_SERVER_DIR=/opt/iljari/server /opt/iljari/server/scripts/backup_db.sh >> /var/log/iljari-db-backup.log 2>&1
set -euo pipefail

SERVER_DIR="${ILJARI_SERVER_DIR:-/opt/iljari/server}"
BACKUP_DIR="${ILJARI_DB_BACKUP_DIR:-/opt/iljari/backups}"
RETENTION_DAYS="${ILJARI_DB_BACKUP_RETENTION_DAYS:-14}"

mkdir -p "${BACKUP_DIR}"
cd "${SERVER_DIR}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
dump_file="${BACKUP_DIR}/iljari-${timestamp}.sql.gz"

echo "[backup] dumping Postgres → ${dump_file}"
docker compose exec -T db pg_dump -U iljari iljari | gzip > "${dump_file}"

if [ ! -s "${dump_file}" ]; then
  echo "[backup] FAILED — dump file is empty, removing" >&2
  rm -f "${dump_file}"
  exit 1
fi

echo "[backup] OK — $(du -h "${dump_file}" | cut -f1)"

echo "[backup] pruning dumps older than ${RETENTION_DAYS}일"
find "${BACKUP_DIR}" -name 'iljari-*.sql.gz' -mtime "+${RETENTION_DAYS}" -print -delete
