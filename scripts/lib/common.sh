#!/usr/bin/env bash
set -euo pipefail

# Minimal, quiet-by-default helpers. Only errors/warnings print by default.

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

require_root() {
  if ! is_root; then
    echo "error: requires root" >&2
    exit 1
  fi
}

die() {
  echo "error: $*" >&2
  exit 1
}

warn() { echo "warn: $*" >&2; }
err()  { echo "error: $*" >&2; }

log() {
  if [[ "${N150_VERBOSE:-0}" == "1" ]]; then
    echo "$*" >&2
  fi
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: ${c}"
  done
}

run_cmd() { "$@"; }

# Filesystem helpers
ensure_dir() { mkdir -p -- "$1"; }

deploy_file() {
  # deploy_file <src> <dst> [mode]
  local src="$1" dst="$2" mode="${3:-0644}"
  ensure_dir "$(dirname -- "$dst")"
  install -m "$mode" -D -- "$src" "$dst"
}

deploy_exec() { deploy_file "$1" "$2" "0755"; }

deploy_dir() {
  # deploy_dir <src_dir> <dst_dir>
  local src="$1" dst="$2"
  require_cmd rsync
  ensure_dir "$dst"
  rsync -a --delete -- "${src%/}/" "${dst%/}/"
}

atomic_write() {
  # atomic_write <dst> <mode> <owner:group>  (reads stdin)
  local dst="$1" mode="$2" owner_group="$3"
  ensure_dir "$(dirname -- "$dst")"
  local tmp
  tmp="$(mktemp --tmpdir="$(dirname -- "$dst")" ".tmp.XXXXXX")"
  cat >"$tmp"
  chmod "$mode" "$tmp"
  chown "$owner_group" "$tmp"
  mv -f "$tmp" "$dst"
}

# Systemd helpers
systemctl_cmd() { require_cmd systemctl; run_cmd systemctl "$@"; }
systemd_daemon_reload() { systemctl_cmd daemon-reload; }

systemd_install_unit() {
  # systemd_install_unit <src_unit_file>
  require_root
  local src="$1"
  [[ -f "$src" ]] || die "unit file not found: $src"
  deploy_file "$src" "${SYSTEMD_UNIT_DIR}/$(basename -- "$src")" "0644"
}

systemd_remove_unit() {
  # systemd_remove_unit <unit_name>
  require_root
  rm -f -- "${SYSTEMD_UNIT_DIR}/${1}"
}

systemd_disable_stop() {
  # systemd_disable_stop <unit...>
  require_root
  systemctl_cmd disable --now "$@" >/dev/null 2>&1 || true
  systemctl_cmd stop "$@" >/dev/null 2>&1 || true
}

# Repo/FHS conventions (component-aware)
repo_component_config_dir() { echo "${REPO_CONFIG_DIR}/$1"; }
etc_component_dir() { echo "${ETC_COMPONENT_DIR}/$1"; }

repo_component_env_examples() {
  # repo_component_env_examples <component>
  local d
  d="$(repo_component_config_dir "$1")"
  [[ -d "$d" ]] || return 0
  (shopt -s nullglob; printf "%s\n" "$d"/*.env.example)
}

repo_component_env_generated_for_example() {
  # repo_component_env_generated_for_example <path/to/*.env.example>
  local ex="$1"
  echo "${ex%.env.example}.env"
}

generate_env_if_missing() {
  # generate_env_if_missing <example> <generated>
  local example="$1" out="$2"
  [[ -f "$example" ]] || die "env example not found: $example"
  if [[ -e "$out" ]]; then
    return 0
  fi
  deploy_file "$example" "$out" "0600"
}

deploy_secret_env() {
  # deploy_secret_env <src_generated_env> <dst_env>
  require_root
  [[ -f "$1" ]] || die "secret env not found: $1"
  cat "$1" | atomic_write "$2" "0600" "root:root"
}

# Root enforcement driven by component metadata
require_root_for_verb() {
  local verb="$1"
  local v
  for v in "${requires_root_verbs[@]:-}"; do
    [[ "$v" == "$verb" ]] && require_root && return 0
  done
  return 0
}
