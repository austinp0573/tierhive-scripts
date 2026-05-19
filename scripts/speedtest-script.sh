#!/bin/sh

# Ensure cleanup if script is aborted mid-test
trap "rm -f /tmp/speed_v4.txt /tmp/speed_v6.txt" EXIT

echo ""
echo "NAT test (IPv4)"
echo "-----------------"
# curl runs completely unhindered, but saves the raw decimal bytes value to a tmp file
curl -4 -o /dev/null -w "%{speed_download}" http://ping.online.net/1000Mo.dat > /tmp/speed_v4.txt

# Read the file contents into a standard script variable
RAW_V4=$(cat /tmp/speed_v4.txt)
MBPS_V4=$(awk "BEGIN {printf \"%.2f\", ($RAW_V4 * 8) / 1000000}")
echo ""
echo "Calculated Result: $MBPS_V4 Mbps"

echo ""
echo ""

echo "IPv6 test"
echo "-----------------"
# curl runs completely unhindered, but saves the raw decimal bytes value to a tmp file
curl -6 -o /dev/null -w "%{speed_download}" http://ping6.online.net/1000Mo.dat > /tmp/speed_v6.txt

# Read the file contents into a standard script variable
RAW_V6=$(cat /tmp/speed_v6.txt)
MBPS_V6=$(awk "BEGIN {printf \"%.2f\", ($RAW_V6 * 8) / 1000000}")
echo ""
echo "Calculated Result: $MBPS_V6 Mbps"

echo ""
echo "End of test"
