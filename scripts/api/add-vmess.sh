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

# Data
domain=$(cat /etc/xray/domain 2>/dev/null)
telegram_bot_token=$(cat /etc/xray/bot.key 2>/dev/null)
telegram_chatid=$(cat /etc/xray/client.id 2>/dev/null)

# Cek apakah kosong
if [[ -z "$domain" ]]; then
    domain="not set"
fi

if [[ -z "$telegram_bot_token" ]]; then
    telegram_bot_token="not set"
fi

if [[ -z "$telegram_chatid" ]]; then
    telegram_chatid="not set"
fi

# Function to convert bytes to human readable format
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

# Function to check if UUID already exists
check_uuid_exists() {
    local uuid="$1"
    
    # Extract all UUIDs from config.json using more precise pattern matching
    local existing_uuids=$(grep -o '"id":[[:space:]]*"[^"]*"' /etc/xray/config.json 2>/dev/null | cut -d'"' -f4)
    
    # Check if the exact UUID already exists
    while IFS= read -r existing_uuid; do
        if [[ "$existing_uuid" == "$uuid" ]]; then
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
            ;;
        "quota")
            [[ "$input" =~ ^[0-9]+$ ]] && return 0
            ;;
        "iplimit")
            [[ "$input" =~ ^[0-9]+$ ]] && return 0
            ;;
        "duration")
            [[ "$input" =~ ^[0-9]+[mhd]$ ]] && return 0
            ;;
        "uuid")
            [[ -n "$input" ]] && return 0
            ;;
    esac
    return 1
}

