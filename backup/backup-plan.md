# Backup Execution Plan (Logical)

1. Create fresh PostgreSQL dump into:
   /root/n8n-n150/backup-src/db/

2. Ensure file data is present at:
   /root/n8n-n150/backup-src/n8n-files/
   (source: /root/n8n-n150/data/n8n/)

3. Copy runtime configuration:
   /root/n8n-n150/compose/.env
   -> /root/n8n-n150/backup-src/config/.env

4. Run restic snapshot on:
   /root/n8n-n150/backup-src/

5. Apply retention policy (from restic.conf):
   - hourly
   - daily
   - weekly
   - monthly

6. Prune unneeded data.
