#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# DELETE VMESS ACCOUNT WITH RECOVERY
# ========================================================

clear
domain=$(cat /etc/xray/domain)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m              DELETE VMESS ACCOUNT                         \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Display all users with expiration info
echo -e "Username\t\tExpired Date\t\tDays Remaining"
echo -e "────────────────────────────────────────────────────────────────"

# Check if database directory exists
if [[ ! -d "/etc/xray/database/vmess" ]]; then
    echo "Database directory not found!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Function to calculate days remaining
calculate_days_remaining() {
    local exp_date="$1"
    # Convert YYYY-MM-DD-HH-MM-SS to YYYY-MM-DD for date comparison (only date part)
    local exp_date_only=$(echo "$exp_date" | cut -d'-' -f1-3)
    local current_date=$(date +%Y-%m-%d)
    
    local exp_timestamp=$(date -d "$exp_date_only" +%s 2>/dev/null)
    local current_timestamp=$(date -d "$current_date" +%s)
    
    if [[ -n "$exp_timestamp" ]]; then
        local diff_seconds=$((exp_timestamp - current_timestamp))
        local days_remaining=$((diff_seconds / 86400))
        if [[ $days_remaining -lt 0 ]]; then
            echo "0"
        else
            echo "$days_remaining"
        fi
    else
        echo "Invalid"
    fi
}

# Get list of user files
user_files=$(ls /etc/xray/database/vmess/ 2>/dev/null)

if [[ -z "$user_files" ]]; then
    echo "No VMESS users found in database!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Display user list from database files
for user_file in $user_files; do
    if [[ -f "/etc/xray/database/vmess/$user_file" ]]; then
        username=$(echo "$user_file" | sed 's/\.txt$//')
        exp_date=$(grep "^expired:" "/etc/xray/database/vmess/$user_file" | cut -d' ' -f2-)
        
        if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
            days_remaining=$(calculate_days_remaining "$exp_date")
            printf "%-20s\t%s\t%s\n" "$username" "$exp_date" "$days_remaining"
        fi
    fi
done

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Get username to delete
read -rp "Enter username to delete: " delete_user

# Check if user exists in database
if [[ ! -f "/etc/xray/database/vmess/${delete_user}.txt" ]]; then
    echo "User '$delete_user' not found in database!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Confirmation
echo ""
read -rp "Are you sure you want to delete user '$delete_user'? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Account deletion cancelled."
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Create recovery directory if it doesn't exist
mkdir -p /etc/xray/recovery/vmess

# Move database file to recovery directory
if [[ -f "/etc/xray/database/vmess/${delete_user}.txt" ]]; then
    mv "/etc/xray/database/vmess/${delete_user}.txt" "/etc/xray/recovery/vmess/${delete_user}.txt"
    echo "Database file moved to recovery directory."
fi

# Remove quota limit file if exists
if [[ -f "/etc/xray/limit/quota/vmess/${delete_user}" ]]; then
    rm -f "/etc/xray/limit/quota/vmess/${delete_user}"
    echo "Quota limit file removed."
fi

# Remove IP limit file if exists
if [[ -f "/etc/xray/limit/ip/vmess/${delete_user}" ]]; then
    rm -f "/etc/xray/limit/ip/vmess/${delete_user}"
    echo "IP limit file removed."
fi

# Remove usage quota file if exists
if [[ -f "/etc/xray/usage/quota/vmess/${delete_user}" ]]; then
    rm -f "/etc/xray/usage/quota/vmess/${delete_user}"
    echo "Usage quota file removed."
fi

# Remove user from config.json
# Remove the user entry (2 lines: the ### comment line and the user data line)
sed -i "/### $delete_user /,/^}/d" /etc/xray/config.json
# Also remove any trailing comma that might be left
sed -i '/},/ { :a;N;$!ba;s/},\n\s*}/}\n}/g; }' /etc/xray/config.json

echo "User entry removed from config.json."

# Restart Xray service
systemctl restart xray.service
echo "Xray service restarted."

# Clear screen and display result
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                 ACCOUNT DELETION SUCCESS                  \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "Username        : \e[1;31m$delete_user\e[0m"
echo -e "Status          : \e[1;32mDELETED\e[0m"
echo -e "Recovery File   : \e[1;36m/etc/xray/recovery/vmess/${delete_user}.txt\e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "To recover this account, use the recovery feature."
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Send to Telegram (if configured)
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     ACCOUNT DELETED     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Username     :</b> <code>$delete_user</code>%0A"
    TEXT+="<b>Status       :</b> <code>DELETED</code>%0A"
    TEXT+="<b>Recovery     :</b> <code>Available</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="${TEXT}" > /dev/null
fi

read -n 1 -s -r -p "Press any key to return to menu..."
menu