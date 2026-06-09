#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# ========================================================
# System Uninstaller
# ========================================================
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                 AUTOSCRIPT UNINSTALLER                     \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[31mWARNING: This will remove all VPN/Proxy configurations, accounts, and databases!\e[0m"
read -p "Are you sure you want to proceed? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo "Stopping services..."
systemctl stop haproxy xray nginx dropbear ssh-ws badvpn quota limit-ip-vless quota-trojan limit-ip-trojan quota-vmess limit-ip-vmess server openvpn-server@server-udp-2200 openvpn-server@server-tcp-1194 2>/dev/null
systemctl disable haproxy xray nginx dropbear ssh-ws badvpn quota limit-ip-vless quota-trojan limit-ip-trojan quota-vmess limit-ip-vmess server openvpn-server@server-udp-2200 openvpn-server@server-tcp-1194 2>/dev/null

echo "Removing directories..."
rm -rf /etc/xray
rm -rf /etc/nginx/risqinf.conf
rm -rf /etc/nginx/conf.d/openvpn.conf
rm -rf /etc/dropbear
rm -rf /etc/openvpn
rm -rf /var/www/html/*
rm -rf /var/log/xray
rm -rf /var/log/nginx

echo "Removing binaries and services..."
rm -f /usr/local/bin/xray
rm -f /usr/local/bin/proxy
rm -f /usr/local/bin/badvpn
rm -f /usr/local/bin/server
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/ssh-ws.service
rm -f /etc/systemd/system/badvpn.service
rm -f /etc/systemd/system/quota*.service
rm -f /etc/systemd/system/limit-ip-*.service
rm -f /etc/systemd/system/server.service
rm -f /etc/systemd/system/dropbear.service
systemctl daemon-reload

echo "Removing management scripts..."
# Remove the API command handlers and the menu/command scripts installed
# into /usr/local/sbin (bare command names without .sh).
rm -rf /usr/local/sbin/api
for cmd in menu menu-ssh menu-vless menu-vmess menu-trojan menu-host menu-backup menu-api menu-dropbear \
    add-ssh add-vless add-vmess add-trojan add-bulk \
    trial-ssh trial-vless trial-vmess trial-trojan \
    delete-ssh delete-vless delete-vmess delete-trojan \
    renew-ssh renew-vless renew-vmess renew-trojan \
    recovery-ssh recovery-vless recovery-vmess recovery-trojan \
    cek-ssh cek-vless cek-vmess cek-trojan cek-user \
    config-ssh config-vless config-vmess config-trojan \
    list-ssh list-vless list-vmess list-trojan \
    limit-ip-ssh limit-ip-vless limit-ip-vmess limit-ip-trojan \
    loop-ip-vless loop-ip-vmess loop-ip-trojan \
    loop-quota-vless loop-quota-vmess loop-quota-trojan \
    quota-vless quota-vmess quota-trojan \
    xp-ssh xp-vless xp-vmess xp-trojan \
    backup restore fixlog versi-xray stream-check change-domain change-timezone helium; do
    rm -f "/usr/local/sbin/$cmd"
done

echo "Cleaning up crontab..."
sed -i '/xp-ssh/d' /etc/crontab
sed -i '/xp-vless/d' /etc/crontab
sed -i '/xp-vmess/d' /etc/crontab
sed -i '/xp-trojan/d' /etc/crontab
sed -i '/backup/d' /etc/crontab
sed -i '/fixlog/d' /etc/crontab
sed -i '/cek-/d' /etc/crontab
systemctl restart crond 2>/dev/null

echo "Restoring packages..."
dnf remove haproxy epel-release nginx dropbear openvpn easy-rsa -y >/dev/null 2>&1

echo "Uninstallation complete. It is recommended to reboot the server."