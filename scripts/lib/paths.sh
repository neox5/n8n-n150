#!/usr/bin/env bash
set -euo pipefail

# Load project identity
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"

# Repo root
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

# Production deployment paths (environment overridable)
: "${SHARE_ROOT:=/usr/local/share/${PROJECT_NAME}}"
: "${ETC_ROOT:=/etc/${PROJECT_NAME}}"
: "${VAR_ROOT:=/var/lib/${PROJECT_NAME}}"

# State directory (always exists after sys init)
STATE_DIR="${VAR_ROOT}/state"

# Systemd unit file directory
SYSTEMD_UNIT_DIR="/etc/systemd/system"
