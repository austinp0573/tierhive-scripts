#!/bin/sh


set -e

# 1. Clear memory caches to free up every possible drop of RAM
echo
echo "-----------------------------------------"
echo "clearing memory caches"
echo "-----------------------------------------"
echo
sync; echo 3 > /proc/sys/vm/drop_caches


echo
echo "-----------------------------------------"
echo "updating repositories and installing nginx"
echo "-----------------------------------------"
echo
apk update
apk add nginx tzdata


echo
echo "-----------------------------------------"
echo "setting timezone to america/chicago and cleaning up tzdata"
echo "-----------------------------------------"
echo
cp /usr/share/zoneinfo/America/Chicago /etc/localtime
echo "America/Chicago" > /etc/timezone
apk del tzdata


echo
echo "-----------------------------------------"
echo "creating web root directory at /var/www/cf-say"
echo "-----------------------------------------"
echo
mkdir -p /var/www/cf-say

echo
echo "-----------------------------------------"
echo "writing minimal nginx configuration"
echo "-----------------------------------------"
echo
cat << 'EOF' > /etc/nginx/http.d/default.conf
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/cf-say;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ /\.git {
        deny all;
    }

    location ~ /\.ht {
        deny all;
    }

    # Disable access logs to save disk I/O and CPU cycles
    access_log off;
    error_log /var/log/nginx/error.log crit;
}

EOF


echo
echo "-----------------------------------------"
echo "fixing permissions for nginx web root"
echo "-----------------------------------------"
echo
chown -R nginx:nginx /var/www/cf-say
chmod 755 /var/www/cf-say


echo
echo "-----------------------------------------"
echo "enabling and starting nginx"
echo "-----------------------------------------"
echo
rc-update add nginx default
rc-service nginx start