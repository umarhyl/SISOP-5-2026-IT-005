#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${ROOT_DIR}/osboot"
QEMU_BIN="${QEMU_BIN:-qemu-system-x86_64}"
RAM_MB="${RAM_MB:-1024}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: command '$1' is required." >&2
    exit 1
  }
}

need_cmd "${QEMU_BIN}"

usage() {
  cat <<'EOF'
Usage: ./qemu.sh [--single|--multi|--all]
  --single  Boot kernel + single initramfs directly
  --multi   Boot kernel + multi initramfs directly
  --all     Boot from generated ISO (grub menu)
EOF
}

case "${1:-}" in
  --single)
    [[ -f "${OUT_DIR}/bzImage" && -f "${OUT_DIR}/single.gz" ]] || {
      echo "Error: build osboot/bzImage and osboot/single.gz first." >&2
      exit 1
    }
    exec "${QEMU_BIN}" -m "${RAM_MB}" -nic user,model=e1000 -kernel "${OUT_DIR}/bzImage" -initrd "${OUT_DIR}/single.gz" -append "console=ttyS0,115200" -nographic
    ;;
  --multi)
    [[ -f "${OUT_DIR}/bzImage" && -f "${OUT_DIR}/multi.gz" ]] || {
      echo "Error: build osboot/bzImage and osboot/multi.gz first." >&2
      exit 1
    }
    exec "${QEMU_BIN}" -m "${RAM_MB}" -nic user,model=e1000 -kernel "${OUT_DIR}/bzImage" -initrd "${OUT_DIR}/multi.gz" -append "console=ttyS0,115200" -nographic
    ;;
  --all)
    [[ -f "${OUT_DIR}/farewell.iso" ]] || {
      echo "Error: build osboot/farewell.iso first." >&2
      exit 1
    }
    exec "${QEMU_BIN}" -m "${RAM_MB}" -nic user,model=e1000 -cdrom "${OUT_DIR}/farewell.iso" -boot d
    ;;
  *)
    usage
    exit 1
    ;;
esac
