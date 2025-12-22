#!/usr/bin/env bash
set -euo pipefail

component_name="proxy"
lifecycle_mode="systemd"

unit_names=( "caddy.service" )

supported_verbs=(
  install
  uninstall
  start
  stop
  restart
  status
  check
)

requires_root_verbs=(
  install
  uninstall
  start
  stop
  restart
)

_install_unit_from_repo() {
  local unit_file="${REPO_SYSTEMD_DIR}/$1"
  [[ -f "$unit_file" ]] || die "unit file not found: $unit_file"

  local dst="${SYSTEMD_UNIT_DIR}/$1"
  ensure_dir "$(dirname -- "$dst")"

  # Rewrite Caddyfile path to INSTALL_CONFIG/Caddyfile.
  sed_replace_literal \
    "$unit_file" \
    "/opt/n8n/config/caddy/Caddyfile" \
    "${INSTALL_CONFIG}/Caddyfile" \
    "$dst"

  chmod 0644 "$dst"
}

c_install() {
  require_cmd caddy

  ensure_dir "${INSTALL_CONFIG}"

  # Static config
  deploy_file "${REPO_CONFIG_DIR}/caddy/Caddyfile" "${INSTALL_CONFIG}/Caddyfile" "0644"

  # Unit
  _install_unit_from_repo "caddy.service"
  systemd_daemon_reload
}

c_uninstall() {
  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "caddy.service"
  systemd_daemon_reload
}

c_check() {
  require_cmd systemctl

  systemctl show -p LoadState --value "caddy.service" >/dev/null 2>&1 || \
    die "systemd unit not found: caddy.service"

  [[ -f "${INSTALL_CONFIG}/Caddyfile" ]] || die "missing: ${INSTALL_CONFIG}/Caddyfile"
}
