#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${1:?ROOTFS is required}"
SUITE="${2:?SUITE is required}"
ARCH="${3:?ARCH is required}"
MIRROR="${4:?MIRROR is required}"

echo
echo "==> Bootstrapping Ubuntu"
echo "    Suite:  ${SUITE}"
echo "    Arch:   ${ARCH}"
echo "    Mirror: ${MIRROR}"
echo

mkdir -p "${ROOTFS}"

debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    "${SUITE}" \
    "${ROOTFS}" \
    "${MIRROR}"

echo
echo "==> Bootstrap completed"
