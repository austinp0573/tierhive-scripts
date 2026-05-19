#!/bin/sh

# https://wiki.alpinelinux.org/wiki/Zram
# configure zram
# change any of the given variables as necessary
# lz4 requires the smallest amount of CPU
# effort and is not bad in terms of compression ratio
# https://linuxreviews.org/Comparison_of_Compression_Algorithms#zram_block_drive_compression
# https://imgur.com/EDLZNUZ

apk add --no-cache zram-init

cat > /etc/conf.d/zram-init << 'EOF'
load_on_start="yes"
unload_on_stop="yes"
num_devices="1"
type0="swap"
size0="256"
algo0="lz4"
priority0="100"
EOF

rc-update add zram-init boot
rc-service zram-init start