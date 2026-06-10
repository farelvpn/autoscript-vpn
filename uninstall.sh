#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
# System Uninstaller — removes everything install.sh created:
#   services, binaries, command scripts, libraries, database, configs,
#   cron entries, login profile, and (optionally) the swap file.
# It intentionally does NOT revert sshd_config or firewall rules, to avoid
# locking you out of an active session. Those are noted at the end.
# ========================================================
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;41;36m                 AUTOSCRIPT UNINSTALLER                     \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mError: must be run as root.\e[0m"
    exit 1
fi

echo -e "\e[31mWARNING: This removes ALL VPN/proxy configs, accounts, and the database!\e[0m"
read -rp "Type 'yes' to proceed: " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# ---------------------------------------------------------------------------
echo "[1/8] Stopping and disabling services..."
SERVICES=(
    haproxy xray nginx dropbear ssh-ws server
    quota limit-ip-vless quota-trojan limit-ip-trojan quota-vmess limit-ip-vmess
    openvpn-server@server-udp-2200 openvpn-server@server-tcp-1194
)
for svc in "${SERVICES[@]}"; do
    systemctl stop "$svc" 2>/dev/null
    systemctl disable "$svc" 2>/dev/null
done

# ---------------------------------------------------------------------------
echo "[2/8] Removing systemd unit files..."
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/ssh-ws.service
rm -f /etc/systemd/system/server.service
rm -f /etc/systemd/system/dropbear.service
rm -f /etc/systemd/system/quota.service
rm -f /etc/systemd/system/quota-trojan.service
rm -f /etc/systemd/system/quota-vmess.service
rm -f /etc/systemd/system/limit-ip-vless.service
rm -f /etc/systemd/system/limit-ip-trojan.service
rm -f /etc/systemd/system/limit-ip-vmess.service
systemctl daemon-reload

# ---------------------------------------------------------------------------
echo "[3/8] Removing binaries and runtime files..."
rm -f /usr/local/bin/xray
rm -f /usr/local/bin/server
rm -f /usr/local/bin/ssh-ws
rm -f /var/log/ssh-ws.log
rm -rf /usr/local/share/xray
rm -f /etc/rsyslog.d/00-autoscript-secure.conf
systemctl restart rsyslog 2>/dev/null

# ---------------------------------------------------------------------------
echo "[4/8] Removing management scripts, libraries, and API handlers..."
rm -rf /usr/local/sbin/api
rm -rf /usr/local/sbin/lib
rm -f /usr/local/sbin/db-migrate
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
    backup restore fixlog versi-xray stream-check change-domain change-timezone; do
    rm -f "/usr/local/sbin/$cmd"
done

# ---------------------------------------------------------------------------
echo "[5/8] Removing configs, database, and web/log directories..."
rm -rf /etc/xray                       # config.json, xray.db, domain, keys, backup.pass
rm -f  /etc/nginx/risqinf.conf
rm -rf /etc/dropbear
rm -rf /etc/openvpn
rm -rf /var/www/html/risqinf
rm -rf /var/log/xray

# ---------------------------------------------------------------------------
echo "[6/8] Cleaning up crontab and login profile..."
for pat in xp-ssh xp-vless xp-vmess xp-trojan limit-ip-ssh backup fixlog cek-; do
    sed -i "/ $pat/d" /etc/crontab 2>/dev/null
done
systemctl restart crond 2>/dev/null
# Restore a normal root login profile (installer set 'clear ; menu').
[[ -f /root/.profile ]] && grep -q "menu" /root/.profile && : > /root/.profile

# ---------------------------------------------------------------------------
echo "[7/8] Optional: remove swap file created by the installer..."
if [[ -f /swapfile ]]; then
    read -rp "Remove /swapfile too? (y/N): " rmswap
    if [[ "$rmswap" =~ ^[Yy]$ ]]; then
        swapoff /swapfile 2>/dev/null
        sed -i '/swapfile/d' /etc/fstab 2>/dev/null
        rm -f /swapfile
        echo "  Swap removed."
    fi
fi

# ---------------------------------------------------------------------------
echo "[8/8] Removing packages (best effort)..."
dnf remove haproxy nginx dropbear openvpn easy-rsa -y >/dev/null 2>&1

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;42;30m              UNINSTALLATION COMPLETE                       \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo "Not reverted (to avoid lockout) — adjust manually if desired:"
echo "  - /etc/ssh/sshd_config (Port 22/3303, root login, password auth)"
echo "  - firewall-cmd rules (open ports)"
echo "  - /etc/sysctl.conf network tuning"
echo "  - rsyslog package (kept; only the drop-in was removed)"
echo "It is recommended to reboot the server."
