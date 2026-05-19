#!/bin/sh

# setup swap
# change SWAP_SIZE_MB to alter the size of the swap

set -eu

SWAP_PATH="/swapfile"
SWAP_SIZE_MB=512

echo "creating a $SWAP_SIZE_MB MB allocated swap file at $SWAP_PATH"
# dd is used as fallocate can cause fragmentation issues on certain filesystems like btrfs/ext4 on Alpine
dd if=/dev/zero of="$SWAP_PATH" bs=1M count="$SWAP_SIZE_MB"
chmod 600 "$SWAP_PATH"

echo "setting up swap space"
mkswap "$SWAP_PATH"

echo "enabling swap file"
swapon "$SWAP_PATH"

echo "configuring permanent swap in /etc/fstab"
if ! grep -q "$SWAP_PATH" /etc/fstab; then
    echo "$SWAP_PATH none swap sw 0 0" >> /etc/fstab
fi

echo "optimizing swappiness for low-RAM environment"

# set swappiness to 10 to prefer keeping data in RAM, minimizing disk I/O
echo "vm.swappiness=10" > /etc/sysctl.d/swap.conf
sysctl -p /etc/sysctl.d/swap.conf

echo ""
echo "swap configuration complete"
echo "---------------------------"

free -h