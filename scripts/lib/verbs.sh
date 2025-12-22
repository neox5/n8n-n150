#!/usr/bin/env bash
set -euo pipefail

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
  echo "Usage:"
  echo "  run ${COMPONENT} <verb>"
  echo ""
  echo "Verbs:"
  echo "  help"
  local v
  for v in "${supported_verbs[@]}"; do
    echo "  ${v}"
  done
}

handle_sys_component() {
  case "$VERB" in
    init)
      ensure_dirs 0755 \
        "${STATE_DIR}" \
        "${ETC_ROOT}" \
        "${SHARE_ROOT}"
      ;;
    cleanup)
      if state_markers_exist; then
        echo "error: cannot cleanup - components still deployed:" >&2
        ls "${STATE_DIR}" | sed 's/\.lock$//' | sed 's/^/  - /' >&2
        exit 1
      fi
      rm -rf -- \
        "${VAR_ROOT}" \
        "${ETC_ROOT}" \
        "${SHARE_ROOT}"
      ;;
    *)
      die "${VERB} is not implemented by ${COMPONENT}"
      ;;
  esac
}

dispatch() {
  if [[ "$VERB" == "help" ]]; then
    if has_fn c_help; then
      c_help "$@"
      return 0
    fi
    default_help
    return 0
  fi

  verb_supported_by_component || \
    die "${VERB} is not supported by ${COMPONENT}"

  check_base_prereqs
  check_component_prereqs

  if [[ "${COMPONENT}" == "sys" ]]; then
    handle_sys_component "$@"
    return 0
  fi

  local hook="c_${VERB//-/_}"
  if has_fn "$hook"; then
    "$hook" "$@"
    return 0
  fi

  die "${VERB} is not implemented by ${COMPONENT}"
}
