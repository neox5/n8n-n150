# Restore Notes

## A. Fast Rollback (same machine)

1. Stop n8n and postgres
2. Restore snapshot to /root/n8n/backup-src
3. Restore DB from dump
4. Restore state/n8n from backup
5. Start services

## B. Disaster Recovery (new machine)

1. Install OS + podman + restic
2. Recreate /root/n8n layout
3. Restore snapshot to /root/n8n/backup-src
4. Populate:
   - state/
   - compose/.env
5. Run podman-compose up -d
