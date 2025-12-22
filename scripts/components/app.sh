#!/usr/bin/env bash
set -euo pipefail

component_name="app"
lifecycle_mode="systemd"

unit_names=( "n8n-stack.service" )

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
  require_root
  require_cmd podman podman-compose rsync

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
  require_root

  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "n8n-stack.service"
  systemd_daemon_reload
}

c_secrets() {
  require_cmd openssl sed tr head

  local example="${REPO_CONFIG_DIR}/n8n/n8n.env.example"
  local out="${REPO_CONFIG_DIR}/n8n/n8n.env"

  [[ -f "$example" ]] || die "missing: ${example}"
  [[ -e "$out" ]] && return 0

  local POSTGRES_PASSWORD
  local N8N_ENCRYPTION_KEY
  POSTGRES_PASSWORD="$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c32)"
  N8N_ENCRYPTION_KEY="$(openssl rand -hex 32)"

  sed \
    -e "s/POSTGRES_PASSWORD=CHANGE_ME/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" \
    -e "s/DB_POSTGRESDB_PASSWORD=CHANGE_ME/DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}/" \
    -e "s/N8N_ENCRYPTION_KEY=CHANGE_ME/N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}/" \
    -e "s|postgresql://n8n:CHANGE_ME@|postgresql://n8n:${POSTGRES_PASSWORD}@|" \
    "$example" > "$out"

  chmod 600 "$out"
}

c_secrets_deploy() {
  require_root

  local src="${REPO_CONFIG_DIR}/n8n/n8n.env"
  local dst="${INSTALL_CONFIG}/n8n.env"
  [[ -f "$src" ]] || die "missing: ${src} (run: make app-secrets)"

  deploy_file "$src" "$dst" "0600"
  chown root:root "$dst"
}

c_check() {
  require_cmd systemctl

  systemctl show -p LoadState --value "n8n-stack.service" >/dev/null 2>&1 || \
    die "systemd unit not found: n8n-stack.service"

  [[ -f "${INSTALL_COMPOSE}/n8n.yml" ]] || die "missing: ${INSTALL_COMPOSE}/n8n.yml"
  [[ -f "${INSTALL_CONFIG}/n8n.conf" ]] || die "missing: ${INSTALL_CONFIG}/n8n.conf"
}
