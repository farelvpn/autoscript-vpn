#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# AUTO DELETE EXPIRED VLESS ACCOUNTS
# ========================================================

clear
domain=$(cat /etc/xray/domain)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m              AUTO DELETE EXPIRED ACCOUNTS                 \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Function to check if account is expired - PERBAIKAN LENGKAP
is_expired() {
    local exp_date="$1"
    # Convert YYYY-MM-DD-HH-MM-SS to proper format for date command
    local year=$(echo "$exp_date" | cut -d'-' -f1)
    local month=$(echo "$exp_date" | cut -d'-' -f2)
    local day=$(echo "$exp_date" | cut -d'-' -f3)
    local hour=$(echo "$exp_date" | cut -d'-' -f4)
    local minute=$(echo "$exp_date" | cut -d'-' -f5)
    local second=$(echo "$exp_date" | cut -d'-' -f6)
    
    local exp_datetime="$year-$month-$day $hour:$minute:$second"
    local current_datetime=$(date "+%Y-%m-%d %H:%M:%S")
    
    local exp_timestamp=$(date -d "$exp_datetime" +%s 2>/dev/null)
    local current_timestamp=$(date -d "$current_datetime" +%s)
    
    if [[ -n "$exp_timestamp" && -n "$current_timestamp" ]]; then
        # If expiration timestamp is less than or equal to current timestamp, account is expired
        if [[ $exp_timestamp -le $current_timestamp ]]; then
            return 0  # Expired
        fi
    fi
    return 1  # Not expired
}

# Create recovery directory if it doesn't exist
mkdir -p /etc/xray/recovery/vless

# Check if database directory exists
if [[ ! -d "/etc/xray/database/vless" ]]; then
    echo "Database directory not found!"
    exit 0
fi

# Get list of user files
user_files=$(ls /etc/xray/database/vless/ 2>/dev/null)

if [[ -z "$user_files" ]]; then
    echo "No VLESS users found in database!"
    exit 0
fi

deleted_count=0
expired_accounts=()

echo "Checking for expired accounts..."
echo "────────────────────────────────────────────────────────────────"

# Check each user for expiration
for user_file in $user_files; do
    if [[ -f "/etc/xray/database/vless/$user_file" ]]; then
        username=$(echo "$user_file" | sed 's/\.txt$//')
        exp_date=$(grep "^expired:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
        
        if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
            if is_expired "$exp_date"; then
                expired_accounts+=("$username")
                echo "EXPIRED: $username (Expired: $exp_date)"
            else
                echo "ACTIVE : $username (Expires: $exp_date)"
            fi
        fi
    fi
done

echo "────────────────────────────────────────────────────────────────"

# If no expired accounts found
if [[ ${#expired_accounts[@]} -eq 0 ]]; then
    echo "No expired accounts found."
    exit 0
fi

echo "Found ${#expired_accounts[@]} expired account(s)."
echo ""
echo "Deleting expired accounts..."
echo "────────────────────────────────────────────────────────────────"

# Process each expired account
for username in "${expired_accounts[@]}"; do
    echo "Deleting: $username"
    
    # Move database file to recovery directory
    if [[ -f "/etc/xray/database/vless/${username}.txt" ]]; then
        mv "/etc/xray/database/vless/${username}.txt" "/etc/xray/recovery/vless/${username}.txt"
        echo "  ✓ Database file moved to recovery"
    fi
    
    # Remove quota limit file if exists
    if [[ -f "/etc/xray/limit/quota/vless/${username}" ]]; then
        rm -f "/etc/xray/limit/quota/vless/${username}"
        echo "  ✓ Quota limit file removed"
    fi
    
    # Remove IP limit file if exists
    if [[ -f "/etc/xray/limit/ip/vless/${username}" ]]; then
        rm -f "/etc/xray/limit/ip/vless/${username}"
        echo "  ✓ IP limit file removed"
    fi
    
    # Remove usage quota file if exists
    if [[ -f "/etc/xray/usage/quota/vless/${username}" ]]; then
        rm -f "/etc/xray/usage/quota/vless/${username}"
        echo "  ✓ Usage quota file removed"
    fi
    
    # Remove user from config.json
    sed -i "/#÷ $username /,/^}/d" /etc/xray/config.json
    # Clean up any trailing comma
    sed -i '/},/ { :a;N;$!ba;s/},\n\s*}/}\n}/g; }' /etc/xray/config.json
    
    echo "  ✓ User entry removed from config.json"
    ((deleted_count++))
done

# Restart Xray service if any accounts were deleted
if [[ $deleted_count -gt 0 ]]; then
    systemctl restart xray.service
    echo "✓ Xray service restarted"
fi

echo "────────────────────────────────────────────────────────────────"
echo "Auto deletion completed!"
echo "Deleted accounts: $deleted_count"
echo "Recovery files are available in: /etc/xray/recovery/vless/"

# Send to Telegram (if configured)
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" && $deleted_count -gt 0 ]]; then
    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     AUTO DELETE EXPIRED ACCOUNTS     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Deleted Accounts :</b> <code>$deleted_count</code>%0A"
    TEXT+="<b>Date            :</b> <code>$(date)</code>%0A"
    TEXT+="<b>Recovery        :</b> <code>Available</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    
    for username in "${expired_accounts[@]}"; do
        TEXT+="<b>Deleted:</b> <code>$username</code>%0A"
    done
    
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="${TEXT}" > /dev/null
fi

# Auto exit without waiting for key press
exit 0