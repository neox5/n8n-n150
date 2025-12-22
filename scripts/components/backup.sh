#!/usr/bin/env bash
set -euo pipefail

component_name="backup"
lifecycle_mode="systemd"

backup_service="n8n-backup.service"
backup_timer="n8n-backup.timer"
unit_names=( "${backup_service}" "${backup_timer}" )

supported_verbs=(
  install
  uninstall
  secrets
  secrets-deploy
  start
  stop
  restart
  status
  check
  run
)

requires_root_verbs=(
  install
  uninstall
  secrets-deploy
  start
  stop
  restart
  run
)

_install_unit_from_repo() {
  local unit="$1"
  local unit_file="${REPO_SYSTEMD_DIR}/${unit}"
  [[ -f "$unit_file" ]] || die "unit file not found: $unit_file"

  local dst="${SYSTEMD_UNIT_DIR}/${unit}"
  ensure_dir "$(dirname -- "$dst")"

  # Rewrite backup script path to installed scripts dir.
  sed "s|ExecStart=/opt/n8n/scripts/backup-n8n.sh|ExecStart=${INSTALL_SCRIPTS}/backup-n8n.sh|g; \
       s|WorkingDirectory=/opt/n8n|WorkingDirectory=${INSTALL_PREFIX_SHARE}|g" \
    "$unit_file" >"$dst"

  chmod 0644 "$dst"
}

c_install() {
  require_root
  require_cmd rsync sed

  ensure_dir "${INSTALL_SCRIPTS}"
  ensure_dir "${INSTALL_CONFIG}"
  ensure_dir "${INSTALL_BACKUP}/staging/db"
  ensure_dir "${INSTALL_BACKUP}/staging/n8n-files"
  ensure_dir "${INSTALL_BACKUP}/staging/config"
  ensure_dir "${INSTALL_BACKUP}/restic-repo"

  # Deploy backup.conf with production paths
  sed "s|BACKUP_SOURCE=/backup-data/staging|BACKUP_SOURCE=${INSTALL_BACKUP}/staging|g; \
       s|RESTIC_REPOSITORY=/backup-data/restic-repo|RESTIC_REPOSITORY=${INSTALL_BACKUP}/restic-repo|g" \
    "${REPO_CONFIG_DIR}/backup/backup.conf" > "${INSTALL_CONFIG}/backup.conf"
  chmod 0644 "${INSTALL_CONFIG}/backup.conf"

  # Deploy backup script with production paths
  sed "s|BASE_DIR=\"/opt/n8n\"|BASE_DIR=\"${INSTALL_PREFIX_VAR}\"|g; \
       s|/config/n8n/n8n.env|${INSTALL_CONFIG}/n8n.env|g; \
       s|/config/backup/backup.env|${INSTALL_CONFIG}/backup.env|g; \
       s|/config/backup/backup.conf|${INSTALL_CONFIG}/backup.conf|g; \
       s|cd \"\${BASE_DIR}/compose\"|cd ${INSTALL_COMPOSE}|g; \
       s|\${BASE_DIR}/config/n8n/n8n.env|${INSTALL_CONFIG}/n8n.env|g" \
    "${REPO_SCRIPTS_DIR}/backup-n8n.sh" > "${INSTALL_SCRIPTS}/backup-n8n.sh"
  chmod 0755 "${INSTALL_SCRIPTS}/backup-n8n.sh"

  # Units
  _install_unit_from_repo "${backup_service}"
  _install_unit_from_repo "${backup_timer}"
  systemd_daemon_reload
}

c_uninstall() {
  require_root

  systemd_disable_stop "${backup_timer}" "${backup_service}"
  systemd_remove_unit "${backup_timer}"
  systemd_remove_unit "${backup_service}"
  systemd_daemon_reload
}

c_secrets() {
  require_cmd openssl sed tr head

  local example="${REPO_CONFIG_DIR}/backup/backup.env.example"
  local out="${REPO_CONFIG_DIR}/backup/backup.env"

  [[ -f "$example" ]] || die "missing: ${example}"
  [[ -e "$out" ]] && return 0

  local RESTIC_PASSWORD
  RESTIC_PASSWORD="$(openssl rand -base64 96 | tr -dc 'a-zA-Z0-9' | head -c64)"

  sed \
    -e "s/RESTIC_PASSWORD=CHANGE_ME/RESTIC_PASSWORD=${RESTIC_PASSWORD}/" \
    "$example" > "$out"

  chmod 600 "$out"
}

c_secrets_deploy() {
  require_root

  local src="${REPO_CONFIG_DIR}/backup/backup.env"
  local dst="${INSTALL_CONFIG}/backup.env"
  [[ -f "$src" ]] || die "missing: ${src} (run: make backup-secrets)"

  deploy_file "$src" "$dst" "0600"
  chown root:root "$dst"
}

c_run() {
  require_root
  # Trigger the oneshot service explicitly.
  systemctl_cmd start "${backup_service}"
}

c_check() {
  require_cmd systemctl

  systemctl show -p LoadState --value "${backup_service}" >/dev/null 2>&1 || \
    die "systemd unit not found: ${backup_service}"
  systemctl show -p LoadState --value "${backup_timer}" >/dev/null 2>&1 || \
    die "systemd unit not found: ${backup_timer}"

  [[ -f "${INSTALL_CONFIG}/backup.conf" ]] || die "missing: ${INSTALL_CONFIG}/backup.conf"
  [[ -x "${INSTALL_SCRIPTS}/backup-n8n.sh" ]] || die "missing: ${INSTALL_SCRIPTS}/backup-n8n.sh"
}
