# Installation

## Automated Installation

```bash
cd /root/n8n-n150
chmod +x deploy/files/install.sh
./deploy/files/install.sh
```

The script will:
1. Generate secrets (.env and restic.env)
2. Initialize restic repository
3. Create directory structure
4. Deploy containers
5. Install systemd units
6. Enable backup timer

**CRITICAL:** Store displayed secrets in password manager immediately.

## Manual Installation

If automated installation fails, follow these steps:

### 1. Environment Configuration

```bash
cd /root/n8n-n150

# Create .env
cp .env.example .env

# Generate secrets
export NEW_POSTGRES_PASSWORD=$(openssl rand -hex 16)
export NEW_ENCRYPTION_KEY=$(openssl rand -hex 32)

# Update .env
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${NEW_POSTGRES_PASSWORD}/" .env
sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${NEW_ENCRYPTION_KEY}/" .env
```

### 2. Restic Configuration

```bash
# Create restic.env
cp restic/restic.env.example restic/restic.env

# Generate password
export RESTIC_PASSWORD=$(openssl rand -hex 32)
sed -i "s/RESTIC_PASSWORD=.*/RESTIC_PASSWORD=${RESTIC_PASSWORD}/" restic/restic.env

# Initialize repository
source restic/restic.env
restic init
```

### 3. Directory Structure

```bash
mkdir -p \
  data/n8n \
  data/postgres/data \
  logs \
  backup-src/db \
  backup-src/n8n-files \
  backup-src/config \
  restic-repo
```

### 4. Deploy Services

```bash
podman-compose pull
podman-compose up -d
```

### 5. Install Systemd Units

```bash
cp deploy/files/n8n-stack.service /etc/systemd/system/
cp deploy/files/n8n-backup.service /etc/systemd/system/
cp deploy/files/n8n-backup.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable n8n-stack.service
systemctl enable --now n8n-backup.timer
```

## Verify Installation

```bash
# Check service status
systemctl status n8n-stack.service

# Check backup timer
systemctl list-timers n8n-backup.timer

# Check containers
podman-compose ps

# Test backup
/root/n8n-n150/backup/backup-n8n.sh
```

## Access n8n

Navigate to: `http://<N150_IP>:5678`

Complete initial n8n setup wizard.

