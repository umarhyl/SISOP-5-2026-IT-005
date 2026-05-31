#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${ROOT_DIR}/osboot"
ISO_ROOT="${ROOT_DIR}/.iso-root"
ISO_PATH="${OUT_DIR}/farewell.iso"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: command '$1' is required." >&2
    exit 1
  }
}

need_cmd grub-mkrescue
need_cmd xorriso

for f in bzImage single.gz multi.gz; do
  [[ -f "${OUT_DIR}/${f}" ]] || {
    echo "Error: ${OUT_DIR}/${f} not found. Build dependencies first." >&2
    exit 1
  }
done

rm -rf "${ISO_ROOT}"
mkdir -p "${ISO_ROOT}/boot/grub" "${OUT_DIR}"

cp "${OUT_DIR}/bzImage" "${ISO_ROOT}/boot/bzImage"
cp "${OUT_DIR}/single.gz" "${ISO_ROOT}/boot/single.gz"
cp "${OUT_DIR}/multi.gz" "${ISO_ROOT}/boot/multi.gz"

cat > "${ISO_ROOT}/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "FarewellOS (single mode)" {
    linux /boot/bzImage console=tty0
    initrd /boot/single.gz
}

menuentry "FarewellOS (multi mode)" {
    linux /boot/bzImage console=tty0
    initrd /boot/multi.gz
}
EOF

grub-mkrescue -o "${ISO_PATH}" "${ISO_ROOT}" >/dev/null 2>&1

rm -rf "${ISO_ROOT}"
echo "[✓] ISO ready at ${ISO_PATH}"
