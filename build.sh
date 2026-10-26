#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
WORK_DIR="${SCRIPT_DIR}/work"
DIST_DIR="${SCRIPT_DIR}/dist"

# ---- Template configuration -----------------------------------------

SUITE="${SUITE:-noble}"
ARCH="${ARCH:-arm64}"

case "${SUITE}" in
    noble)
        VERSION="24.04"
        ;;
    *)
        echo "ERROR: Unsupported Ubuntu suite: ${SUITE}" >&2
        exit 1
        ;;
esac

MIRROR="${MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"

ROOTFS="${WORK_DIR}/ubuntu-${VERSION}-${ARCH}"

OUTPUT_NAME="ubuntu-${VERSION}-minimal_${ARCH}.tar.zst"
OUTPUT="${DIST_DIR}/${OUTPUT_NAME}"

# ---- Functions ------------------------------------------------------

cleanup_on_error() {
    local exit_code=$?

    if (( exit_code != 0 )); then
        echo
        echo "ERROR: Build failed (exit code: ${exit_code})." >&2
        echo "RootFS has been preserved at:" >&2
        echo "  ${ROOTFS}" >&2
    fi

    exit "${exit_code}"
}

trap cleanup_on_error EXIT

# ---- Preconditions --------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root." >&2
    echo "Run: sudo ./build.sh" >&2
    exit 1
fi

for command in debootstrap chroot tar zstd; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: ${command}" >&2
        exit 1
    fi
done

# ---- Prepare --------------------------------------------------------

echo "============================================================"
echo " Proxmox LXC Template Builder"
echo "============================================================"
echo "Suite:       ${SUITE}"
echo "Version:     ${VERSION}"
echo "Architecture:${ARCH}"
echo "Mirror:      ${MIRROR}"
echo "RootFS:      ${ROOTFS}"
echo "Output:      ${OUTPUT}"
echo "============================================================"
echo

mkdir -p "${WORK_DIR}" "${DIST_DIR}"

if [[ -e "${ROOTFS}" ]]; then
    echo "Removing previous RootFS..."
    rm -rf "${ROOTFS}"
fi

rm -f "${OUTPUT}"

# ---- Build ----------------------------------------------------------

"${SCRIPTS_DIR}/bootstrap.sh" \
    "${ROOTFS}" \
    "${SUITE}" \
    "${ARCH}" \
    "${MIRROR}"

"${SCRIPTS_DIR}/configure.sh" \
    "${ROOTFS}" \
    "${SUITE}"

"${SCRIPTS_DIR}/cleanup.sh" \
    "${ROOTFS}"

# ---- Package --------------------------------------------------------

echo
echo "Creating LXC template..."

tar \
    --numeric-owner \
    --xattrs \
    --acls \
    --exclude-from "${SCRIPTS_DIR}/excludes.txt" \
    -C "${ROOTFS}" \
    -I 'zstd -19 -T0' \
    -cpf "${OUTPUT}" \
    .

echo
echo "Verifying archive..."

zstd -t "${OUTPUT}"

echo
echo "Template contents:"
tar -tf "${OUTPUT}" | head -n 20 || true

echo
echo "============================================================"
echo " Build completed successfully"
echo "============================================================"
echo
echo "Template:"
echo "  ${OUTPUT}"
echo
echo "Size:"
du -h "${OUTPUT}"
echo
echo "Install on Proxmox:"
echo "  scp '${OUTPUT}' root@pimox:/var/lib/vz/template/cache/"
echo
