#!/usr/bin/env bash
set -euo pipefail

discover_components() {
  local comp
  for comp in "${ROOT_DIR}/scripts/components/"*.sh; do
    [[ -f "$comp" ]] || continue
    basename "$comp" .sh
  done | sort
}

verb_supported_by_component() {
  local sv
  for sv in "${supported_verbs[@]:-}"; do
    [[ "$sv" == "$VERB" ]] && return 0
  done
  return 1
}

has_fn() {
  declare -F "$1" >/dev/null 2>&1
}

default_help() {
  echo "${COMPONENT} commands:"
  local v
  for v in "${supported_verbs[@]}"; do
    printf "  %-12s\n" "${v}"
  done
}

default_verify() {
  require_installed
  
  # Validate registry structure
  registry_validate || {
    echo "error: registry validation failed" >&2
    return 1
  }
  
  # Verify disk state matches registry
  registry_verify || {
    echo "error: registry verification failed" >&2
    return 1
  }
  
  echo "base verification passed"
}

default_uninstall() {
  if ! is_installed; then
    echo "not installed"
    return 0
  fi
  
  # Reconcile registry with actual state first
  registry_reconcile >/dev/null 2>&1 || true
  
  # Validate no enabled units (check actual system state)
  verify_no_enabled_units || return 1
  
  # Validate no active units (check actual system state)
  verify_no_active_units || return 1
  
  # Uninstall from registry
  uninstall_from_registry
  
  # Remove registry
  rm -rf "${STATE_DIR}/${COMPONENT}.registry"
}

dispatch() {
  # Help bypasses everything
  if [[ "$VERB" == "help" ]]; then
    if has_fn c_help; then
      c_help "$@"
      return 0
    fi
    default_help
    return 0
  fi

  # Validation
  verb_supported_by_component || \
    die "${VERB} is not supported by ${COMPONENT}"

  check_base_prereqs
  check_component_prereqs

  # Resolve hook (defaults for uninstall and verify)
  local hook="c_${VERB//-/_}"
  if [[ "$VERB" == "uninstall" ]] && ! has_fn "$hook"; then
    hook="default_uninstall"
  fi
  
  if [[ "$VERB" == "verify" ]] && ! has_fn "$hook"; then
    hook="default_verify"
  fi

  if has_fn "$hook"; then
    # PRE-HOOK: Install only
    if [[ "$VERB" == "install" ]]; then
      if is_installed && [[ "${1:-}" != "--force" ]]; then
        echo "already installed (use --force to overwrite)"
        return 0
      fi
      ensure_registry
    fi
    
    # COMPONENT OPERATION
    "$hook" "$@"
    return $?
  fi

  die "${VERB} is not implemented by ${COMPONENT}"
}
