#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# TRIAL VLESS ACCOUNT CREATOR
# ========================================================

clear
domain=$(cat /etc/xray/domain)

# Function to convert bytes to human readable format (SIMPLIFIED)
bytes_to_human() {
    local bytes=$1
    local units=('B' 'KB' 'MB' 'GB' 'TB' 'PB' 'EB' 'ZB' 'YB')
    local unit=0
    
    # Handle unlimited case
    if [[ $bytes -eq 0 ]]; then
        echo "Unlimited"
        return
    fi
    
    # Convert bytes to the appropriate unit
    while (( bytes >= 1024 )) && (( unit < ${#units[@]} - 1 )); do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes} ${units[$unit]}"
}

# Function to validate input
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "duration")
            [[ "$input" =~ ^[0-9]+[mhd]$ ]] && return 0
            echo "Duration format must be like: 30m, 2h, 1d"
            ;;
    esac
    return 1
}

# Create necessary directories if they don't exist
mkdir -p /etc/xray/limit/quota/vless
mkdir -p /etc/xray/limit/ip/vless
mkdir -p /etc/xray/database/vless
mkdir -p /etc/xray/usage/quota/vless

# Generate random username with prefix "trial"
random_number=$((RANDOM % 1000))
user="trial${random_number}"

# Check if user exists and generate new if needed
while [[ $(grep -w "\"$user\"" /etc/xray/config.json | wc -l) -gt 0 ]]; do
    random_number=$((RANDOM % 1000))
    user="trial${random_number}"
done

# Generate random UUID (standard format)
uuid=$(cat /proc/sys/kernel/random/uuid)

# Set default values for trial
quota=10  # 10 GB
iplimit=2 # 2 IP limit

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo -e "\e[0;41;36m  CREATE TRIAL VLESS ACCOUNT     \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
echo "Username: $user"
echo "UUID: $uuid"
echo "Quota: $quota GB"
echo "IP Limit: $iplimit"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

# Get duration
until false; do
    read -rp "Expired (ex: 30m / 2h / 1d): " duration
    if [[ -z "$duration" ]]; then
        echo "Duration cannot be empty"
        read -n 1 -s -r -p "Press any key to continue..."
        continue
    fi
    
    if validate_input "$duration" "duration"; then
        break
    fi
    read -n 1 -s -r -p "Press any key to continue..."
done

# Calculate expiration
case "$duration" in
    *m) seconds=$(( ${duration%m} * 60 )) ;;
    *h) seconds=$(( ${duration%h} * 3600 )) ;;
    *d) seconds=$(( ${duration%d} * 86400 )) ;;
esac

exp=$(date -d "+$seconds seconds" +"%Y-%m-%d-%H-%M-%S")
exp_full=$exp

# Set quota and IP limit
if [[ $quota -gt 0 ]]; then
    bytes=$((quota * 1024 * 1024 * 1024))
    echo "$bytes" > "/etc/xray/limit/quota/vless/$user"
    quota_display="${quota} GB"
else
    quota_display="Unlimited"
    bytes=0
fi

if [[ $iplimit -gt 0 ]]; then
    echo "$iplimit" > "/etc/xray/limit/ip/vless/$user"
    iplimit_display="$iplimit"
else
    iplimit_display="Unlimited"
fi

# Add user to config
sed -i '/#vless$/a\#÷ '"$user $exp_full"'\
},{"id": "'"$uuid"'","email": "'"$user"'"' /etc/xray/config.json

# Save account database
cat > /etc/xray/database/vless/$user.txt <<EOF
username: $user
uuid: $uuid
limit_ip: $iplimit
quota: $quota
expired: $exp_full
EOF

# Generate links
vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${user}"

# Restart service
systemctl restart xray.service

# Send to Telegram
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     [ TRIAL VLESS ACCOUNT ]     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Hostname : </b> <code>${domain}</code>%0A"
    TEXT+="<b>Username : </b> <code>${user}</code>%0A"
    TEXT+="<b>Expired  : </b> <code>${exp_full}</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     Account Information     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>UUID/Key : </b> <code>$uuid</code>%0A"
    TEXT+="<b>Encryption:</b> <code>none</code>%0A"
    TEXT+="<b>Path WS  : </b> <code>/vless</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Limit IP : </b> <code>$iplimit_display</code>%0A"
    TEXT+="<b>Quota    : </b> <code>$quota_display</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>        Port & Service       </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>VLESS WS TLS : 443</b>%0A"
    TEXT+="<b>VLESS WS HTTP: 80</b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Link VLESS WS TLS : </b>%0A<code>$vlesslink1</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Link VLESS WS Non-TLS : </b>%0A<code>$vlesslink2</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="${TEXT}" > /dev/null
fi

# Display results
clear
echo -e "
━━━━━━━━━━━━━━━━━━━━━━━━
 [<= TRIAL VLESS ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${user}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /vless
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
━━━━━━━━━━━━━━━━━━━━━━━━
     PORT & SERVICE
━━━━━━━━━━━━━━━━━━━━━━━━
VLESS WS TLS : 443
VLESS WS HTTP: 80
━━━━━━━━━━━━━━━━━━━━━━━━
Link VLESS WS TLS   : 
$vlesslink1
━━━━━━━━━━━━━━━━━━━━━━━━
Link VLESS WS Non-TLS : 
$vlesslink2
━━━━━━━━━━━━━━━━━━━━━━━━"

read -n 1 -s -r -p "Press any key to menu..."
menu