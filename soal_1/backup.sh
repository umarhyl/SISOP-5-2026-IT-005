#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${ROOT_DIR}/osboot"
STAMP="$(date +%d%m%Y-%H%M%S)"
ZIP_PATH="${OUT_DIR}/farewell_backup_${STAMP}.zip"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: command '$1' is required." >&2
    exit 1
  }
}

need_cmd zip

mkdir -p "${OUT_DIR}"

files=(bzImage single.gz multi.gz farewell.iso)
existing=()
for f in "${files[@]}"; do
  if [[ -f "${OUT_DIR}/${f}" ]]; then
    existing+=("${OUT_DIR}/${f}")
  fi
done

if [[ ${#existing[@]} -eq 0 ]]; then
  echo "Error: no build artifacts found in ${OUT_DIR}." >&2
  exit 1
fi

zip -j "${ZIP_PATH}" "${existing[@]}" >/dev/null
rm -f "${existing[@]}"

echo "[✓] Backup archive created at ${ZIP_PATH}"
