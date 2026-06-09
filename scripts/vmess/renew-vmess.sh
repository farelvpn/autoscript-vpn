#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# RENEW VMESS ACCOUNT EXPIRATION
# ========================================================

clear
domain=$(cat /etc/xray/domain)

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

# Function to validate input
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "username")
            [[ -n "$input" ]] && return 0
            echo "Username cannot be empty"
            ;;
        "days")
            [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -gt 0 ]] && return 0
            echo "Days must be a positive number"
            ;;
    esac
    return 1
}

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m              RENEW VMESS ACCOUNT EXPIRATION               \e[0m"
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

# Get username to renew
until false; do
    read -rp "Enter username to renew: " renew_user
    
    if validate_input "$renew_user" "username"; then
        # Check if user exists in database
        if [[ -f "/etc/xray/database/vmess/${renew_user}.txt" ]]; then
            break
        else
            echo "User '$renew_user' not found in database!"
            read -n 1 -s -r -p "Press any key to continue..."
        fi
    else
        read -n 1 -s -r -p "Press any key to continue..."
    fi
    echo ""
done

# Get current expiration date from database
current_exp=$(grep "^expired:" "/etc/xray/database/vmess/${renew_user}.txt" | cut -d' ' -f2-)

echo ""
echo "Current expiration: $current_exp"

# Get renewal days
until false; do
    read -rp "Enter additional days (e.g., 30 for 30 days): " renew_days
    
    if validate_input "$renew_days" "days"; then
        break
    else
        read -n 1 -s -r -p "Press any key to continue..."
    fi
    echo ""
done

# Calculate new expiration date - METODE YANG DIPERBAIKI
# Parse the current expiration date
IFS='-' read -r year month day hour minute second <<< "$current_exp"

# Create a proper date string for the date command
current_date_str="$year-$month-$day $hour:$minute:$second"

# Debug: Show what we're working with
echo "Debug: Current date string: $current_date_str"
echo "Debug: Adding $renew_days days"

# Calculate new expiration using timestamp arithmetic
current_timestamp=$(date -d "$current_date_str" +%s 2>/dev/null)
if [[ -z "$current_timestamp" ]]; then
    echo "Error: Cannot parse current expiration date!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 1
fi

# Add the specified number of days (in seconds)
seconds_to_add=$((renew_days * 24 * 60 * 60))
new_timestamp=$((current_timestamp + seconds_to_add))

# Convert back to our desired format
new_exp=$(date -d "@$new_timestamp" +"%Y-%m-%d-%H-%M-%S" 2>/dev/null)

# Check if new_exp was calculated successfully
if [[ -z "$new_exp" || "$new_exp" == " " ]]; then
    echo "Error calculating new expiration date!"
    echo "Current timestamp: $current_timestamp"
    echo "Seconds to add: $seconds_to_add"
    echo "New timestamp: $new_timestamp"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 1
fi

# Update expiration in database file
sed -i "s/expired:.*/expired: $new_exp/" /etc/xray/database/vmess/${renew_user}.txt

# Update expiration in config.json (if user exists there)
if grep -q "\"$renew_user\"" /etc/xray/config.json; then
    sed -i "s/### $renew_user .*/### $renew_user $new_exp/" /etc/xray/config.json
fi

# Restart Xray service
systemctl restart xray.service

# Clear screen and display result
clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                 ACCOUNT RENEWAL SUCCESS                   \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "Username        : \e[1;32m$renew_user\e[0m"
echo -e "Old Expiration  : \e[1;31m$current_exp\e[0m"
echo -e "New Expiration  : \e[1;32m$new_exp\e[0m"
echo -e "Added Days      : \e[1;36m${renew_days} days\e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Send to Telegram (if configured)
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     ACCOUNT RENEWAL     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Username     :</b> <code>$renew_user</code>%0A"
    TEXT+="<b>Old Expired  :</b> <code>$current_exp</code>%0A"
    TEXT+="<b>New Expired  :</b> <code>$new_exp</code>%0A"
    TEXT+="<b>Added Days   :</b> <code>${renew_days} days</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="${TEXT}" > /dev/null
fi

read -n 1 -s -r -p "Press any key to return to menu..."
menu