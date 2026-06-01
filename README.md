# SISOP-5-2026-IT-005

|               |           |
|---------------|-----------|
| Nama          | Umar      |
| NRP           | 5027251005|
| Kode Asisten  | KENZ      |

# Struktur Repositori:
```SISOP-5-2026-IT-005/
├── soal_1/
│   ├── .config
│   ├── backup.sh
│   ├── iso.sh
│   ├── kernel.sh
│   ├── multi.sh
│   ├── osboot/
│   ├── qemu.sh
│   └── single.sh
└── README.md
```

# Reporting

## Soal 1: Farewell Party
Pada soal ini diminta untuk membuat sistem operasi Linux minimal berbasis kernel Linux 6.1.1 yang dapat dijalankan menggunakan QEMU. Sistem operasi yang dibuat memiliki dua mode boot, yaitu single-user dan multi-user. Selain itu, sistem juga harus dapat melakukan boot melalui file ISO, memiliki package manager sederhana, mendukung koneksi internet, serta menyediakan script backup untuk seluruh hasil build.

### 1. `kernel.sh` - Compile Linux Kerenel
Pada tahap pertama, dilakukan proses download source code Linux kernel versi 6.1.1, konfigurasi kernel, lalu compile hingga menghasilkan file `bzImage` yang nantinya digunakan untuk booting sistem operasi. Kernel menjadi komponen utama karena seluruh proses booting, manajemen proses, filesystem, dan networking akan dijalankan oleh kernel Linux tersebut.

**Konfigurasi Kernel yang Digunakan**
Berikut beberapa konfigurasi penting yang digunakan:
- `64-Bit Kernel` - Digunakan agar kernel dapat berjalan pada arsitektur x86_64.
- `General Setup` > `Initial RAM filesystem and RAM disk (initramfs/initrd) support` - Fitur ini wajib diaktifkan karena filesystem yang dibuat (`single.gz` dan `multi.gz`) akan dimuat sebagai initramfs saat booting.
- `Device Drivers` > `Generic Driver Options` > `Maintain a devtmpfs filesystem to mount at /dev` - Digunakan agar kernel otomatis membuat device file seperti `/dev/null`, `/dev/console`, dan device lain yang dibutuhkan userspace.
- `Networking Support` > `Networking options` > `TCP/IP Networking` - Digunakan agar sistem operasi dapat menggunakan protokol TCP/IP dan terkoneksi internet.
- `Device Drivers` > `Network device support` > `Virtio Network Driver` - Digunakan agar kernel dapat mendeteksi virtual network interface milik QEMU.
- `File Systems` > `FUSE support` - Fitur ini diperlukan untuk menjalankan filesystem FUSE sesuai spesifikasi soal.
- `Executable file formats` > `Kernel support for ELF binaries` - Digunakan agar binary Linux ELF dapat dieksekusi oleh kernel.

```sh
KERNEL_VERSION="6.1.1"
KERNEL_TARBALL="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"
```
Bagian ini digunakan untuk menentukan versi kernel Linux yang akan diunduh.

```sh
curl -L "${KERNEL_URL}" -o "${WORK_DIR}/${KERNEL_TARBALL}"
```
Script menggunakan `curl` untuk mengunduh source code kernel Linux.

```sh
tar -xf "${WORK_DIR}/${KERNEL_TARBALL}" -C "${WORK_DIR}"
```
Source kernel kemudian diekstrak ke direktori build.

```sh
cp "${ROOT_DIR}/.config" "${KERNEL_SRC}/.config"
```
File `.config` hasil konfigurasi manual menggunakan `make menuconfig` digunakan kembali agar seluruh fitur yang diperlukan tetap konsisten saat build ulang.

```sh
make -C "${KERNEL_SRC}" olddefconfig
```
Digunakan untuk menyesuaikan `.config` dengan dependency konfigurasi kernel terbaru.

**Enable Feature Otomatis**

Selain menggunakan `.config`, script juga mengaktifkan beberapa fitur kernel secara otomatis menggunakan `scripts/config`.

```sh
"${KERNEL_SRC}/scripts/config" --file "${KERNEL_SRC}/.config" \
    --enable NET \
    --enable INET \
    --enable DEVTMPFS \
    --enable BINFMT_ELF \
    --enable FUSE_FS \
    --enable VIRTIO_NET
```
- `NET` → mengaktifkan networking kernel
- `INET` → mengaktifkan TCP/IP
- `DEVTMPFS` → otomatis generate `/dev`
- `BINFMT_ELF` → menjalankan binary Linux
- `FUSE_FS` → dukungan filesystem FUSE
- `VIRTIO_NET` → driver network QEMU

```sh
make -C "${KERNEL_SRC}" -j"${JOBS}" bzImage
```
Kernel dikompilasi menjadi `bzImage`.

```sh
cp "${KERNEL_SRC}/arch/x86/boot/bzImage" "${OUT_DIR}/bzImage"
```
Hasil compile kemudian dipindahkan ke folder `osboot/`.

