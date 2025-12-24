#!/usr/bin/env bash
set -euo pipefail

# System initialization
system_init() {
  local created=false
  
  # Create base directories if missing
  if [[ ! -d "${VAR_ROOT}" ]]; then
    mkdir -p -m 0755 "${VAR_ROOT}"
    log_operation "+" "dir" "0755" "${VAR_ROOT}"
    created=true
  fi
  
  if [[ ! -d "${STATE_DIR}" ]]; then
    mkdir -p -m 0755 "${STATE_DIR}"
    log_operation "+" "dir" "0755" "${STATE_DIR}"
    created=true
  fi
  
  if [[ ! -d "${ETC_ROOT}" ]]; then
    mkdir -p -m 0755 "${ETC_ROOT}"
    log_operation "+" "dir" "0755" "${ETC_ROOT}"
    created=true
  fi
  
  if [[ ! -d "${SHARE_ROOT}" ]]; then
    mkdir -p -m 0755 "${SHARE_ROOT}"
    log_operation "+" "dir" "0755" "${SHARE_ROOT}"
    created=true
  fi
  
  # Output status if silent mode disabled
  if [[ "${SILENT:-false}" == "false" ]] && [[ "$created" == "false" ]]; then
    echo "system already initialized"
  fi
}

# System cleanup
system_cleanup() {
  # Check if initialized
  if [[ ! -d "${STATE_DIR}" ]]; then
    [[ "${SILENT:-false}" == "false" ]] && echo "system not initialized"
    return 0
  fi
  
  # Check for installed components
  local lock_count
  lock_count=$(find "${STATE_DIR}" -type f -name ".lock" 2>/dev/null | wc -l)
  
  if [[ "$lock_count" -ne 0 ]]; then
    echo "error: cannot cleanup - components still installed:" >&2
    find "${STATE_DIR}" -type d -name "*.registry" 2>/dev/null | \
      sed 's|.*/||; s|\.registry$||' | \
      sed 's/^/  - /' >&2
    return 1
  fi
  
  # Remove directories (deepest first)
  local dirs=(
    "${STATE_DIR}"
    "${VAR_ROOT}"
    "${ETC_ROOT}"
    "${SHARE_ROOT}"
  )
  
  for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      if rmdir "$dir" 2>/dev/null; then
        log_operation "-" "dir" "" "$dir"
      fi
    fi
  done
}

# System tree view
system_tree() {
  # Check if initialized
  if [[ ! -d "${STATE_DIR}" ]]; then
    echo "system not initialized (run: ./run init)"
    return 0
  fi
  
  # Silent mode: no output
  [[ "${SILENT:-false}" == "true" ]] && return 0
  
  local tree_args=("$@")
  if [[ "${#tree_args[@]}" -eq 0 ]]; then
    tree_args=(-C --noreport)
  else
    tree_args+=(--noreport)
  fi
  
  # Main directories
  for dir in "${SHARE_ROOT}" "${ETC_ROOT}" "${VAR_ROOT}"; do
    if [[ ! -d "$dir" ]]; then
      echo "$dir (not created)"
      echo ""
    else
      tree "${tree_args[@]}" "${dir}" 2>/dev/null || true
      echo ""
    fi
  done
  
  # Systemd units table
  print_systemd_table
}

print_systemd_table() {
  echo "Systemd units:"
  printf "%-15s %-35s %-10s %s\n" "COMPONENT" "UNIT" "STATUS" "STATE"
  
  local found_units=false
  
  # Iterate through all component registries (sorted)
  for registry_dir in "${STATE_DIR}"/*.registry; do
    [[ -d "$registry_dir" ]] || continue
    
    local component=$(basename "$registry_dir" .registry)
    
    # Read units for this component
    while IFS=' ' read -r unit_path mode; do
      [[ -n "$unit_path" ]] || continue
      
      found_units=true
      local unit_name=$(basename "$unit_path")
      local status="disabled"
      local state="inactive"
      
      # Check if enabled (actual system state)
      if systemd_is_enabled "$unit_path"; then
        status="enabled"
      fi
      
      # Check runtime state
      if systemctl is-active --quiet "$unit_name" 2>/dev/null; then
        state="active"
      fi
      
      printf "%-15s %-35s %-10s %s\n" "$component" "$unit_name" "$status" "$state"
    done < "${registry_dir}/units"
  done
  
  if [[ "$found_units" == "false" ]]; then
    echo "(no systemd unit files installed)"
  fi
  
  echo ""
}
