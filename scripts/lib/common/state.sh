#!/usr/bin/env bash
set -euo pipefail

# Installation state
is_installed() {
  local component="${1:-${COMPONENT}}"
  [[ -f "${STATE_DIR}/${component}.registry/.lock" ]]
}

installed_timestamp() {
  local component="${1:-${COMPONENT}}"
  local lock_file="${STATE_DIR}/${component}.registry/.lock"
  
  if [[ -f "$lock_file" ]]; then
    cat "$lock_file"
  else
    echo "unknown"
  fi
}

installed_count() {
  [[ -d "${STATE_DIR}" ]] || { echo 0; return; }
  find "${STATE_DIR}" -type f -name ".lock" 2>/dev/null | wc -l
}

# Requirements
require_sys_init() {
  [[ -d "${STATE_DIR}" ]] || \
    die "system not initialized (run: ./run init)"
}

require_installed() {
  local component="${1:-${COMPONENT}}"
  is_installed "$component" || \
    die "${component} not installed (run: ./run ${component} install)"
}
