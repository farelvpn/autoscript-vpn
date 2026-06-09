#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# LIST VLESS ACCOUNTS
# ========================================================

clear
domain=$(cat /etc/xray/domain)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m                    MEMBER XRAY VLESS                       \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Function to calculate days remaining
calculate_days_remaining() {
    local exp_date="$1"
    # Convert YYYY-MM-DD-HH-MM-SS to YYYY-MM-DD for date comparison
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

# Function to format quota
format_quota() {
    local quota_file="$1"
    if [[ -f "$quota_file" ]]; then
        local quota_bytes=$(cat "$quota_file")
        if [[ "$quota_bytes" == "0" ]] || [[ -z "$quota_bytes" ]]; then
            echo "Unlimited"
        else
            local quota_gb=$((quota_bytes / (1024 * 1024 * 1024)))
            echo "${quota_gb} GB"
        fi
    else
        echo "Unlimited"
    fi
}

# Function to format IP limit
format_ip_limit() {
    local ip_file="$1"
    if [[ -f "$ip_file" ]]; then
        local ip_limit=$(cat "$ip_file")
        if [[ "$ip_limit" == "0" ]] || [[ -z "$ip_limit" ]]; then
            echo "Unlimited"
        else
            echo "$ip_limit"
        fi
    else
        echo "Unlimited"
    fi
}

# Check if database directory exists
if [[ ! -d "/etc/xray/database/vless" ]]; then
    echo "Database directory not found!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Get list of user files
user_files=$(ls /etc/xray/database/vless/ 2>/dev/null)

if [[ -z "$user_files" ]]; then
    echo "No VLESS users found in database!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Process each user
user_count=0
first_user=true
for user_file in $user_files; do
    if [[ -f "/etc/xray/database/vless/$user_file" ]]; then
        if [[ "$first_user" == false ]]; then
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        fi
        first_user=false
        
        ((user_count++))
        
        # Read account details
        username=$(echo "$user_file" | sed 's/\.txt$//')
        uuid=$(grep "^uuid:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
        limit_ip_raw=$(grep "^limit_ip:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
        quota_raw=$(grep "^quota:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
        expired=$(grep "^expired:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
        
        # Format values
        days_left=$(calculate_days_remaining "$expired")
        limit_ip=$(format_ip_limit "/etc/xray/limit/ip/vless/$username")
        quota=$(format_quota "/etc/xray/limit/quota/vless/$username")
        
        # Display user info
        echo "Username: $username"
        echo "UUID: $uuid"
        echo "Expired: $expired ($days_left days left)"
        echo "Limit IP: $limit_ip"
        echo "Quota: $quota"
        echo ""
    fi
done

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "Total Users: $user_count"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

read -n 1 -s -r -p "Press any key to return to menu..."
menu