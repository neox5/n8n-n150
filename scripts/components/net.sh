#!/usr/bin/env bash
set -euo pipefail

supported_verbs=(
  install
  uninstall
  start
  stop
)

readonly NET_COMPOSE_SRC="${ROOT_DIR}/compose/network.yml"
readonly NET_COMPOSE_DST="${SHARE_ROOT}/compose/network.yml"
readonly NET_UNIT_SRC="${ROOT_DIR}/systemd/n150-net.service"
readonly NET_UNIT_DST="${SYSTEMD_UNIT_DIR}/n150-net.service"

c_install() {
  local force=false
  [[ "${1:-}" == "--force" ]] && force=true
  
  require_sys_init
  
  if is_installed && [[ "$force" == "false" ]]; then
    echo "already installed (use --force to overwrite)"
    return 0
  fi
  
  ensure_dirs 0755 "${SHARE_ROOT}/compose"
  install_file "${NET_COMPOSE_SRC}" "${NET_COMPOSE_DST}"
  install_file "${NET_UNIT_SRC}" "${NET_UNIT_DST}"
  
  create_lock
}

c_uninstall() {
  if ! is_installed; then
    echo "not installed"
    return 0
  fi
  
  remove_files \
    "${NET_COMPOSE_DST}" \
    "${NET_UNIT_DST}"
  
  remove_lock
}

c_start() {
  systemd_start_unit "${NET_UNIT_DST}"
}

c_stop() {
  systemd_stop_unit "${NET_UNIT_DST}"
}
