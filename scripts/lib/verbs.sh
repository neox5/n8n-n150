#!/usr/bin/env bash
set -euo pipefail

# Dispatcher (structure-first; minimal enforcement).

readonly -a N150_MUTATING_VERBS=(
  install
  uninstall
  secrets-deploy
  start
  stop
  restart
  run
)

verb_supported_by_component() {
  local v="$1"
  local sv
  for sv in "${supported_verbs[@]:-}"; do
    [[ "$sv" == "$v" ]] && return 0
  done
  return 1
}

has_fn() {
  declare -F "$1" >/dev/null 2>&1
}

is_mutating_verb() {
  local v="$1"
  local m
  for m in "${N150_MUTATING_VERBS[@]}"; do
    [[ "$m" == "$v" ]] && return 0
  done
  return 1
}

default_systemd() {
  local verb="$1"
  [[ "${#unit_names[@]:-0}" -gt 0 ]] || return 1

  case "$verb" in
    start)   systemctl_cmd start "${unit_names[@]}" ;;
    stop)    systemctl_cmd stop "${unit_names[@]}" ;;
    restart) systemctl_cmd restart "${unit_names[@]}" ;;
    status)  systemctl_cmd status "${unit_names[@]}" ;;
    *) return 1 ;;
  esac
}

dispatch() {
  local verb="$1"; shift || true

  verb_supported_by_component "$verb" || \
    die "${verb} is not supported by ${component_name}"

  # Check root requirement
  if [[ -n "${requires_root_verbs[@]:-}" ]]; then
    local rv
    for rv in "${requires_root_verbs[@]}"; do
      if [[ "$rv" == "$verb" ]]; then
        require_root
        break
      fi
    done
  fi

  # prereqs
  check_base_prereqs
  check_component_prereqs

  # Mandatory validation before mutating verbs
  if is_mutating_verb "$verb"; then
    if has_fn c_check; then
      local check_output
      if ! check_output=$(c_check 2>&1); then
        echo "ERROR: ${component_name} validation failed" >&2
        echo "" >&2
        echo "$check_output" >&2
        echo "" >&2
        echo "Fix issues above and retry." >&2
        echo "Run: make ${component_name}-check" >&2
        exit 1
      fi
    fi
  fi

  # secrets: component may override, otherwise use common system
  if [[ "$verb" == "secrets" ]]; then
    if has_fn c_secrets; then
      c_secrets "$@"
      return 0
    fi
    common_secrets_generate "${component_name}"
    return 0
  fi

  local hook="c_${verb//-/_}"

  if has_fn "$hook"; then
    "$hook" "$@"
    return 0
  fi

  case "${lifecycle_mode:-custom}" in
    systemd)
      default_systemd "$verb" && return 0
      ;;
    custom) ;;
    *)
      die "invalid lifecycle_mode for ${component_name}: ${lifecycle_mode}"
      ;;
  esac

  die "${verb} is not implemented by ${component_name}"
}
