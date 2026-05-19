#!/bin/sh
# exit immediately if any command fails
set -e

# clear default motd
echo -n "" > /etc/motd

echo ""
echo "optimize network and configure IPv6"
echo ""

# 1. prompt for host IPv6 address and gateway
printf "Enter your allocated IPv6 Address (e.g., 2a11:6c7:1900:2017::2): "
read -r USER_IPV6

printf "Enter your provider's IPv6 Gateway (e.g., 2a11:6c7:1900:2017::1): "
read -r USER_GATEWAY

if [ -z "$USER_IPV6" ] || [ -z "$USER_GATEWAY" ]; then
    echo "Error: IPv6 address and gateway cannot be empty."
    exit 1
fi

echo ""
echo "Optimizing Kernel Network Parameters (BBR & Buffers)"

# 2. Write System Control Network Optimizations
cat << 'EOF' > /etc/sysctl.d/99-networking-optimized.conf
# Enable BBR TCP Congestion Control
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# Maximize network receive and transmit window buffer scales
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# Optimize backlog and memory reuse thresholds
net.core.netdev_max_backlog=10000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# Enable kernel-level IPv6 processing and Router Advertisements
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.all.accept_ra=2
EOF

# Explicitly parse the config file using BusyBox-compatible sysctl syntax
sysctl -p /etc/sysctl.d/99-networking-optimized.conf

echo ""
echo "Prioritizing IPv6 DNS Resolutions"
# 3. Enforce Operating System IPv6 Routing Priority
cat << 'EOF' > /etc/gai.conf
# Standard configuration rules prioritizing IPv6 addresses globally
precedence ::ffff:0:0/96  10
precedence ::/0          40
EOF

echo ""
echo "Appending IPv6 Configuration to /etc/network/interfaces"
# 4. Safely append the block to the end of the existing interfaces file
cat << EOF >> /etc/network/interfaces

iface eth0 inet6 static
    address $USER_IPV6
    netmask 64
    gateway $USER_GATEWAY
EOF

echo ""
echo "Scheduling Background Network Reload"
# 5. Fork the network restart so it doesn't kill your active terminal execution
(sleep 1 && rc-service networking restart) >/dev/null 2>&1 &

echo ""
echo "Network Optimization and IPv6 setup complete"

# may need to alter this to account for higher funtioning IPv4
# NAT, it just depends on what the speedtest indicates