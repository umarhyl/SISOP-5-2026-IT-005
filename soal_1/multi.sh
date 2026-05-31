#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${ROOT_DIR}/osboot"
ROOTFS="${ROOT_DIR}/.multi-rootfs"
CACHE_DIR="${ROOT_DIR}/.alpine-cache"
ALPINE_MIRROR="${ALPINE_MIRROR:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: command '$1' is required." >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd cpio
need_cmd gzip
need_cmd openssl

mkdir -p "${OUT_DIR}" "${CACHE_DIR}"

ALPINE_TARBALL="$(
  curl -fsSL "${ALPINE_MIRROR}/latest-releases.yaml" \
    | awk -F': ' '/file: alpine-minirootfs-.*-x86_64.tar.gz/{print $2; exit}'
)"
[[ -n "${ALPINE_TARBALL}" ]] || {
  echo "Error: failed to resolve Alpine minirootfs tarball." >&2
  exit 1
}
ALPINE_TAR_PATH="${CACHE_DIR}/${ALPINE_TARBALL}"

if [[ ! -f "${ALPINE_TAR_PATH}" ]]; then
  echo "[+] Downloading ${ALPINE_TARBALL}..."
  curl -fL "${ALPINE_MIRROR}/${ALPINE_TARBALL}" -o "${ALPINE_TAR_PATH}"
fi

rm -rf "${ROOTFS}"
mkdir -p "${ROOTFS}"
tar -xzf "${ALPINE_TAR_PATH}" -C "${ROOTFS}"

hash_pw() {
  openssl passwd -6 -salt "${1}_farewell" "$1"
}

ROOT_HASH="$(hash_pw root123)"
HENN_HASH="$(hash_pw henn123)"
HANN_HASH="$(hash_pw hann123)"
VIII_HASH="$(hash_pw viii123)"
KIDS_HASH="$(hash_pw kids123)"

cat > "${ROOTFS}/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
henn:x:1000:1000:henn:/home/henn:/bin/sh
hann:x:1001:1001:hann:/home/hann:/bin/sh
viii:x:1002:1002:viii:/home/viii:/bin/sh
kids:x:1003:1003:kids:/home/kids:/bin/sh
EOF

cat > "${ROOTFS}/etc/group" <<'EOF'
root:x:0:
henn:x:1000:
hann:x:1001:
viii:x:1002:
kids:x:1003:
g_henn:x:2000:henn
g_henn_hann:x:2001:henn,hann
g_henn_hann_viii:x:2002:henn,hann,viii
g_all:x:2003:henn,hann,viii,kids
EOF

cat > "${ROOTFS}/etc/shadow" <<EOF
root:${ROOT_HASH}:19000:0:99999:7:::
henn:${HENN_HASH}:19000:0:99999:7:::
hann:${HANN_HASH}:19000:0:99999:7:::
viii:${VIII_HASH}:19000:0:99999:7:::
kids:${KIDS_HASH}:19000:0:99999:7:::
EOF
chmod 600 "${ROOTFS}/etc/shadow"

mkdir -p "${ROOTFS}/home/henn" "${ROOTFS}/home/hann" "${ROOTFS}/home/viii" "${ROOTFS}/home/kids"
mkdir -p "${ROOTFS}/etc/init.d" "${ROOTFS}/dev/pts"

cat > "${ROOTFS}/etc/securetty" <<'EOF'
tty1
ttyS0
EOF

cat > "${ROOTFS}/etc/hostname" <<'EOF'
farewell-os
EOF

cat > "${ROOTFS}/etc/apk/repositories" <<'EOF'
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF

cat > "${ROOTFS}/etc/resolv.conf" <<'EOF'
nameserver 10.0.2.3
nameserver 8.8.8.8
EOF

cat > "${ROOTFS}/etc/profile" <<'EOF'
if [ -z "${FAREWELL_BANNER_SHOWN:-}" ]; then
  export FAREWELL_BANNER_SHOWN=1
  clear
  cat <<'BANNER'
########################################
#            FAREWELL  PARTY           #
########################################
BANNER
  echo "Welcome, $(id -un)."
fi
EOF

cat > "${ROOTFS}/etc/inittab" <<'EOF'
::sysinit:/etc/init.d/rcS
tty1::respawn:/sbin/getty 115200 tty1
ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt100
::ctrlaltdel:/bin/umount -a -r
::shutdown:/bin/umount -a -r
EOF

cat > "${ROOTFS}/etc/init.d/rcS" <<'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev || {
  mount -t tmpfs tmpfs /dev
  mknod -m 622 /dev/console c 5 1
  mknod -m 666 /dev/null c 1 3
}
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
[ -w /proc/sys/net/ipv4/ping_group_range ] && echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range
chmod 1777 /tmp
hostname -F /etc/hostname

ifconfig lo 127.0.0.1 up || true
ifconfig eth0 up 2>/dev/null || true
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up 2>/dev/null || true
route add default gw 10.0.2.2 dev eth0 2>/dev/null || route add default gw 10.0.2.2 2>/dev/null || true

cat > /etc/resolv.conf <<'DNS'
nameserver 10.0.2.3
nameserver 8.8.8.8
DNS

chown -R 0:0 /root
chown -R 1000:2000 /home/henn
chown -R 1001:2001 /home/hann
chown -R 1002:2002 /home/viii
chown -R 1003:2003 /home/kids
chmod 770 /home/henn /home/hann /home/viii /home/kids
EOF
chmod +x "${ROOTFS}/etc/init.d/rcS"

cat > "${ROOTFS}/init" <<'EOF'
#!/bin/sh
exec /sbin/init
EOF
chmod +x "${ROOTFS}/init"

cat > "${ROOTFS}/bin/party" <<'EOF'
#!/bin/sh

usage() {
  cat <<'USAGE'
party - package manager frontend
Usage:
  party update
  party install <pkg...>
  party remove <pkg...>
  party search <pattern>
  party list
USAGE
}

APK_BIN=""
for cand in apk /sbin/apk /usr/sbin/apk /bin/apk /usr/bin/apk; do
  if [ "${cand#*/}" = "${cand}" ]; then
    if command -v "${cand}" >/dev/null 2>&1; then
      APK_BIN="$(command -v "${cand}")"
      break
    fi
  elif [ -x "${cand}" ]; then
    APK_BIN="${cand}"
    break
  fi
done

if [ -n "${APK_BIN}" ]; then
  cmd="${1:-}"
  case "${cmd}" in
    update) shift; exec "${APK_BIN}" update "$@" ;;
    install) shift; exec "${APK_BIN}" add "$@" ;;
    remove) shift; exec "${APK_BIN}" del "$@" ;;
    search) shift; exec "${APK_BIN}" search "${1:-}" ;;
    list) shift; exec "${APK_BIN}" info ;;
    ""|-h|--help|help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
fi

echo "party: no backend package manager detected."
exit 1
EOF
chmod +x "${ROOTFS}/bin/party"

(
  cd "${ROOTFS}"
  find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "${OUT_DIR}/multi.gz"
)

rm -rf "${ROOTFS}"
echo "[✓] Initramfs multi mode ready at ${OUT_DIR}/multi.gz"