### 2. single.sh - Single User Root Filesystem
Pada tahap ini dibuat root filesystem sederhana menggunakan Alpine MinirootFS dan BusyBox untuk mode single-user. Mode ini hanya memiliki satu user yaitu `root`, sehingga seluruh akses sistem langsung dimiliki oleh root tanpa proses login multi-user.

**Struktur Filesystem**
```
/
├── bin/
├── dev/
├── etc/
├── proc/
├── sys/
├── root/
└── tmp/
```

**Konfigurasi User Root**
```sh
cat > "${ROOTFS}/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
EOF
```
File `/etc/passwd` digunakan untuk mendefinisikan akun root.

```sh
ROOT_HASH="$(openssl passwd -6 -salt root_farewell root123)"
```
Password root dibuat menggunakan hash SHA512.

```sh
cat > "${ROOTFS}/etc/shadow" <<EOF
root:${ROOT_HASH}:19000:0:99999:7:::
EOF
```
Password hash disimpan ke `/etc/shadow`.

**Konfigurasi inittab**
```sh
cat > "${ROOTFS}/etc/inittab" <<'EOF'
::sysinit:/etc/init.d/rcS
tty1::respawn:/sbin/getty -n -l /bin/sh tty1 115200 vt100
EOF
```
- `::sysinit` → menjalankan script `rcS` saat init
- `tty1::respawn` → menjalankan getty untuk terminal tty1, langsung menjalankan shell tanpa login

**Script Startup (rcS)**
Script `rcS` adalah script pertama yang dijalankan saat initramfs berhasil diboot.
```sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
```
Filesystem virtual di-mount agar userspace dapat mengakses informasi kernel dan device.

**Setup Network**
```sh
ifconfig eth0 up
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
route add default gw 10.0.2.2
```
Ini digunakan untuk mengaktifkan interface network, memberikan IP, menambahkan default gateway. IP `10.10.2.2` merupakan gateway bawaan QEMU user networking.

**Setup DNS**
```sh
cat > /etc/resolv.conf <<'DNS'
nameserver 10.0.2.3
nameserver 8.8.8.8
DNS
```
Digunakan agar sistem dapat melakukan DNS resolution untuk `wget example.com`.

**Setup Package Manager**
```sh
cat > "${ROOTFS}/bin/party"
...
chmod +x "${ROOTFS}/bin/party"
```
Script `party` adalah package manager sederhana yang dibuat untuk menginstall paket tambahan.

**Generate initramfs**
```sh
find . | cpio -oHnewc | gzip > "${OUT_DIR}/single.gz"
```
Seluruh root filesystem kemudian dikemas menjadi initramfs `single.gz` yang akan digunakan untuk booting mode single-user.

### 3. `multi.sh` - Multi User Root Filesystem
Tahap ini merupakan pengembangan dari single-user filesystem menjadi multi-user filesystem. Sistem mendukung beberapa user berbeda dengan login, password, home directory, dan permission masing-masing sesuai spesifikasi soal.

**Struktur Home User**
```sh
mkdir -p "${ROOTFS}/home/henn"
mkdir -p "${ROOTFS}/home/hann"
mkdir -p "${ROOTFS}/home/viii"
mkdir -p "${ROOTFS}/home/kids"
```

**Konfigurasi User dan Group**
```sh
cat > "${ROOTFS}/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
henn:x:1000:1000:henn:/home/henn:/bin/sh
hann:x:1001:1001:hann:/home/hann:/bin/sh
viii:x:1002:1002:viii:/home/viii:/bin/sh
kids:x:1003:1003:kids:/home/kids:/bin/sh
EOF

cat > "${ROOTFS}/etc/group"
```

**Konfigurasi Password**
```sh
ROOT_HASH="$(hash_pw root123)"
HENN_HASH="$(hash_pw henn123)"
```
Password di-hash menggunakan SHA512.

```sh
cat > "${ROOTFS}/etc/shadow"
```
Password hash disimpan di `/etc/shadow`.

**Banner Login**
```sh
cat > "${ROOTFS}/etc/profile"
```
Ketika user berhasil login, shell akan menjalankan `/etc/profile`.

```sh
echo "Welcome, $(id -un)."
```
`id -un` digunakan untuk mengambil username aktif sehingga banner otomatis berubah sesuai user login.

**Konfigurasi Login**
```sh
tty1::respawn:/sbin/getty 115200 tty1
```
Berbeda dengan single-user mode, multi-user mode menggunakan `getty` normal sehingga user harus login terlebih dahulu menggunakan username dan password.

**Setup Permission Ping**
```sh
echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range
```
Digunakan agar seluruh user dapat menggunakan `ping` tanpa harus menjadi root.

**Networking**
```sh
ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
route add default gw 10.0.2.2
```
Konfigurasi network sama seperti single-user mode.

**Package Manager `party`**
```sh
apk add "$@"
```
`party` bertindak sebagai wrapper package manager Alpine APK.
Hal ini memenuhi spesifikasi soal yang meminta package manager dengan nama `party`.

**Generate Multi Initramfs**
```sh
find . | cpio -oHnewc | gzip > "${OUT_DIR}/multi.gz"
```
Root filesystem multi-user kemudian dikemas menjadi `multi.gz`.

