#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/root/n8n-n150"

echo "[install] Starting n8n-n150 deployment"

# Verify we're in the repository
if [[ ! -f "${REPO_DIR}/podman-compose.yml" ]]; then
  echo "ERROR: Repository not found at ${REPO_DIR}"
  exit 1
fi

cd "${REPO_DIR}"

# Generate secrets
echo "[install] Generating secrets"
NEW_POSTGRES_PASSWORD=$(openssl rand -hex 16)
NEW_ENCRYPTION_KEY=$(openssl rand -hex 32)
NEW_RESTIC_PASSWORD=$(openssl rand -hex 32)

# Create .env from example
if [[ ! -f .env ]]; then
  echo "[install] Creating .env file"
  cp .env.example .env
  sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${NEW_POSTGRES_PASSWORD}/" .env
  sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_ENCRYPTION_KEY}/" .env
else
  echo "[install] .env already exists, skipping"
fi

# Create restic.env
if [[ ! -f restic/restic.env ]]; then
  echo "[install] Creating restic/restic.env"
  cp restic/restic.env.example restic/restic.env
  sed -i "s/RESTIC_PASSWORD=.*/RESTIC_PASSWORD=${NEW_RESTIC_PASSWORD}/" restic/restic.env
else
  echo "[install] restic/restic.env already exists, skipping"
fi

# Create required directories
echo "[install] Creating directory structure"
mkdir -p data/n8n data/postgres/data logs backup-src/db backup-src/n8n-files backup-src/config restic-repo

# Initialize restic repository
if [[ ! -f restic-repo/config ]]; then
  echo "[install] Initializing restic repository"
  source restic/restic.env
  restic init
else
  echo "[install] Restic repository already initialized"
fi

# Pull container images
echo "[install] Pulling container images"
podman-compose pull

# Start services
echo "[install] Starting services"
podman-compose up -d

# Install systemd units
echo "[install] Installing systemd units"
cp deploy/files/n8n-stack.service /etc/systemd/system/
cp deploy/files/n8n-backup.service /etc/systemd/system/
cp deploy/files/n8n-backup.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable n8n-stack.service
systemctl enable --now n8n-backup.timer

echo "[install] Deployment complete"
echo ""
echo "CRITICAL: Store these secrets in password manager:"
echo "  POSTGRES_PASSWORD: ${NEW_POSTGRES_PASSWORD}"
echo "  N8N_ENCRYPTION_KEY: ${NEW_ENCRYPTION_KEY}"
echo "  RESTIC_PASSWORD: ${NEW_RESTIC_PASSWORD}"
echo ""
echo "Access n8n at: http://$(hostname -I | awk '{print $1}'):5678"
