#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${ROOT_DIR}/osboot"
WORK_DIR="${ROOT_DIR}/.linux-build"
KERNEL_VERSION="6.1.1"
KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"
KERNEL_SRC="${WORK_DIR}/linux-${KERNEL_VERSION}"
JOBS="${JOBS:-$(nproc)}"
CC_BIN="${CC_BIN:-gcc-12}"

mkdir -p "${OUT_DIR}" "${WORK_DIR}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: command '$1' is required." >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd make
need_cmd "${CC_BIN}"

if [[ ! -f "${WORK_DIR}/${KERNEL_TARBALL}" ]]; then
  echo "[+] Downloading Linux ${KERNEL_VERSION}..."
  curl -L "${KERNEL_URL}" -o "${WORK_DIR}/${KERNEL_TARBALL}"
fi

if [[ ! -d "${KERNEL_SRC}" ]]; then
  echo "[+] Extracting Linux source..."
  tar -xf "${WORK_DIR}/${KERNEL_TARBALL}" -C "${WORK_DIR}"
fi

echo "[+] Preparing kernel config..."
if [[ -f "${ROOT_DIR}/.config" ]]; then
  cp "${ROOT_DIR}/.config" "${KERNEL_SRC}/.config"
  make -C "${KERNEL_SRC}" olddefconfig CC="${CC_BIN}"
else
  make -C "${KERNEL_SRC}" tinyconfig CC="${CC_BIN}"
fi

if [[ -x "${KERNEL_SRC}/scripts/config" ]]; then
  # Keep tiny config but explicitly enable features needed by the assignment.
  "${KERNEL_SRC}/scripts/config" --file "${KERNEL_SRC}/.config" \
    --enable 64BIT \
    --enable PRINTK \
    --enable MULTIUSER \
    --enable POSIX_TIMERS \
    --enable HIGH_RES_TIMERS \
    --enable SYSCTL \
    --enable PROC_SYSCTL \
    --enable FUTEX \
    --enable CGROUPS \
    --enable TTY \
    --enable VT \
    --enable EXPERT \
    --enable EMBEDDED \
    --enable BINFMT_ELF \
    --enable BINFMT_SCRIPT \
    --enable PCI \
    --enable PCIEPORTBUS \
    --enable SERIAL_8250 \
    --enable SERIAL_8250_CONSOLE \
    --enable SERIAL_CORE \
    --enable SERIAL_CORE_CONSOLE \
    --enable UNIX98_PTYS \
    --enable LEGACY_PTYS \
    --enable NET \
    --enable INET \
    --enable IP_PING \
    --enable UNIX \
    --enable PACKET \
    --enable DEVTMPFS \
    --enable DEVTMPFS_MOUNT \
    --enable TMPFS \
    --enable BLK_DEV_INITRD \
    --enable PROC_FS \
    --enable SYSFS \
    --enable FILE_LOCKING \
    --enable FUSE_FS \
    --enable EXT2_FS \
    --enable EXT3_FS \
    --enable EXT4_FS \
    --enable NETDEVICES \
    --enable ETHERNET \
    --enable E1000 \
    --enable E1000E \
    --enable 8139TOO \
    --enable VIRTIO_MENU \
    --enable VIRTIO_PCI \
    --enable VIRTIO_CONSOLE \
    --enable VIRTIO_BLK \
    --enable VIRTIO_NET
  make -C "${KERNEL_SRC}" olddefconfig CC="${CC_BIN}"
fi

echo "[+] Building bzImage with ${CC_BIN} (jobs=${JOBS})..."
make -C "${KERNEL_SRC}" -j"${JOBS}" CC="${CC_BIN}" bzImage

cp "${KERNEL_SRC}/arch/x86/boot/bzImage" "${OUT_DIR}/bzImage"
echo "[✓] Kernel ready at ${OUT_DIR}/bzImage"
