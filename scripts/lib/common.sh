#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: ${c}"
  done
}

mode_to_symbolic() {
  local mode="$1"
  local perms=""
  
  # Convert octal mode to symbolic (e.g., 0755 -> rwxr-xr-x)
  # Extract last 3 digits (ignore leading 0)
  local user=$((8#${mode:1:1}))
  local group=$((8#${mode:2:1}))
  local other=$((8#${mode:3:1}))
  
  # User permissions
  [[ $((user & 4)) -ne 0 ]] && perms+="r" || perms+="-"
  [[ $((user & 2)) -ne 0 ]] && perms+="w" || perms+="-"
  [[ $((user & 1)) -ne 0 ]] && perms+="x" || perms+="-"
  
  # Group permissions
  [[ $((group & 4)) -ne 0 ]] && perms+="r" || perms+="-"
  [[ $((group & 2)) -ne 0 ]] && perms+="w" || perms+="-"
  [[ $((group & 1)) -ne 0 ]] && perms+="x" || perms+="-"
  
  # Other permissions
  [[ $((other & 4)) -ne 0 ]] && perms+="r" || perms+="-"
  [[ $((other & 2)) -ne 0 ]] && perms+="w" || perms+="-"
  [[ $((other & 1)) -ne 0 ]] && perms+="x" || perms+="-"
  
  echo "$perms"
}

log_operation() {
  local action="$1"
  local type="$2"
  local mode="$3"
  local path="$4"
  
  # Respect silent mode
  [[ "${SILENT:-false}" == "true" ]] && return 0
  
  # Format: [action] type (perms) path
  # or:     [action] type          path  (when mode is empty)
  
  if [[ -n "$mode" ]]; then
    local symbolic
    symbolic=$(mode_to_symbolic "$mode")
    printf "[%s] %-4s (%s) %s\n" "$action" "$type" "$symbolic" "$path"
  else
    printf "[%s] %-4s %10s %s\n" "$action" "$type" "" "$path"
  fi
}

ensure_dirs() {
  local mode="$1"; shift
  
  local d
  for d in "$@"; do
    mkdir -p -m "$mode" "$d"
    log_operation "+" "dir" "$mode" "$d"
  done
}

remove_dirs() {
  local d
  for d in "$@"; do
    rm -rf -- "$d"
    log_operation "-" "dir" "" "$d"
  done
}

install_file() {
  local src="$1"
  local dst="$2"
  local mode="${3:-0644}"
  
  cp "$src" "$dst"
  chmod "$mode" "$dst"
  
  log_operation "+" "file" "$mode" "$dst"
}

remove_files() {
  local f
  for f in "$@"; do
    rm -f -- "$f"
    log_operation "-" "file" "" "$f"
  done
}

create_lock() {
  date +%s > "${STATE_DIR}/${COMPONENT}.lock"
}

remove_lock() {
  rm -f "${STATE_DIR}/${COMPONENT}.lock"
}

is_installed() {
  local component="${1:-${COMPONENT}}"
  [[ -f "${STATE_DIR}/${component}.lock" ]]
}

require_sys_init() {
  [[ -f "${STATE_DIR}/sys.lock" ]] || die "system not initialized (run: ./run sys init)"
}

require_installed() {
  local component="${1:-${COMPONENT}}"
  is_installed "$component" || die "${component} not installed (run: ./run ${component} install)"
}

installed_count() {
  [[ -d "${STATE_DIR}" ]] || { echo 0; return; }
  find "${STATE_DIR}" -name "*.lock" 2>/dev/null | wc -l
}

discover_components() {
  local comp
  for comp in "${ROOT_DIR}/scripts/components/"*.sh; do
    [[ -f "$comp" ]] || continue
    basename "$comp" .sh
  done | sort
}

readonly -a BASE_CMDS=(
  bash
  sed
  awk
  grep
)

check_base_prereqs() {
  require_cmd "${BASE_CMDS[@]}"
}

check_component_prereqs() {
  if declare -p required_cmds >/dev/null 2>&1; then
    require_cmd "${required_cmds[@]}"
  fi
}

is_unit_active() {
  local unit_name="$1"
  systemctl is-active --quiet "$unit_name"
}

systemd_start_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if is_unit_active "$unit_name"; then
    echo "already running"
    return 0
  fi
  
  systemctl daemon-reload
  systemctl enable "$unit_name"
  systemctl start "$unit_name"
  
  [[ "${SILENT:-false}" == "true" ]] && return 0
  echo "[start] $unit_name"
}

systemd_stop_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if ! is_unit_active "$unit_name"; then
    echo "already stopped"
    return 0
  fi
  
  systemctl stop "$unit_name"
  systemctl disable "$unit_name"
  
  [[ "${SILENT:-false}" == "true" ]] && return 0
  echo "[stop] $unit_name"
}
