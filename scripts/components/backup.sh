#!/usr/bin/env bash
set -euo pipefail

component_name="backup"
lifecycle_mode="systemd"

backup_service="n8n-backup.service"
backup_timer="n8n-backup.timer"
unit_names=( "${backup_service}" "${backup_timer}" )

supported_verbs=(
  check
  install
  secrets
  secrets-deploy
  start
  status
  stop
  restart
  run
  uninstall
)

required_cmds=(
  rsync
  restic
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
  ensure_dir "${INSTALL_SCRIPTS}"
  ensure_dir "${INSTALL_CONFIG}"
  ensure_dir "${INSTALL_BACKUP}/staging/db"
  ensure_dir "${INSTALL_BACKUP}/staging/n8n-files"
  ensure_dir "${INSTALL_BACKUP}/staging/config"
  ensure_dir "${INSTALL_BACKUP}/restic-repo"

  # Deploy backup.conf with production paths
  sed_replace_literal \
    "${REPO_CONFIG_DIR}/backup/backup.conf" \
    "BACKUP_SOURCE=/backup-data/staging" \
    "BACKUP_SOURCE=${INSTALL_BACKUP}/staging" \
    "${INSTALL_CONFIG}/backup.conf.tmp1"
  
  sed_replace_literal \
    "${INSTALL_CONFIG}/backup.conf.tmp1" \
    "RESTIC_REPOSITORY=/backup-data/restic-repo" \
    "RESTIC_REPOSITORY=${INSTALL_BACKUP}/restic-repo" \
    "${INSTALL_CONFIG}/backup.conf"
  
  rm -f "${INSTALL_CONFIG}/backup.conf.tmp1"
  chmod 0644 "${INSTALL_CONFIG}/backup.conf"

  # Deploy backup script with production paths
  sed_replace_literal \
    "${REPO_SCRIPTS_DIR}/backup-n8n.sh" \
    "BASE_DIR=\"/opt/n8n\"" \
    "BASE_DIR=\"${INSTALL_PREFIX_VAR}\"" \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp1"
  
  sed_replace_literal \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp1" \
    "/config/n8n/n8n.env" \
    "${INSTALL_CONFIG}/n8n.env" \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp2"
  
  sed_replace_literal \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp2" \
    "/config/backup/backup.env" \
    "${INSTALL_CONFIG}/backup.env" \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp3"
  
  sed_replace_literal \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp3" \
    "/config/backup/backup.conf" \
    "${INSTALL_CONFIG}/backup.conf" \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp4"
  
  sed "s|cd \"\${BASE_DIR}/compose\"|cd ${INSTALL_COMPOSE}|g" \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp4" > "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp5"
  
  sed_replace_literal \
    "${INSTALL_SCRIPTS}/backup-n8n.sh.tmp5" \
    "\${BASE_DIR}/config/n8n/n8n.env" \
    "${INSTALL_CONFIG}/n8n.env" \
    "${INSTALL_SCRIPTS}/backup-n8n.sh"
  
  rm -f "${INSTALL_SCRIPTS}"/backup-n8n.sh.tmp*
  chmod 0755 "${INSTALL_SCRIPTS}/backup-n8n.sh"

  # Units
  _install_unit_from_repo "${backup_service}"
  _install_unit_from_repo "${backup_timer}"
  systemd_daemon_reload
}

c_uninstall() {
  systemd_disable_stop "${backup_timer}" "${backup_service}"
  systemd_remove_unit "${backup_timer}"
  systemd_remove_unit "${backup_service}"
  systemd_daemon_reload
}

c_secrets_deploy() {
  local src="${REPO_CONFIG_DIR}/backup/backup.env"
  local dst="${INSTALL_CONFIG}/backup.env"
  [[ -f "$src" ]] || die "missing: ${src} (run: ctl backup secrets)"

  # Validate no CHANGE_ME tokens
  if secrets_has_change_me "$src"; then
    die "secret file contains CHANGE_ME tokens: ${src}
Edit the file and replace CHANGE_ME with actual secrets.
Then retry: make backup-secrets-deploy"
  fi

  deploy_file "$src" "$dst" "0600"
  chown root:root "$dst"
}

c_run() {
  # Trigger the oneshot service explicitly.
  systemctl_cmd start "${backup_service}"
}

c_check() {
  systemctl_cmd show -p LoadState --value "${backup_service}" >/dev/null 2>&1 || \
    die "systemd unit not found: ${backup_service}"
  systemctl_cmd show -p LoadState --value "${backup_timer}" >/dev/null 2>&1 || \
    die "systemd unit not found: ${backup_timer}"

  [[ -f "${INSTALL_CONFIG}/backup.conf" ]] || die "missing: ${INSTALL_CONFIG}/backup.conf"
  [[ -x "${INSTALL_SCRIPTS}/backup-n8n.sh" ]] || die "missing: ${INSTALL_SCRIPTS}/backup-n8n.sh"
}
