#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${1:?ROOTFS is required}"
SUITE="${2:?SUITE is required}"

echo
echo "==> Configuring Ubuntu RootFS"
echo

# --------------------------------------------------------------------
# DNS
# --------------------------------------------------------------------

# resolv.conf may be a symlink in the target.
rm -f "${ROOTFS}/etc/resolv.conf"
cp --dereference /etc/resolv.conf "${ROOTFS}/etc/resolv.conf"

# --------------------------------------------------------------------
# APT repositories
# --------------------------------------------------------------------

cat >"${ROOTFS}/etc/apt/sources.list" <<EOF
deb http://ports.ubuntu.com/ubuntu-ports ${SUITE} main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${SUITE}-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports ${SUITE}-security main restricted universe multiverse
EOF

# --------------------------------------------------------------------
# Configuration executed inside chroot
# --------------------------------------------------------------------

cat >"${ROOTFS}/tmp/configure-lxc.sh" <<'CHROOT_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package lists"

apt-get update

echo "==> Upgrading base system"

apt-get -y full-upgrade

echo "==> Installing base packages"

apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    dbus \
    netbase \
    iproute2 \
    iputils-ping \
    openssh-server \
    sudo \
    ca-certificates \
    curl \
    vim-tiny \
    less \
    procps \
    tzdata

# --------------------------------------------------------------------
# Networking
# --------------------------------------------------------------------

mkdir -p /etc/systemd/network

cat >/etc/systemd/network/eth0.network <<'EOF'
[Match]
Name=eth0

[Network]
DHCP=yes
EOF

systemctl enable systemd-networkd.service

# systemd-resolved is intentionally not required here.
# Proxmox/LXC can manage /etc/resolv.conf.

# --------------------------------------------------------------------
# LXC-specific systemd handling
# --------------------------------------------------------------------

# configfs cannot normally be mounted by an unprivileged LXC container.
systemctl mask sys-kernel-config.mount

# --------------------------------------------------------------------
# SSH
# --------------------------------------------------------------------

# ssh host keys are deliberately removed during cleanup.
# They will be regenerated for each container.
systemctl enable ssh.service

echo "==> RootFS configuration completed"
CHROOT_SCRIPT

chmod +x "${ROOTFS}/tmp/configure-lxc.sh"

chroot "${ROOTFS}" /tmp/configure-lxc.sh

rm -f "${ROOTFS}/tmp/configure-lxc.sh"

echo
echo "==> Ubuntu configuration completed"
