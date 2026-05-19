#!/bin/sh
set -e

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

echo ""
echo "1: Kernel Module Blacklist and Initramfs"
echo "---------------------------------------------"

cat > /etc/modprobe.d/blacklist-unnecessary.conf << 'EOF'
# Graphics (headless server)
blacklist drm
blacklist drm_kms_helper
blacklist simpledrm
blacklist virtio_gpu
blacklist fb
# KVM (not nesting VMs)
blacklist kvm
blacklist kvm_amd
blacklist kvm_intel
# Legacy devices
blacklist floppy
blacklist cdrom
blacklist sr_mod
blacklist isofs
# HID/input (headless)
blacklist hid
blacklist usbhid
blacklist hid_generic
blacklist psmouse
blacklist mousedev
# Wrong cloud drivers (not GCP/AWS)
blacklist gve
blacklist ena
# Force block DRM
install drm /bin/true
install drm_kms_helper /bin/true
install simpledrm /bin/true
install fb /bin/true
# USB (not needed on VPS)
blacklist usbcore
blacklist xhci_hcd
blacklist xhci_pci
blacklist usb_common
# I2C (not needed)
blacklist i2c_core
blacklist i2c_smbus
blacklist i2c_piix4
# Input (headless)
blacklist evdev
blacklist button
# Misc not needed
blacklist loop
blacklist ata_generic
blacklist i6300esb
blacklist qemu_fw_cfg
# Memory ballooning
blacklist virtio_balloon
# Hard block loop device
install loop /bin/true
EOF

# Strip initramfs features (Assumes virtio-blk. Change to "base ext4 scsi virtio" if virtio-scsi)
sed -i 's/^features=.*/features="base ext4 virtio"/' /etc/mkinitfs/mkinitfs.conf

# Strip unnecessary modules from bootloader and apply tuning parameters
sed -i 's/,usb-storage,ext4,ena,gve/,ext4 ipv6.disable=1 audit=0 nowatchdog/' /boot/extlinux.conf
sed -i 's/,usb-storage,ext4,ena,gve/,ext4/' /etc/update-extlinux.conf
sed -i 's/default_kernel_opts="/default_kernel_opts="ipv6.disable=1 audit=0 nowatchdog /' /etc/update-extlinux.conf

mkinitfs

echo "2: Replace OpenSSH with Dropbear"
echo "-----------------------------------------"
apk add dropbear

# We swap the startup services but do not stop sshd immediately. 
# Stopping sshd here over an active SSH session will terminate the script execution.
# The switch will safely take effect on reboot.
rc-update del sshd default
rc-update add dropbear default

echo "3: Remove Cloud-Init and Python"
echo "--------------------------------------------"
# Remove cloud-init and python dependencies dynamically
apk del $(grep "^P:" /lib/apk/db/installed | sed 's/^P://' | grep -E "^(cloud-init|cloud-utils|py3-|python3|pyc)")

echo "4: Package Cleanup"
echo "-----------------------------------------"
# Swap Chrony for Busybox ntpd
if rc-service chronyd status 2>/dev/null; then
    rc-service chronyd stop
fi
rc-update del chronyd default || true
rc-update add ntpd default
apk del chrony chrony-openrc

# Remove non-runtime utilities and hypervisor tools
apk del bash sudo doas nvme-cli syslinux mtools numactl curl e2fsprogs-extra partx qemu-guest-agent qemu-guest-agent-openrc

# Remove orphaned libraries
apk del readline gdbm mpdecimal sqlite-libs yaml p11-kit libtasn1 gnutls nettle gmp libidn2 libunistring libexpat libedit libffi shadow tzdata libseccomp libncursesw libpanelw ncurses-terminfo-base

# Remove DHCP client (assuming static IP deployed)
apk del dhcpcd dhcpcd-openrc

# remove OpenSSH (done last as it may drop the current session upon package removal)
apk del openssh openssh-client-common openssh-client-default openssh-keygen openssh-server openssh-server-common openssh-server-common-openrc openssh-server-pam openssh-sftp-server || true

# Clear cache
rm -rf /var/cache/apk/*

echo "5: Service Cleanup"
echo "-------------------------------------"
rc-update del acpid boot || true
rc-update del hwclock boot || true
rc-update del swap boot || true

echo "6: System Tuning"
echo "--------------------------------------"

# Suppress IPv6 sysctl errors since it's disabled in the kernel
sed -i '/net\.ipv6/s/^/# /' /usr/lib/sysctl.d/00-alpine.conf

# Prevent debugfs and tracefs mounting
sed -i 's/mount -n -t debugfs/: #mount -n -t debugfs/' /etc/init.d/sysfs
sed -i 's/mount -n -t tracefs/: #mount -n -t tracefs/' /etc/init.d/sysfs

# Network and kernel sysctl tuning
cat > /etc/sysctl.d/10-minvps.conf << 'EOF'
# Reduce network socket buffers
net.core.rmem_default = 32768
net.core.wmem_default = 32768
net.core.rmem_max = 131072
net.core.wmem_max = 131072
net.core.netdev_max_backlog = 64
net.core.somaxconn = 128
# Reclaim inode and dentry caches more aggressively under memory pressure
vm.vfs_cache_pressure = 500
# Reduce PID table overhead
kernel.pid_max = 4096
# Dirty page writeback thresholds
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
# Disable watchdog
kernel.watchdog = 0
EOF

# Switch syslog to in-memory circular buffer (64KB)
sed -i 's/SYSLOGD_OPTS="-t"/SYSLOGD_OPTS="-t -C64"/' /etc/conf.d/syslog

# Create local script to reduce block device read-ahead
echo 128 > /sys/block/vda/queue/read_ahead_kb
cat > /etc/local.d/readahead.start << 'EOF'
#!/bin/sh
echo 128 > /sys/block/vda/queue/read_ahead_kb
EOF
chmod +x /etc/local.d/readahead.start
rc-update add local default

echo ""
echo "--------------------------------------------------------------------"
echo "alpine-minimal-drobear.sh done, please reboot to apply all kernel and service changes."