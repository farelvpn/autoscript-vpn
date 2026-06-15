#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Timezone Changer
# ========================================================
[[ -f /usr/local/sbin/lib/common.sh ]] && . /usr/local/sbin/lib/common.sh
clear
ui_header "CHANGE TIMEZONE"

current_tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
echo "Current Timezone: $current_tz"
echo ""
echo "Example Timezones: Asia/Jakarta, Asia/Kuala_Lumpur, UTC"
read -p "Enter New Timezone: " new_tz

if [[ -z "$new_tz" ]]; then
    echo "Timezone cannot be empty."
    exit 1
fi

if timedatectl set-timezone "$new_tz" 2>/dev/null; then
    echo "------------------------------------------------------------"
    echo -e "\e[32mTimezone successfully changed to: $new_tz\e[0m"
    echo "Current System Time: $(date)"

    # Re-arm systemd timers so OnCalendar schedules recompute for the new TZ.
    systemctl daemon-reload 2>/dev/null
    systemctl restart autoexpire.timer limit-ip-ssh.timer backup.timer fixlog.timer 2>/dev/null
else
    echo -e "\e[31mFailed to set timezone. Please check the spelling (e.g., Asia/Jakarta).\e[0m"
fi

echo "------------------------------------------------------------"
read -n 1 -s -r -p "Press any key to return to menu..."
menu