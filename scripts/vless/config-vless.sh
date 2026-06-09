#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# VIEW VLESS ACCOUNT DETAILS
# ========================================================

clear
domain=$(cat /etc/xray/domain)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m              VIEW VLESS ACCOUNT DETAILS                  \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Display all users with expiration info
echo -e "Username\t\tExpired Date\t\tDays Remaining"
echo -e "────────────────────────────────────────────────────────────────"

# Check if database directory exists
if [[ ! -d "/etc/xray/database/vless" ]]; then
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
user_files=$(ls /etc/xray/database/vless/ 2>/dev/null)

if [[ -z "$user_files" ]]; then
    echo "No VLESS users found in database!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Display user list from database files
for user_file in $user_files; do
    if [[ -f "/etc/xray/database/vless/$user_file" ]]; then
        username=$(echo "$user_file" | sed 's/\.txt$//')
        exp_date=$(grep "^expired:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
        
        if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
            days_remaining=$(calculate_days_remaining "$exp_date")
            printf "%-20s\t%s\t%s\n" "$username" "$exp_date" "$days_remaining"
        fi
    fi
done

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Get username to view details
read -rp "Enter username to view details: " view_user

# Check if user exists in database
if [[ ! -f "/etc/xray/database/vless/${view_user}.txt" ]]; then
    echo "User '$view_user' not found in database!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Read account details from database
username=$(grep "^username:" "/etc/xray/database/vless/${view_user}.txt" | cut -d' ' -f2-)
uuid=$(grep "^uuid:" "/etc/xray/database/vless/${view_user}.txt" | cut -d' ' -f2-)
limit_ip=$(grep "^limit_ip:" "/etc/xray/database/vless/${view_user}.txt" | cut -d' ' -f2-)
quota=$(grep "^quota:" "/etc/xray/database/vless/${view_user}.txt" | cut -d' ' -f2-)
expired=$(grep "^expired:" "/etc/xray/database/vless/${view_user}.txt" | cut -d' ' -f2-)

# Format display values
if [[ "$limit_ip" == "0" ]]; then
    iplimit_display="Unlimited"
else
    iplimit_display="$limit_ip"
fi

if [[ "$quota" == "0" ]]; then
    quota_display="Unlimited"
else
    quota_display="${quota} GB"
fi

# Generate links
vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${username}"
vlesslink2="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${username}"

# Clear screen and display account details
clear
echo -e "
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
\e[0;41;36m                 VLESS ACCOUNT DETAILS                    \e[0m
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Hostname    : ${domain}
Username    : ${username}
Expired     : ${expired}
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
   ACCOUNT INFORMATION
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
UUID/Key    : $uuid
Encryption  : none
Path WS     : /vless
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
     PORT & SERVICE
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
VLESS WS TLS : 443
VLESS WS HTTP: 80
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Link VLESS WS TLS   : 
$vlesslink1
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Link VLESS WS Non-TLS : 
$vlesslink2
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

read -n 1 -s -r -p "Press any key to return to menu..."
menu