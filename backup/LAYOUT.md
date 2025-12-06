# Target System Layout (N150)

Root directory:

/root/n8n-n150/

compose/
  podman-compose.yml
  .env            # real secrets (NOT in git)

data/
  n8n/            # bind-mounted into n8n container
  postgres/       # bind-mounted into postgres container

backup-src/
  db/             # PostgreSQL dumps
  n8n-files/      # copy or link of data/n8n
  config/
    .env          # copied from compose/.env at backup time

restic/
  restic.env      # real restic password + repo path (NOT in git)
  restic.conf     # retention and backup policy (committed)

restic-repo/
  # encrypted restic repository data

logs/
  backup.log
