#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# RECOVER VLESS ACCOUNT
# ========================================================

clear
domain=$(cat /etc/xray/domain)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m              RECOVER VLESS ACCOUNT                        \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Check if recovery directory exists
if [[ ! -d "/etc/xray/recovery/vless" ]]; then
    echo "Recovery directory not found!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Get list of recovery files
recovery_files=$(ls /etc/xray/recovery/vless/ 2>/dev/null)

if [[ -z "$recovery_files" ]]; then
    echo "No deleted VLESS accounts found in recovery!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

echo "Deleted accounts available for recovery:"
echo "────────────────────────────────────────────────────────────────"

# Display recovery list
for recovery_file in $recovery_files; do
    if [[ -f "/etc/xray/recovery/vless/$recovery_file" ]]; then
        username=$(echo "$recovery_file" | sed 's/\.txt$//')
        exp_date=$(grep "^expired:" "/etc/xray/recovery/vless/$recovery_file" | cut -d' ' -f2-)
        deleted_date=$(stat -c %y "/etc/xray/recovery/vless/$recovery_file" | cut -d' ' -f1)
        
        if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
            printf "%-20s\t%s\t%s\n" "$username" "$exp_date" "$deleted_date"
        fi
    fi
done

echo "────────────────────────────────────────────────────────────────"

# Get username to recover
read -rp "Enter username to recover: " recover_user

# Check if recovery file exists
if [[ ! -f "/etc/xray/recovery/vless/${recover_user}.txt" ]]; then
    echo "Recovery file for user '$recover_user' not found!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Read account details from recovery file
username=$(grep "^username:" "/etc/xray/recovery/vless/${recover_user}.txt" | cut -d' ' -f2-)
uuid=$(grep "^uuid:" "/etc/xray/recovery/vless/${recover_user}.txt" | cut -d' ' -f2-)
limit_ip=$(grep "^limit_ip:" "/etc/xray/recovery/vless/${recover_user}.txt" | cut -d' ' -f2-)
quota=$(grep "^quota:" "/etc/xray/recovery/vless/${recover_user}.txt" | cut -d' ' -f2-)
expired=$(grep "^expired:" "/etc/xray/recovery/vless/${recover_user}.txt" | cut -d' ' -f2-)

# Check if user already exists in current database
if [[ -f "/etc/xray/database/vless/${recover_user}.txt" ]]; then
    echo "User '$recover_user' already exists in current database!"
    read -rp "Do you want to overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Recovery cancelled."
        read -n 1 -s -r -p "Press any key to return to menu..."
        menu
        exit 0
    fi
fi

# Create necessary directories if they don't exist
mkdir -p /etc/xray/limit/quota/vless
mkdir -p /etc/xray/limit/ip/vless
mkdir -p /etc/xray/database/vless
mkdir -p /etc/xray/usage/quota/vless

# Move recovery file back to database
mv "/etc/xray/recovery/vless/${recover_user}.txt" "/etc/xray/database/vless/${recover_user}.txt"

# Recreate quota limit file if quota > 0
if [[ "$quota" -gt 0 ]]; then
    bytes=$((quota * 1024 * 1024 * 1024))
    echo "$bytes" > "/etc/xray/limit/quota/vless/$recover_user"
fi

# Recreate IP limit file if limit_ip > 0
if [[ "$limit_ip" -gt 0 ]]; then
    echo "$limit_ip" > "/etc/xray/limit/ip/vless/$recover_user"
fi

# Add user to config.json
sed -i '/#vless$/a\#÷ '"$recover_user $expired"'\
},{"id": "'"$uuid"'","email": "'"$recover_user"'"' /etc/xray/config.json

# Restart Xray service
systemctl restart xray.service

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

# Clear screen and display result
clear
echo -e "
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
\e[0;41;36m                 ACCOUNT RECOVERY SUCCESS                  \e[0m
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

# Send to Telegram (if configured)
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     ACCOUNT RECOVERY     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Username     :</b> <code>$recover_user</code>%0A"
    TEXT+="<b>Status       :</b> <code>RECOVERED</code>%0A"
    TEXT+="<b>Expired      :</b> <code>$expired</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="${TEXT}" > /dev/null
fi

read -n 1 -s -r -p "Press any key to return to menu..."
menu