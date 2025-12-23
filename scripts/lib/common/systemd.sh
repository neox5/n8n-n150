#!/usr/bin/env bash
set -euo pipefail

is_unit_active() {
  local unit_name="$1"
  systemctl is-active --quiet "$unit_name"
}

require_unit_stopped() {
  local unit_path="$1"
  local unit_name
  unit_name=$(basename "${unit_path}")
  
  if is_unit_active "${unit_name}"; then
    die "component is running - stop it first (run: ./run ${COMPONENT} stop)"
  fi
}

systemd_enable_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable "$unit_name" >/dev/null 2>&1
  log_unit_operation "enable" "$unit_name"
}

systemd_disable_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  systemctl disable "$unit_name" >/dev/null 2>&1
  log_unit_operation "disable" "$unit_name"
}

systemd_start_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if is_unit_active "$unit_name"; then
    echo "already running"
    return 0
  fi
  
  systemctl start "$unit_name" >/dev/null 2>&1
  log_unit_operation "start" "$unit_name"
}

systemd_stop_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if ! is_unit_active "$unit_name"; then
    echo "already stopped"
    return 0
  fi
  
  systemctl stop "$unit_name" >/dev/null 2>&1
  log_unit_operation "stop" "$unit_name"
}
