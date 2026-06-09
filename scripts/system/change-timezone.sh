#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Timezone Changer
# ========================================================
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                   CHANGE TIMEZONE                          \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

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
    
    # Restart cron to apply new timezone schedule
    systemctl restart crond 2>/dev/null
else
    echo -e "\e[31mFailed to set timezone. Please check the spelling (e.g., Asia/Jakarta).\e[0m"
fi

echo "------------------------------------------------------------"
read -n 1 -s -r -p "Press any key to return to menu..."
menu