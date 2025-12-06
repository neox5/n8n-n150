#!/usr/bin/env bash
set -euo pipefail

# Base directory = repo root (works on dev and on /root/n8n-n150)
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load DB credentials from .env (used for pg_dump)
if [[ -f "${BASE_DIR}/.env" ]]; then
  # shellcheck disable=SC1090
  source "${BASE_DIR}/.env"
else
  echo "ERROR: ${BASE_DIR}/.env not found"
  exit 1
fi

# Load restic env (repo + password)
if [[ -f "${BASE_DIR}/restic/restic.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${BASE_DIR}/restic/restic.env"
  set +a
else
  echo "ERROR: ${BASE_DIR}/restic/restic.env not found"
  exit 1
fi

# Load restic config (KEEP_* + BACKUP_SOURCE)
/root/n8n-n150/backup/restic.conf
if [[ -f "${BASE_DIR}/backup/restic.conf" ]]; then
  # shellcheck disable=SC1090
  source "${BASE_DIR}/backup/restic.conf"
else
  echo "ERROR: ${BASE_DIR}/backup/restic.conf not found"
  exit 1
fi

# Ensure backup-src structure exists
mkdir -p \
  "${BASE_DIR}/backup-src/db" \
  "${BASE_DIR}/backup-src/n8n-files" \
  "${BASE_DIR}/backup-src/config"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PG_DUMP_FILE="${BASE_DIR}/backup-src/db/n8n-${TIMESTAMP}.sql.gz"

echo "[backup] $(date) starting backup run"

# Find postgres container ID via podman-compose
cd "${BASE_DIR}"
PG_CID="$(podman-compose ps -q postgres || true)"

if [[ -z "${PG_CID}" ]]; then
  echo "ERROR: postgres container not running (podman-compose ps -q postgres returned empty)"
  exit 1
fi

echo "[backup] dumping PostgreSQL database to ${PG_DUMP_FILE}"

# Use pg_dump inside the postgres container
podman exec "${PG_CID}" pg_dump \
  -U "${POSTGRES_USER}" \
  "${POSTGRES_DB}" | gzip > "${PG_DUMP_FILE}"

echo "[backup] syncing n8n files into backup-src"
rsync -a --delete \
  "${BASE_DIR}/data/n8n/" \
  "${BASE_DIR}/backup-src/n8n-files/"

echo "[backup] copying .env into backup-src/config/.env"
cp "${BASE_DIR}/.env" "${BASE_DIR}/backup-src/config/.env"

echo "[backup] running restic backup on ${BACKUP_SOURCE}"
restic backup "${BACKUP_SOURCE}"

echo "[backup] applying retention policy: hourly=${KEEP_HOURLY} daily=${KEEP_DAILY} weekly=${KEEP_WEEKLY} monthly=${KEEP_MONTHLY}"
restic forget \
  --keep-hourly "${KEEP_HOURLY}" \
  --keep-daily  "${KEEP_DAILY}" \
  --keep-weekly "${KEEP_WEEKLY}" \
  --keep-monthly "${KEEP_MONTHLY}" \
  --prune

echo "[backup] $(date) backup run finished"
