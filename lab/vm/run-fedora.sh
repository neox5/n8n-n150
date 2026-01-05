#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"
BASE="$IMAGES_DIR/fedora43_base.qcow2"
WORK="$IMAGES_DIR/fedora43.qcow2"

mkdir -p "$IMAGES_DIR"

show_help() {
  cat <<EOF
Usage: $0 [COMMAND]

Commands:
  (none)           Run current state
  save <name>      Create internal snapshot
  load <name>      Revert to internal snapshot
  reset            Delete working image (next run creates fresh copy)
  list             List all internal snapshots
  help, -h         Show this help

State Files:
  fedora43_base.qcow2   Read-only backup (never modified)
  fedora43.qcow2        Working image (contains all snapshots)

Examples:
  $0                    # Run current state
  $0 save bootstrap     # Create 'bootstrap' snapshot
  $0 load bootstrap     # Revert to 'bootstrap' snapshot
  $0 load base          # Revert to fresh OS install
  $0 reset              # Delete working image, start fresh
  $0 list               # Show available snapshots

VM Access:
  SSH: ssh -p 2222 ansible@localhost
  Shutdown: sudo poweroff (from inside VM)
  Force kill: Ctrl+C (may corrupt state)
EOF
}

check_base() {
  if [ ! -f "$BASE" ]; then
    echo "[vm] error: base image not found: $BASE" >&2
    echo "[vm] create it first (see VM_SETUP.md)" >&2
    exit 1
  fi
}

init_work_image() {
  if [ ! -f "$WORK" ]; then
    echo "[vm] creating working image from base"
    cp "$BASE" "$WORK"

    # Check if 'base' snapshot exists
    if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*base"; then
      echo "[vm] creating 'base' snapshot"
      qemu-img snapshot -c base "$WORK" >/dev/null
    fi
  fi
}

case "${1:-}" in
help | -h | --help)
  show_help
  exit 0
  ;;

save)
  SNAPSHOT_NAME="${2:-}"
  if [ -z "$SNAPSHOT_NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 save <name>" >&2
    exit 1
  fi

  check_base
  init_work_image

  echo "[vm] creating snapshot: $SNAPSHOT_NAME"
  qemu-img snapshot -c "$SNAPSHOT_NAME" "$WORK"
  echo "[vm] snapshot created: $SNAPSHOT_NAME"
  exit 0
  ;;

load)
  SNAPSHOT_NAME="${2:-}"
  if [ -z "$SNAPSHOT_NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 load <name>" >&2
    exit 1
  fi

  check_base

  if [ ! -f "$WORK" ]; then
    echo "[vm] error: no working image found" >&2
    echo "[vm] run without arguments to create it" >&2
    exit 1
  fi

  if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*$SNAPSHOT_NAME"; then
    echo "[vm] error: snapshot not found: $SNAPSHOT_NAME" >&2
    echo "[vm] available snapshots:" >&2
    qemu-img snapshot -l "$WORK" | tail -n +3 | awk '{print "  - " $2}' >&2
    exit 1
  fi

  echo "[vm] reverting to snapshot: $SNAPSHOT_NAME"
  qemu-img snapshot -a "$SNAPSHOT_NAME" "$WORK"
  echo "[vm] snapshot loaded: $SNAPSHOT_NAME"
  exit 0
  ;;

reset)
  if [ -f "$WORK" ]; then
    echo "[vm] deleting working image"
    rm -f "$WORK"
    echo "[vm] working image deleted (next run will create fresh copy)"
  else
    echo "[vm] no working image to delete"
  fi
  exit 0
  ;;

list)
  check_base

  if [ ! -f "$WORK" ]; then
    echo "[vm] no working image (run without arguments to create it)"
    exit 0
  fi

  echo "[vm] available snapshots:"
  if qemu-img snapshot -l "$WORK" 2>/dev/null | tail -n +3 | grep -q .; then
    qemu-img snapshot -l "$WORK" | tail -n +3 | awk '{print "  - " $2 " (" $3 " " $4 ")"}'
  else
    echo "  (none)"
  fi
  exit 0
  ;;

"")
  check_base
  init_work_image
  ;;

*)
  echo "[vm] error: unknown command: $1" >&2
  echo "[vm] run '$0 help' for usage" >&2
  exit 1
  ;;
esac

exec qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -drive file="$WORK",if=virtio \
  -nic user,hostfwd=tcp::2222-:22
