#!/usr/bin/env bash
set -euo pipefail

component_name="monitoring"
lifecycle_mode="systemd"

unit_names=( "monitoring-stack.service" )

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

  sed "s|WorkingDirectory=/opt/n8n|WorkingDirectory=${INSTALL_PREFIX_SHARE}|g" \
    "$unit_file" >"$dst"

  chmod 0644 "$dst"
}

c_install() {
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
  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "monitoring-stack.service"
  systemd_daemon_reload
}

c_secrets_deploy() {
  local src="${REPO_CONFIG_DIR}/monitoring/monitoring.env"
  local dst="${INSTALL_CONFIG}/monitoring.env"
  [[ -f "$src" ]] || die "missing: ${src} (run: ctl monitoring secrets)"

  # Validate no CHANGE_ME tokens
  if secrets_has_change_me "$src"; then
    die "secret file contains CHANGE_ME tokens: ${src}
Edit the file and replace CHANGE_ME with actual secrets.
Then retry: make monitoring-secrets-deploy"
  fi

  deploy_file "$src" "$dst" "0600"
  chown root:root "$dst"
}

c_check() {
  systemctl_cmd show -p LoadState --value "monitoring-stack.service" >/dev/null 2>&1 || \
    die "systemd unit not found: monitoring-stack.service"

  [[ -f "${INSTALL_COMPOSE}/monitoring.yml" ]] || die "missing: ${INSTALL_COMPOSE}/monitoring.yml"
  [[ -f "${INSTALL_CONFIG}/monitoring.conf" ]] || die "missing: ${INSTALL_CONFIG}/monitoring.conf"
  [[ -f "${INSTALL_CONFIG}/monitoring/alloy-config.alloy" ]] || die "missing: ${INSTALL_CONFIG}/monitoring/alloy-config.alloy"
  
  # Runtime validation (only if service is active)
  if systemctl_cmd is-active monitoring-stack.service >/dev/null 2>&1; then
    
    # Check VictoriaMetrics container
    if ! podman exec victoriametrics wget -q -O- http://localhost:8428/health >/dev/null 2>&1; then
      warn "victoriametrics container not responding"
    fi
    
    # Check Grafana container
    if ! podman exec grafana wget -q -O- http://localhost:3000/api/health >/dev/null 2>&1; then
      warn "grafana container not responding"
    fi
  fi
}
