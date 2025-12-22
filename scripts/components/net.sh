#!/usr/bin/env bash
set -euo pipefail

component_name="net"
lifecycle_mode="systemd"

unit_names=( "n150-net.service" )

supported_verbs=(
  check
  install
  start
  status
  stop
  restart
  uninstall
)

required_cmds=(
  podman
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
  systemd_install_unit "$unit_file"
}

c_install() {
  _install_unit_from_repo "n150-net.service"
  systemd_daemon_reload
}

c_uninstall() {
  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "n150-net.service"
  systemd_daemon_reload
}

c_check() {
  # Check systemd unit exists
  systemctl_cmd show -p LoadState --value "n150-net.service" >/dev/null 2>&1 || \
    die "systemd unit not found: n150-net.service"
  
  # Verify network actually exists
  if ! podman network exists "${N150_NETWORK_NAME}" 2>/dev/null; then
    die "podman network does not exist: ${N150_NETWORK_NAME}"
  fi
  
  # Check for state divergence
  local unit_active=false
  systemctl_cmd is-active n150-net.service >/dev/null 2>&1 && unit_active=true
  
  local net_exists=false
  podman network exists "${N150_NETWORK_NAME}" 2>/dev/null && net_exists=true
  
  if $unit_active && ! $net_exists; then
    die "systemd unit active but network missing (was it removed externally?)"
  fi
  
  if ! $unit_active && $net_exists; then
    warn "network exists but systemd unit inactive"
  fi
}
