#!/usr/bin/env bash
set -euo pipefail

# Minimal, quiet-by-default helpers. Only errors print.

die() {
  echo "error: $*" >&2
  exit 1
}

warn() { echo "warn: $*" >&2; }

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: ${c}"
  done
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "this operation requires root privileges"
  fi
}

# ---------------------------------------------------------------------------
# Centralized prerequisite model
# ---------------------------------------------------------------------------

readonly -a N150_BASE_CMDS=(
  bash
  sed
  awk
  grep
)

check_base_prereqs() {
  require_cmd "${N150_BASE_CMDS[@]}"
}

# Component may define:
#   required_cmds=( ...)
check_component_prereqs() {
  if [[ "${#required_cmds[@]:-0}" -gt 0 ]]; then
    require_cmd "${required_cmds[@]}"
  fi
}

# ---------------------------------------------------------------------------
# Filesystem helpers
# ---------------------------------------------------------------------------

ensure_dir() { mkdir -p -- "$1"; }

deploy_file() {
  local src="$1" dst="$2" mode="${3:-0644}"
  ensure_dir "$(dirname -- "$dst")"
  install -m "$mode" -D -- "$src" "$dst"
}

atomic_write() {
  local dst="$1" mode="$2"
  ensure_dir "$(dirname -- "$dst")"
  local tmp
  tmp="$(mktemp --tmpdir="$(dirname -- "$dst")" ".tmp.XXXXXX")"
  cat >"$tmp"
  chmod "$mode" "$tmp"
  
  # Flush to disk before rename
  if command -v sync >/dev/null 2>&1; then
    sync "$tmp" 2>/dev/null || sync
  fi
  
  mv -f -- "$tmp" "$dst"
  
  # Sync directory entry
  if command -v sync >/dev/null 2>&1; then
    sync "$(dirname -- "$dst")" 2>/dev/null || sync
  fi
}

# ---------------------------------------------------------------------------
# Safe sed replacement helpers
# ---------------------------------------------------------------------------

sed_escape() {
  # Escape special characters for sed replacement string
  printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'
}

sed_replace_literal() {
  # sed_replace_literal <file> <search_pattern> <replacement_value> <output_file>
  local file="$1"
  local search="$2"
  local replace="$3"
  local output="$4"
  
  local escaped_replace
  escaped_replace=$(sed_escape "$replace")
  
  sed "s|${search}|${escaped_replace}|g" "$file" > "$output"
}

# ---------------------------------------------------------------------------
# Systemd helpers (systemctl presence is checked here, not in required_cmds)
# ---------------------------------------------------------------------------

systemctl_cmd() {
  require_cmd systemctl
  systemctl "$@"
}

systemd_daemon_reload() { systemctl_cmd daemon-reload; }

systemd_install_unit() {
  local src="$1"
  [[ -f "$src" ]] || die "unit file not found: $src"
  deploy_file "$src" "${SYSTEMD_UNIT_DIR}/$(basename -- "$src")" "0644"
}

systemd_remove_unit() {
  rm -f -- "${SYSTEMD_UNIT_DIR}/${1}"
}

systemd_disable_stop() {
  systemctl_cmd disable --now "$@" >/dev/null 2>&1 || true
  systemctl_cmd stop "$@" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Secrets generation
# ---------------------------------------------------------------------------

_repo_env_examples_default() {
  local component="$1"
  local d="${REPO_CONFIG_DIR}/${component}"
  [[ -d "$d" ]] || return 0
  (shopt -s nullglob; printf "%s\n" "${d}"/*.env.example)
}

_env_out_for_example() {
  local ex="$1"
  echo "${ex%.env.example}.env"
}

_gen_value_for_token() {
  local token="$1"
  case "$token" in
    GEN_ALNUM_32)
      require_cmd openssl tr head
      openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c32
      ;;
    GEN_ALNUM_64)
      require_cmd openssl tr head
      openssl rand -base64 96 | tr -dc 'a-zA-Z0-9' | head -c64
      ;;
    GEN_HEX_64)
      require_cmd openssl
      openssl rand -hex 32
      ;;
    *)
      die "unknown secrets token: ${token}"
      ;;
  esac
}

_resolve_refs_single_hop() {
  local value="$1"
  local map_name="$2"

  # Indirect reference to assoc array
  # shellcheck disable=SC2178,SC1083
  declare -n _m="$map_name"

  local out="$value"
  local name

  # Replace only first occurrence per iteration (prevents infinite loops)
  while [[ "$out" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
    name="${BASH_REMATCH[1]}"
    [[ -v "_m[$name]" ]] || die "undefined reference: ${name}"
    out="${out/\$\{$name\}/${_m[$name]}}"
  done

  # Single-hop rule: if anything that looks like a ref remains, fail.
  if [[ "$out" == *'${'* ]]; then
    die "unresolved reference(s) remain after one pass: ${out}"
  fi

  printf "%s" "$out"
}

_generate_env_from_example() {
  local example="$1" out="$2"

  [[ -f "$example" ]] || die "env example not found: ${example}"
  [[ -e "$out" ]] && return 0

  require_cmd mktemp chmod mv

  # Store file as structured lines to preserve comments/blank lines and ordering.
  local -a kind=() keys=() vals=() raw=()

  # Assoc map of key->value after pass1 (GEN_* resolved; others as-is)
  declare -A kv=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Preserve blank/comment lines verbatim
    if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      kind+=( "raw" ); raw+=( "$line" ); keys+=( "" ); vals+=( "" )
      continue
    fi

    # Minimal KEY=VALUE parsing (no export, no multiline)
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"

      case "$val" in
        CHANGE_ME)
          kv["$key"]="$val"
          ;;
        GEN_*)
          kv["$key"]="$(_gen_value_for_token "$val")"
          ;;
        *)
          kv["$key"]="$val"
          ;;
      esac

      kind+=( "kv" ); raw+=( "" ); keys+=( "$key" ); vals+=( "$val" )
      continue
    fi

    # Unknown format: keep verbatim (but note it won't participate in ref resolution)
    kind+=( "raw" ); raw+=( "$line" ); keys+=( "" ); vals+=( "" )
  done <"$example"

  # Pass 2: single-hop reference resolution, then write output.
  local tmp
  tmp="$(mktemp --tmpdir="$(dirname -- "$out")" ".envgen.XXXXXX")"

  local i k v final
  for i in "${!kind[@]}"; do
    if [[ "${kind[$i]}" == "raw" ]]; then
      printf "%s\n" "${raw[$i]}" >>"$tmp"
      continue
    fi

    k="${keys[$i]}"
    v="${kv[$k]}"

    # Resolve ${...} references (single-hop rule enforced inside)
    final="$(_resolve_refs_single_hop "$v" kv)"

    printf "%s=%s\n" "$k" "$final" >>"$tmp"
  done

  chmod 600 "$tmp"
  mv -f -- "$tmp" "$out"
}

common_secrets_generate() {
  # common_secrets_generate <component_name>
  local component="$1"

  local -a examples=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && examples+=( "$p" )
  done < <(_repo_env_examples_default "$component")

  [[ "${#examples[@]}" -gt 0 ]] || return 0

  local ex out
  for ex in "${examples[@]}"; do
    out="$(_env_out_for_example "$ex")"
    _generate_env_from_example "$ex" "$out"
  done
}

secrets_has_change_me() {
  local file="$1"
  grep -q "CHANGE_ME" "$file"
}
