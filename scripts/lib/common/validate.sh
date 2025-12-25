#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: ${c}"
  done
}

readonly -a BASE_CMDS=(
  bash
  sed
  awk
  grep
  systemctl
  podman
  tree
)

check_base_prereqs() {
  require_cmd "${BASE_CMDS[@]}"
}

check_component_prereqs() {
  if declare -p required_cmds >/dev/null 2>&1; then
    require_cmd "${required_cmds[@]}"
  fi
}
