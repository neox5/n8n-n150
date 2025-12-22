#!/usr/bin/env bash
set -euo pipefail

# Repo root
_paths_this_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${_paths_this_dir}/../.." && pwd)"

# Production deployment paths (FHS)
: "${N150_SHARE_ROOT:=/usr/local/share/n8n-n150}"
: "${N150_ETC_ROOT:=/etc/n8n-n150}"
: "${N150_VAR_ROOT:=/var/lib/n8n-n150}"

# Backwards-compatible aliases (existing scripts may still use these names)
readonly INSTALL_PREFIX_SHARE="${N150_SHARE_ROOT}"
readonly INSTALL_PREFIX_ETC="${N150_ETC_ROOT}"
readonly INSTALL_PREFIX_VAR="${N150_VAR_ROOT}"

readonly INSTALL_COMPOSE="${INSTALL_PREFIX_SHARE}/compose"
readonly INSTALL_SCRIPTS="${INSTALL_PREFIX_SHARE}/scripts"
readonly INSTALL_CONFIG="${INSTALL_PREFIX_ETC}"
readonly INSTALL_DATA="${INSTALL_PREFIX_VAR}/data"
readonly INSTALL_BACKUP="${INSTALL_PREFIX_VAR}/backup-data"

# Repo paths
REPO_COMPOSE_DIR="${ROOT_DIR}/compose"
REPO_CONFIG_DIR="${ROOT_DIR}/config"
REPO_SCRIPTS_DIR="${ROOT_DIR}/scripts"
REPO_SYSTEMD_DIR="${ROOT_DIR}/systemd"

# Install target paths
SHARE_COMPOSE_DIR="${N150_SHARE_ROOT}/compose"
SHARE_SCRIPTS_DIR="${N150_SHARE_ROOT}/scripts"
ETC_COMPONENT_DIR="${N150_ETC_ROOT}"     # /etc/n8n-n150/<component>/...
VAR_DATA_DIR="${N150_VAR_ROOT}/data"
VAR_BACKUP_DIR="${N150_VAR_ROOT}/backup-data"

# Common names
N150_NETWORK_NAME="${N150_NETWORK_NAME:-n150-net}"
SYSTEMD_UNIT_DIR="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
