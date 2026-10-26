#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${1:?ROOTFS is required}"

echo
echo "==> Cleaning RootFS for template use"
echo

# --------------------------------------------------------------------
# Machine identity
# --------------------------------------------------------------------

echo "==> Resetting machine-id"

rm -f "${ROOTFS}/etc/machine-id"
touch "${ROOTFS}/etc/machine-id"

rm -f "${ROOTFS}/var/lib/dbus/machine-id"

# --------------------------------------------------------------------
# SSH host keys
# --------------------------------------------------------------------

echo "==> Removing SSH host keys"

rm -f "${ROOTFS}"/etc/ssh/ssh_host_*

# --------------------------------------------------------------------
# Hostname
# --------------------------------------------------------------------

echo "==> Resetting hostname"

: >"${ROOTFS}/etc/hostname"

# Remove hostname potentially written into /etc/hosts.
cat >"${ROOTFS}/etc/hosts" <<'EOF'
127.0.0.1 localhost
::1       localhost ip6-localhost ip6-loopback

ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

# --------------------------------------------------------------------
# APT cache
# --------------------------------------------------------------------

echo "==> Cleaning APT cache"

chroot "${ROOTFS}" apt-get clean

rm -rf "${ROOTFS}/var/lib/apt/lists/"*
rm -rf "${ROOTFS}/var/cache/apt/archives/"*

# --------------------------------------------------------------------
# Temporary files
# --------------------------------------------------------------------

echo "==> Removing temporary files"

rm -rf "${ROOTFS}/tmp/"*
rm -rf "${ROOTFS}/var/tmp/"*

# --------------------------------------------------------------------
# Logs
# --------------------------------------------------------------------

echo "==> Cleaning logs"

find "${ROOTFS}/var/log" \
    -type f \
    -exec truncate -s 0 {} \;

rm -rf "${ROOTFS}/var/log/journal/"*

# --------------------------------------------------------------------
# DHCP leases
# --------------------------------------------------------------------

echo "==> Removing DHCP leases"

rm -rf "${ROOTFS}/var/lib/systemd/network/"*

# --------------------------------------------------------------------
# Shell history
# --------------------------------------------------------------------

rm -f "${ROOTFS}/root/.bash_history"

# --------------------------------------------------------------------
# resolv.conf
# --------------------------------------------------------------------

# The resolver copied from the builder was only required while building.
# Proxmox/LXC will provide the container's resolver configuration.
rm -f "${ROOTFS}/etc/resolv.conf"

echo
echo "==> Cleanup completed"
