#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# RECOVER VMESS ACCOUNT
# ========================================================

clear
domain=$(cat /etc/xray/domain)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m              RECOVER VMESS ACCOUNT                        \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Check if recovery directory exists
if [[ ! -d "/etc/xray/recovery/vmess" ]]; then
    echo "Recovery directory not found!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Get list of recovery files
recovery_files=$(ls /etc/xray/recovery/vmess/ 2>/dev/null)

if [[ -z "$recovery_files" ]]; then
    echo "No deleted VMESS accounts found in recovery!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

echo "Deleted accounts available for recovery:"
echo "────────────────────────────────────────────────────────────────"

# Display recovery list
for recovery_file in $recovery_files; do
    if [[ -f "/etc/xray/recovery/vmess/$recovery_file" ]]; then
        username=$(echo "$recovery_file" | sed 's/\.txt$//')
        exp_date=$(grep "^expired:" "/etc/xray/recovery/vmess/$recovery_file" | cut -d' ' -f2-)
        deleted_date=$(stat -c %y "/etc/xray/recovery/vmess/$recovery_file" | cut -d' ' -f1)
        
        if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
            printf "%-20s\t%s\t%s\n" "$username" "$exp_date" "$deleted_date"
        fi
    fi
done

echo "────────────────────────────────────────────────────────────────"

# Get username to recover
read -rp "Enter username to recover: " recover_user

# Check if recovery file exists
if [[ ! -f "/etc/xray/recovery/vmess/${recover_user}.txt" ]]; then
    echo "Recovery file for user '$recover_user' not found!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    menu
    exit 0
fi

# Read account details from recovery file
username=$(grep "^username:" "/etc/xray/recovery/vmess/${recover_user}.txt" | cut -d' ' -f2-)
uuid=$(grep "^uuid:" "/etc/xray/recovery/vmess/${recover_user}.txt" | cut -d' ' -f2-)
limit_ip=$(grep "^limit_ip:" "/etc/xray/recovery/vmess/${recover_user}.txt" | cut -d' ' -f2-)
quota=$(grep "^quota:" "/etc/xray/recovery/vmess/${recover_user}.txt" | cut -d' ' -f2-)
expired=$(grep "^expired:" "/etc/xray/recovery/vmess/${recover_user}.txt" | cut -d' ' -f2-)

# Check if user already exists in current database
if [[ -f "/etc/xray/database/vmess/${recover_user}.txt" ]]; then
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
mkdir -p /etc/xray/limit/quota/vmess
mkdir -p /etc/xray/limit/ip/vmess
mkdir -p /etc/xray/database/vmess
mkdir -p /etc/xray/usage/quota/vmess

# Move recovery file back to database
mv "/etc/xray/recovery/vmess/${recover_user}.txt" "/etc/xray/database/vmess/${recover_user}.txt"

# Recreate quota limit file if quota > 0
if [[ "$quota" -gt 0 ]]; then
    bytes=$((quota * 1024 * 1024 * 1024))
    echo "$bytes" > "/etc/xray/limit/quota/vmess/$recover_user"
fi

# Recreate IP limit file if limit_ip > 0
if [[ "$limit_ip" -gt 0 ]]; then
    echo "$limit_ip" > "/etc/xray/limit/ip/vmess/$recover_user"
fi

# Add user to config.json
sed -i '/#vmess$/a\### '"$recover_user $expired"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$recover_user""'"' /etc/xray/config.json

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
acs=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`

ask=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF`


vmesslink1="vmess://$(echo $acs | base64 -w 0)"
vmesslink2="vmess://$(echo $ask | base64 -w 0)"

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
Path WS     : /vmess
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
     PORT & SERVICE
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
VMESS WS TLS : 443
VMESS WS HTTP: 80
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Link VMESS WS TLS   : 
$vmesslink1
\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m
Link VMESS WS Non-TLS : 
$vmesslink2
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