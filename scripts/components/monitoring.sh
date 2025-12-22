#!/usr/bin/env bash
set -euo pipefail

component_name="monitoring"
lifecycle_mode="systemd"

unit_names=( "monitoring-stack.service" )

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

  sed "s|WorkingDirectory=/opt/n8n|WorkingDirectory=${INSTALL_PREFIX_SHARE}|g" \
    "$unit_file" >"$dst"

  chmod 0644 "$dst"
}

c_install() {
  require_root
  require_cmd podman podman-compose rsync

  ensure_dir "${INSTALL_COMPOSE}"
  ensure_dir "${INSTALL_CONFIG}"
  ensure_dir "${INSTALL_CONFIG}/monitoring"
  ensure_dir "${INSTALL_CONFIG}/monitoring/grafana-provisioning/datasources"
  ensure_dir "${INSTALL_DATA}/monitoring/victoriametrics"
  ensure_dir "${INSTALL_DATA}/monitoring/grafana"

  # Compose (rewrite paths)
  sed "s|../config/|${INSTALL_CONFIG}/|g; s|../data/|${INSTALL_DATA}/|g" \
    "${REPO_COMPOSE_DIR}/monitoring.yml" > "${INSTALL_COMPOSE}/monitoring.yml"

  # Static config
  deploy_file "${REPO_CONFIG_DIR}/monitoring/monitoring.conf" "${INSTALL_CONFIG}/monitoring.conf" "0644"
  deploy_file "${REPO_CONFIG_DIR}/monitoring/alloy-config.alloy" "${INSTALL_CONFIG}/monitoring/alloy-config.alloy" "0644"
  deploy_file \
    "${REPO_CONFIG_DIR}/monitoring/grafana-provisioning/datasources/victoriametrics-datasource.yml" \
    "${INSTALL_CONFIG}/monitoring/grafana-provisioning/datasources/victoriametrics-datasource.yml" \
    "0644"

  # Systemd unit
  _install_unit_from_repo "monitoring-stack.service"
  systemd_daemon_reload
}

c_uninstall() {
  require_root

  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "monitoring-stack.service"
  systemd_daemon_reload
}

c_secrets() {
  require_cmd openssl sed tr head

  local example="${REPO_CONFIG_DIR}/monitoring/monitoring.env.example"
  local out="${REPO_CONFIG_DIR}/monitoring/monitoring.env"

  [[ -f "$example" ]] || die "missing: ${example}"
  [[ -e "$out" ]] && return 0

  local GF_SECURITY_ADMIN_PASSWORD
  GF_SECURITY_ADMIN_PASSWORD="$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c32)"

  sed \
    -e "s/GF_SECURITY_ADMIN_PASSWORD=CHANGE_ME/GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}/" \
    "$example" > "$out"

  chmod 600 "$out"
}

c_secrets_deploy() {
  require_root

  local src="${REPO_CONFIG_DIR}/monitoring/monitoring.env"
  local dst="${INSTALL_CONFIG}/monitoring.env"
  [[ -f "$src" ]] || die "missing: ${src} (run: make monitoring-secrets)"

  deploy_file "$src" "$dst" "0600"
  chown root:root "$dst"
}

c_check() {
  require_cmd systemctl

  systemctl show -p LoadState --value "monitoring-stack.service" >/dev/null 2>&1 || \
    die "systemd unit not found: monitoring-stack.service"

  [[ -f "${INSTALL_COMPOSE}/monitoring.yml" ]] || die "missing: ${INSTALL_COMPOSE}/monitoring.yml"
  [[ -f "${INSTALL_CONFIG}/monitoring.conf" ]] || die "missing: ${INSTALL_CONFIG}/monitoring.conf"
  [[ -f "${INSTALL_CONFIG}/monitoring/alloy-config.alloy" ]] || die "missing: ${INSTALL_CONFIG}/monitoring/alloy-config.alloy"
}
