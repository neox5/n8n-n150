#!/usr/bin/env bash
set -euo pipefail

ok()   { printf "[OK]   %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
info() { printf "[INFO] %s\n" "$1"; }
fail() { printf "[FAIL] %s\n" "$1"; }

section() { printf "\n== %s ==\n" "$1"; }

section "OS"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  info "${PRETTY_NAME:-unknown}"
  [[ "${ID:-}" == "fedora" ]] && ok "ID=fedora" || warn "ID=${ID:-unknown} (expected fedora)"
  [[ "${VERSION_ID:-}" == "43" ]] && ok "VERSION_ID=43" || warn "VERSION_ID=${VERSION_ID:-unknown} (expected 43)"
else
  fail "/etc/os-release not readable"
fi

section "Installation paths (should be absent on a fresh host)"
for p in /usr/local/share/n8n-n150 /etc/n8n-n150 /var/lib/n8n-n150; do
  if [[ -e "$p" ]]; then
    warn "present: $p"
  else
    ok "absent:  $p"
  fi
done

section "systemd units (should be absent before install)"
if systemctl list-unit-files 2>/dev/null | grep -q 'n8n-n150'; then
  warn "found n8n-n150 unit files"
else
  ok "no n8n-n150 unit files"
fi

section "Podman baseline"
if command -v podman >/dev/null 2>&1; then
  info "$(podman --version)"
  # Keep output tight: only counts
  running="$(podman ps --format '{{.ID}}' | wc -l | tr -d ' ')"
  allc="$(podman ps -a --format '{{.ID}}' | wc -l | tr -d ' ')"
  info "containers: running=${running} total=${allc}"
  info "networks:"
  podman network ls --format '  {{.Name}} ({{.Driver}})' || true
else
  fail "podman missing"
fi

section "Ingress ports (80/443)"
if ss -lntp 2>/dev/null | grep -Eq ':(80|443)\s'; then
  warn "ports 80/443 in use"
  ss -lntp 2>/dev/null | grep -E ':(80|443)\s' || true
else
  ok "ports 80/443 free"
fi