### 4. `iso.sh` - Generate Bootable ISO
Setelah kernel dan initramfs selesai dibuat, tahap berikutnya adalah membuat bootable ISO menggunakan GRUB. ISO ini dapat melakukan boot baik ke mode single-user maupun multi-user.

**Potongan Kode**
```SH
mkdir -p "${ISO_ROOT}/boot/grub"
```
Membuat struktur folder ISO beserta direktori GRUB.

```sh
cp "${OUT_DIR}/bzImage" "${ISO_ROOT}/boot/bzImage"
cp "${OUT_DIR}/single.gz" "${ISO_ROOT}/boot/single.gz"
cp "${OUT_DIR}/multi.gz" "${ISO_ROOT}/boot/multi.gz"
```
Kernel dan initramfs disalin ke dalam filesystem ISO.

```sh
menuentry "FarewellOS (single mode)" {
    linux /boot/bzImage console=tty0
    initrd /boot/single.gz
}
```
GRUB menu pertama digunakan untuk boot mode single-user.

```sh
menuentry "FarewellOS (multi mode)" {
    linux /boot/bzImage console=tty0
    initrd /boot/multi.gz
}
```
GRUB menu kedua digunakan untuk boot mode multi-user.

```sh
grub-mkrescue -o "${ISO_PATH}" "${ISO_ROOT}"
```
Seluruh struktur ISO kemudian dikompilasi menjadi file bootable `farewell.iso`.

### 5. `qemu.sh` - Booting Sistem Operasi
Script ini digunakan untuk menjalankan sistem operasi menggunakan QEMU sesuai mode yang dipilih pengguna.

```sh
exec "${QEMU_BIN}" \
-m "${RAM_MB}" \
-nic user,model=e1000 \
-kernel "${OUT_DIR}/bzImage" \
-initrd "${OUT_DIR}/single/multi.gz" \ 
-append "console=ttyS0,115200" \
-nographic
```
| Parameter                 | Fungsi                                      |
| ------------------------- | ------------------------------------------- |
| `-m "${RAM_MB}"`          | Mengatur jumlah RAM virtual                 |
| `-nic user,model=e1000`   | Membuat virtual network interface           |
| `-kernel bzImage`         | Menjalankan kernel Linux langsung           |
| `-initrd single/multi.gz` | Memuat initramfs single-user/multi-user     |
| `-append "console=ttyS0"` | Mengarahkan output kernel ke serial console |
| `-nographic`              | Menjalankan QEMU tanpa GUI                  |

**Networking QEMU**

Dengan menggunakan opsi `-nic user,model=e1000`, QEMU akan membuat jaringan virtual yang memungkinkan guest OS untuk terkoneksi ke internet melalui NAT. IP default untuk gateway adalah `10.0.2.2`, dan DNS server default adalah `10.0.2.3`. Oleh karena itu sistem dapat melakukan ping ke `8.8.8.8` dan melakukan DNS resolution untuk `example.com`.

**Boot ISO**
`-all` mode ini digunakan untuk melakukan boot melalui file ISO yang sebelumnya dibuat oleh `iso.sh`.

```sh
exec "${QEMU_BIN}" \
-m "${RAM_MB}" \
-nic user,model=e1000 \
-cdrom "${OUT_DIR}/farewell.iso" \
-boot d
```
| Parameter             | Fungsi                                |
| --------------------- | ------------------------------------- |
| `-cdrom farewell.iso` | Mount file ISO sebagai CD-ROM virtual |
| `-boot d`             | Boot dari CD-ROM                      |

**Alur Booting Sistem**
```
QEMU
  ↓
Load bzImage
  ↓
Load initramfs (single.gz / multi.gz)
  ↓
Kernel boot
  ↓
init (/etc/inittab)
  ↓
rcS startup script
  ↓
mount filesystem
  ↓
network setup
  ↓
shell / login prompt
```

### 6. `backup.sh` - Backup Hasil Build
Script ini digunakan untuk membuat backup dari seluruh hasil build kernel, initramfs, dan ISO ke dalam folder `backup/` dengan nama file yang mencakup timestamp.
```sh
STAMP="$(date +%d%m%Y-%H%M%S)"
ZIP_PATH="${OUT_DIR}/farewell_backup_${STAMP}.zip"
files=(bzImage single.gz multi.gz farewell.iso)
zip -j "${ZIP_PATH}" "${existing[@]}"
rm -f "${existing[@]}"
```
- `date +%d%m%Y-%H%M%S` digunakan untuk membuat timestamp unik untuk setiap backup.
- `zip -j` digunakan untuk membuat file zip tanpa menyertakan struktur direktori.
- Setelah backup dibuat, file asli dihapus untuk menjaga kebersihan folder `osboot/`.

### 7. Proof of Concept**
- **Single User Mode**
![Single User Mode](/assets/soal_1/image.png)

- **Multi User Mode (Root)**
![Root User](/assets/soal_1/root.png)

- **Multi User Mode (Henn)**
![Henn User](/assets/soal_1/henn.png)

- **All Modes**
![FUSE](/assets/soal_1/all.png)

- **Fuse Test**
![FUSE](/assets/soal_1/fuse.png)
