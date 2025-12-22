#!/usr/bin/env bash
set -euo pipefail

component_name="app"
lifecycle_mode="systemd"

unit_names=( "n8n-stack.service" )

supported_verbs=(
  check
  install
  secrets
  secrets-deploy
  start
  status
  stop
  restart
  uninstall
)

required_cmds=(
  podman
  podman-compose
  rsync
)

requires_root_verbs=(
  install
  uninstall
  secrets-deploy
  start
  stop
  restart
)

_install_unit_from_repo() {
  local unit_file="${REPO_SYSTEMD_DIR}/$1"
  [[ -f "$unit_file" ]] || die "unit file not found: $unit_file"

  local dst="${SYSTEMD_UNIT_DIR}/$1"
  ensure_dir "$(dirname -- "$dst")"

  # Rewrite WorkingDirectory from /opt/n8n to INSTALL_PREFIX_SHARE.
  sed "s|WorkingDirectory=/opt/n8n|WorkingDirectory=${INSTALL_PREFIX_SHARE}|g" \
    "$unit_file" >"$dst"

  chmod 0644 "$dst"
}

c_install() {
  # Directory structure (component-scoped)
  ensure_dir "${INSTALL_COMPOSE}"
  ensure_dir "${INSTALL_CONFIG}"
  ensure_dir "${INSTALL_DATA}/n8n"
  ensure_dir "${INSTALL_DATA}/postgres/data"

  # Compose (rewrite repo-relative paths to production absolute paths)
  sed "s|../config/|${INSTALL_CONFIG}/|g; s|../data/|${INSTALL_DATA}/|g" \
    "${REPO_COMPOSE_DIR}/n8n.yml" > "${INSTALL_COMPOSE}/n8n.yml"

  # Static config
  deploy_file "${REPO_CONFIG_DIR}/n8n/n8n.conf" "${INSTALL_CONFIG}/n8n.conf" "0644"

  # Systemd unit
  _install_unit_from_repo "n8n-stack.service"
  systemd_daemon_reload
}

c_uninstall() {
  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "n8n-stack.service"
  systemd_daemon_reload
}

c_secrets_deploy() {
  local src="${REPO_CONFIG_DIR}/n8n/n8n.env"
  local dst="${INSTALL_CONFIG}/n8n.env"
  [[ -f "$src" ]] || die "missing: ${src} (run: ctl app secrets)"

  # Validate no CHANGE_ME tokens
  if secrets_has_change_me "$src"; then
    die "secret file contains CHANGE_ME tokens: ${src}
Edit the file and replace CHANGE_ME with actual secrets.
Then retry: make app-secrets-deploy"
  fi

  deploy_file "$src" "$dst" "0600"
  chown root:root "$dst"
}

c_check() {
  # Static validation
  systemctl_cmd show -p LoadState --value "n8n-stack.service" >/dev/null 2>&1 || \
    die "systemd unit not found: n8n-stack.service"

  [[ -f "${INSTALL_COMPOSE}/n8n.yml" ]] || die "missing: ${INSTALL_COMPOSE}/n8n.yml"
  [[ -f "${INSTALL_CONFIG}/n8n.conf" ]] || die "missing: ${INSTALL_CONFIG}/n8n.conf"
  
  # Runtime validation (only if service is active)
  if systemctl_cmd is-active n8n-stack.service >/dev/null 2>&1; then
    
    # Check postgres container health
    if ! podman exec n8n-postgres pg_isready -U n8n -q 2>/dev/null; then
      die "postgres container not responding"
    fi
    
    # Check n8n container health
    if ! podman exec n8n wget -q -O- http://localhost:5678 >/dev/null 2>&1; then
      warn "n8n container not responding on port 5678"
    fi
  fi
}
