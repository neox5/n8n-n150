#!/usr/bin/env bash
set -euo pipefail

component_name="net"
lifecycle_mode="systemd"

unit_names=( "n150-net.service" )

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
  systemd_install_unit "$unit_file"
}

c_install() {
  require_root
  require_cmd podman

  _install_unit_from_repo "n150-net.service"
  systemd_daemon_reload
}

c_uninstall() {
  require_root

  systemd_disable_stop "${unit_names[@]}"
  systemd_remove_unit "n150-net.service"
  systemd_daemon_reload
}

c_check() {
  require_cmd podman
  # The unit creates the network; check only validates podman presence and that the unit exists on disk.
  systemctl show -p LoadState --value "n150-net.service" >/dev/null 2>&1 || \
    die "systemd unit not found: n150-net.service"
}
