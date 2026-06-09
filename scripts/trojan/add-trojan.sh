#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Author: risqinf
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
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

# Function to check if UUID already exists (STRICT TEXT MATCHING)
check_uuid_exists() {
    local uuid="$1"
    
    # Extract all UUIDs from config.json using more precise pattern matching
    local existing_uuids=$(grep -o '"id":[[:space:]]*"[^"]*"' /etc/xray/config.json | cut -d'"' -f4)
    
    # Check if the exact UUID already exists
    while IFS= read -r existing_uuid; do
        if [[ "$existing_uuid" == "$uuid" ]]; then
            echo "UUID '$uuid' is already used by another user. Please use a different UUID."
            return 1
        fi
    done <<< "$existing_uuids"
    
    return 0
}

# Function to validate input
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "username")
            [[ "$input" =~ ^[a-zA-Z0-9_]+$ ]] && return 0
            echo "Username can only contain letters, numbers and underscores"
            ;;
        "quota")
            [[ "$input" =~ ^[0-9]+$ ]] && return 0
            echo "Quota must be a positive number"
            ;;
        "iplimit")
            [[ "$input" =~ ^[0-9]+$ ]] && return 0
            echo "IP limit must be a positive number"
            ;;
        "duration")
            [[ "$input" =~ ^[0-9]+[mhd]$ ]] && return 0
            echo "Duration format must be like: 30m, 2h, 1d"
            ;;
        "uuid")
            [[ -n "$input" ]] && return 0
            echo "UUID cannot be empty"
            ;;
    esac
    return 1
}

# Create necessary directories if they don't exist
mkdir -p /etc/xray/limit/quota/trojan
mkdir -p /etc/xray/limit/ip/trojan
mkdir -p /etc/xray/database/trojan
mkdir -p /etc/xray/usage/quota/trojan

# Get username
until false; do
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m  ADD TROJAN ACCOUNT     \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    
    read -rp "Username: " -e user
    
    # Validate username
    if ! validate_input "$user" "username"; then
        read -n 1 -s -r -p "Press any key to continue..."
        continue
    fi
    
    # Check if user exists
    user_exists=$(grep -w "\"$user\"" /etc/xray/config.json | wc -l)
    if [[ $user_exists -gt 0 ]]; then
        echo "A client with this username already exists. Please choose another name."
        read -n 1 -s -r -p "Press any key to continue..."
        continue
    fi
    
    break
done

# Get custom UUID or generate random
echo ""
echo "Enter custom UUID (press Enter for auto-generate):"
read -rp "Custom UUID: " custom_uuid

if [[ -z "$custom_uuid" ]]; then
    # Generate random UUID (standard format)
    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo "Using auto-generated UUID: $uuid"
else
    # Validate custom UUID (any format is allowed except empty)
    until validate_input "$custom_uuid" "uuid" && check_uuid_exists "$custom_uuid"; do
        read -rp "Custom UUID: " custom_uuid
        if [[ -z "$custom_uuid" ]]; then
            uuid=$(cat /proc/sys/kernel/random/uuid)
            echo "Using auto-generated UUID: $uuid"
            break
        fi
    done
    
    if [[ -n "$custom_uuid" ]]; then
        uuid="$custom_uuid"
        echo "Using custom UUID: $uuid"
    fi
fi

read -n 1 -s -r -p "Press any key to continue..."
clear

# Get quota
until false; do
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m  ADD TROJAN ACCOUNT     \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo "Username: $user"
    echo "UUID: $uuid"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    
    read -rp "Quota (GB): " quota
    if [[ -z "$quota" ]]; then
        echo "Quota cannot be empty"
        read -n 1 -s -r -p "Press any key to continue..."
        clear
        continue
    fi
    
    if validate_input "$quota" "quota"; then
        break
    fi
    read -n 1 -s -r -p "Press any key to continue..."
    clear
done

# Get IP limit
until false; do
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m  ADD TROJAN ACCOUNT     \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo "Username: $user"
    echo "UUID: $uuid"
    echo "Quota: $quota GB"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    
    read -rp "Max IP login: " iplimit
    if [[ -z "$iplimit" ]]; then
        echo "IP limit cannot be empty"
        read -n 1 -s -r -p "Press any key to continue..."
        continue
    fi
    
    if validate_input "$iplimit" "iplimit"; then
        break
    fi
    read -n 1 -s -r -p "Press any key to continue..."
done

# Get duration
until false; do
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m  ADD TROJAN ACCOUNT     \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo "Username: $user"
    echo "UUID: $uuid"
    echo "Quota: $quota GB"
    echo "IP Limit: $iplimit"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    
    read -rp "Expired (ex: 1m / 30m / 2h / 1d): " duration
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
    echo "$bytes" > "/etc/xray/limit/quota/trojan/$user"
    quota_display="${quota} GB"
else
    quota_display="Unlimited"
    bytes=0
fi

if [[ $iplimit -gt 0 ]]; then
    echo "$iplimit" > "/etc/xray/limit/ip/trojan/$user"
    iplimit_display="$iplimit"
else
    iplimit_display="Unlimited"
fi

# Add user to config
sed -i '/#trojan$/a\#@ '"$user $exp_full"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

# Save account database
cat > /etc/xray/database/trojan/$user.txt <<EOF
username: $user
uuid: $uuid
limit_ip: $iplimit
quota: $quota
expired: $exp_full
EOF

# Generate links
trojanlink1="trojan://${uuid}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

# Restart service
systemctl restart xray.service

# Send to Telegram
BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     [ TROJAN ACCOUNT ]     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Hostname : </b> <code>${domain}</code>%0A"
    TEXT+="<b>Username : </b> <code>${user}</code>%0A"
    TEXT+="<b>Expired  : </b> <code>${exp_full}</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>     Account Information     </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>UUID/Key : </b> <code>$uuid</code>%0A"
    TEXT+="<b>Encryption:</b> <code>none</code>%0A"
    TEXT+="<b>Path WS  : </b> <code>/trojan</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Limit IP : </b> <code>$iplimit_display</code>%0A"
    TEXT+="<b>Quota    : </b> <code>$quota_display</code>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>        Port & Service       </b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>TROJAN WS TLS : 443</b>%0A"
    TEXT+="<b>TROJAN WS HTTP: 80</b>%0A"
    TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
    TEXT+="<b>Link TROJAN WS TLS : </b>%0A<code>$trojanlink1</code>%0A"
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
 [<= TROJAN ACCOUNT =>]
━━━━━━━━━━━━━━━━━━━━━━━━
Hostname    : ${domain}
Username    : ${user}
Expired     : ${exp_full}
━━━━━━━━━━━━━━━━━━━━━━━━
   ACCOUNT INFORMATION
━━━━━━━━━━━━━━━━━━━━━━━━
UUID/Key    : $uuid
Encryption  : none
Path WS     : /trojan
━━━━━━━━━━━━━━━━━━━━━━━━
Limit IP    : ${iplimit_display}
Limit Quota : $quota_display
━━━━━━━━━━━━━━━━━━━━━━━━
     PORT & SERVICE
━━━━━━━━━━━━━━━━━━━━━━━━
TROJAN WS TLS : 443
TROJAN WS HTTP: 80
━━━━━━━━━━━━━━━━━━━━━━━━
Link TROJAN WS TLS   : 
$trojanlink1
━━━━━━━━━━━━━━━━━━━━━━━━"

read -n 1 -s -r -p "Press any key to menu..."
menu