# Function to create VMESS account
create_vmess_account() {
    local user="$1"
    local uuid="$2"
    local quota="$3"
    local iplimit="$4"
    local duration="$5"
    
    # Validasi input
    if [[ -z "$user" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username is required\"}"
        return 1
    fi

    if [[ -z "$uuid" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"UUID is required\"}"
        return 1
    fi

    if [[ -z "$quota" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Quota is required\"}"
        return 1
    fi

    if [[ -z "$iplimit" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"IP limit is required\"}"
        return 1
    fi

    if [[ -z "$duration" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Duration is required\"}"
        return 1
    fi

    # Validate individual inputs
    if ! validate_input "$user" "username"; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username can only contain letters, numbers and underscores\"}"
        return 1
    fi

    if ! validate_input "$quota" "quota"; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Quota must be a positive number\"}"
        return 1
    fi

    if ! validate_input "$iplimit" "iplimit"; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"IP limit must be a positive number\"}"
        return 1
    fi

    if ! validate_input "$duration" "duration"; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Duration format must be like: 30m, 2h, 1d\"}"
        return 1
    fi

    # Check if user exists
    user_exists=$(grep -w "\"$user\"" /etc/xray/config.json 2>/dev/null | wc -l)
    if [[ $user_exists -gt 0 ]]; then
        echo "{\"status\": \"false\", \"code\": 409, \"message\": \"A client with this username already exists\"}"
        return 1
    fi

    # Check if UUID exists
    if ! check_uuid_exists "$uuid"; then
        echo "{\"status\": \"false\", \"code\": 409, \"message\": \"UUID '$uuid' is already used by another user\"}"
        return 1
    fi

    # Create necessary directories if they don't exist
    mkdir -p /etc/xray/limit/quota/vmess
    mkdir -p /etc/xray/limit/ip/vmess
    mkdir -p /etc/xray/database/vmess
    mkdir -p /etc/xray/usage/quota/vmess

    # Calculate expiration
    case "$duration" in
        *m) seconds=$(( ${duration%m} * 60 )) ;;
        *h) seconds=$(( ${duration%h} * 3600 )) ;;
        *d) seconds=$(( ${duration%d} * 86400 )) ;;
    esac

    exp=$(date -d "+$seconds seconds" +"%Y-%m-%d-%H-%M-%S")
    exp_full=$exp
    exp_display=$(date -d "+$seconds seconds" +"%d-%m-%Y %H:%M:%S")

    # Set quota and IP limit
    if [[ $quota -gt 0 ]]; then
        bytes=$((quota * 1024 * 1024 * 1024))
        echo "$bytes" > "/etc/xray/limit/quota/vmess/$user"
        quota_display="${quota} GB"
        quota_human="$quota_display"
    else
        quota_display="Unlimited"
        quota_human="Unlimited"
        bytes=0
    fi

    if [[ $iplimit -gt 0 ]]; then
        echo "$iplimit" > "/etc/xray/limit/ip/vmess/$user"
        iplimit_display="$iplimit"
    else
        iplimit_display="Unlimited"
    fi

    # Add user to config
    if ! sed -i '/#vmess$/a\### '"$user $exp_full"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json 2>/dev/null; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to update Xray configuration\"}"
        return 1
    fi

    # Save account database
    cat > /etc/xray/database/vmess/$user.txt <<EOF
username: $user
uuid: $uuid
limit_ip: $iplimit
quota: $quota
expired: $exp_full
EOF

    # Generate VMESS links
    local acs=$(cat<<EOF
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
EOF
)

    local ask=$(cat<<EOF
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
EOF
)

    vmesslink1="vmess://$(echo "$acs" | base64 -w 0 2>/dev/null)"
    vmesslink2="vmess://$(echo "$ask" | base64 -w 0 2>/dev/null)"

    # Validate base64 encoding
    if [[ -z "$vmesslink1" || -z "$vmesslink2" ]]; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to generate VMESS links\"}"
        return 1
    fi

    # Restart service
    if ! systemctl restart xray.service 2>/dev/null; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to restart Xray service\"}"
        return 1
    fi

    # Send to Telegram if configured
    local telegram_sent="false"
    if [[ "$telegram_bot_token" != "not set" && "$telegram_chatid" != "not set" ]]; then
        TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>     [ VMESS ACCOUNT ]     </b>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>Hostname : </b> <code>${domain}</code>%0A"
        TEXT+="<b>Username : </b> <code>${user}</code>%0A"
        TEXT+="<b>Expired  : </b> <code>${exp_display}</code>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>     Account Information     </b>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>UUID/Key : </b> <code>$uuid</code>%0A"
        TEXT+="<b>Encryption:</b> <code>none</code>%0A"
        TEXT+="<b>Path WS  : </b> <code>/multipath</code>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>Limit IP : </b> <code>$iplimit_display</code>%0A"
        TEXT+="<b>Quota    : </b> <code>$quota_display</code>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>        Port & Service       </b>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>VMESS WS TLS : 443</b>%0A"
        TEXT+="<b>VMESS WS HTTP: 80</b>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>Link VMESS WS TLS : </b>%0A<code>$vmesslink1</code>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>Link VMESS WS Non-TLS : </b>%0A<code>$vmesslink2</code>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

        if curl -s -X POST "https://api.telegram.org/bot${telegram_bot_token}/sendMessage" \
            -d chat_id="${telegram_chatid}" \
            -d parse_mode="HTML" \
            -d text="${TEXT}" > /dev/null 2>&1; then
            telegram_sent="true"
        fi
    fi

    # Response data
    response=$(cat <<EOF
{
    "status": "true",
    "code": 201,
    "message": "VMESS account created successfully",
    "data": {
        "username": "$user",
        "uuid": "$uuid",
        "domain": "$domain",
        "expired_system": "$exp_full",
        "expired_display": "$exp_display",
        "limits": {
            "ip": $iplimit,
            "ip_display": "$iplimit_display",
            "quota": $quota,
            "quota_display": "$quota_display",
            "quota_bytes": $bytes,
            "quota_human": "$quota_human"
        },
        "duration": "$duration",
        "ports": {
            "vmess_ws_tls": 443,
            "vmess_ws_http": 80
        },
        "configuration": {
            "encryption": "none",
            "alter_id": 0,
            "path_ws": "/multipath",
            "sni": "$domain"
        },
        "links": {
            "vmess_ws_tls": "$vmesslink1",
            "vmess_ws_http": "$vmesslink2"
        },
        "telegram_notification": "$telegram_sent"
    }
}
EOF
    )

    echo "$response"
    return 0
}

# Main execution
if [[ "$1" == "--interactive" ]] || [[ "$1" == "-i" ]]; then
    # Mode interaktif
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m  ADD VMESS ACCOUNT     \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    
    read -rp "Username: " -e user
    
    # Validate username
    if ! validate_input "$user" "username"; then
        echo "Username can only contain letters, numbers and underscores"
        exit 1
    fi
    
    # Check if user exists
    user_exists=$(grep -w "\"$user\"" /etc/xray/config.json 2>/dev/null | wc -l)
    if [[ $user_exists -gt 0 ]]; then
        echo "A client with this username already exists. Please choose another name."
        exit 1
    fi

    echo ""
    echo "Enter custom UUID (press Enter for auto-generate):"
    read -rp "Custom UUID: " custom_uuid

    if [[ -z "$custom_uuid" ]]; then
        # Generate random UUID (standard format)
        uuid=$(cat /proc/sys/kernel/random/uuid)
        echo "Using auto-generated UUID: $uuid"
    else
        # Validate custom UUID
        if [[ -z "$custom_uuid" ]]; then
            uuid=$(cat /proc/sys/kernel/random/uuid)
            echo "Using auto-generated UUID: $uuid"
        elif ! check_uuid_exists "$custom_uuid"; then
            echo "UUID '$custom_uuid' is already used by another user. Please use a different UUID."
            exit 1
        else
            uuid="$custom_uuid"
            echo "Using custom UUID: $uuid"
        fi
    fi

    read -n 1 -s -r -p "Press any key to continue..."
    clear

    # Get quota
    until false; do
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        echo -e "\e[0;41;36m  ADD VMESS ACCOUNT     \e[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        echo "Username: $user"
        echo "UUID: $uuid"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        
        read -rp "Quota (GB): " quota
        if [[ -z "$quota" ]]; then
            echo "Quota cannot be empty"
            continue
        fi
        
        if validate_input "$quota" "quota"; then
            break
        fi
        echo "Quota must be a positive number"
    done

    # Get IP limit
    until false; do
        clear
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        echo -e "\e[0;41;36m  ADD VMESS ACCOUNT     \e[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        echo "Username: $user"
        echo "UUID: $uuid"
        echo "Quota: $quota GB"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        
        read -rp "Max IP login: " iplimit
        if [[ -z "$iplimit" ]]; then
            echo "IP limit cannot be empty"
            continue
        fi
        
        if validate_input "$iplimit" "iplimit"; then
            break
        fi
        echo "IP limit must be a positive number"
    done

    # Get duration
    until false; do
        clear
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        echo -e "\e[0;41;36m  ADD VMESS ACCOUNT     \e[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        echo "Username: $user"
        echo "UUID: $uuid"
        echo "Quota: $quota GB"
        echo "IP Limit: $iplimit"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        
        read -rp "Expired (ex: 1m / 30m / 2h / 1d): " duration
        if [[ -z "$duration" ]]; then
            echo "Duration cannot be empty"
            continue
        fi
        
        if validate_input "$duration" "duration"; then
            break
        fi
        echo "Duration format must be like: 30m, 2h, 1d"
    done

    create_vmess_account "$user" "$uuid" "$quota" "$iplimit" "$duration"
else
    # Mode POST - membaca input JSON dari stdin
    input_data=$(cat)
    user=$(echo "$input_data" | jq -r '.username' 2>/dev/null)
    uuid=$(echo "$input_data" | jq -r '.uuid' 2>/dev/null)
    quota=$(echo "$input_data" | jq -r '.quota' 2>/dev/null)
    iplimit=$(echo "$input_data" | jq -r '.iplimit' 2>/dev/null)
    duration=$(echo "$input_data" | jq -r '.duration' 2>/dev/null)
    
    # Jika UUID tidak disediakan, generate otomatis
    if [[ -z "$uuid" || "$uuid" == "null" ]]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    
    if [[ -z "$user" || "$user" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing username field\"}"
        exit 1
    fi
    
    if [[ -z "$quota" || "$quota" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing quota field in JSON input\"}"
        exit 1
    fi
    
    if [[ -z "$iplimit" || "$iplimit" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing iplimit field in JSON input\"}"
        exit 1
    fi
    
    if [[ -z "$duration" || "$duration" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing duration field in JSON input\"}"
        exit 1
    fi
    
    # Eksekusi pembuatan account VMESS
    create_vmess_account "$user" "$uuid" "$quota" "$iplimit" "$duration"
fi