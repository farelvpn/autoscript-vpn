#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# TRIAL VMESS ACCOUNT CREATOR (JSON API)
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

# Function to validate input
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "duration")
            [[ "$input" =~ ^[0-9]+[mhd]$ ]] && return 0
            ;;
    esac
    return 1
}

# Function to generate random username
generate_random_username() {
    local prefix="${1:-trial}"
    local random_number=$((RANDOM % 10000))
    local username="${prefix}${random_number}"
    
    # Check if user exists and generate new if needed
    while [[ $(grep -w "\"$username\"" /etc/xray/config.json 2>/dev/null | wc -l) -gt 0 ]] || 
          [[ -f "/etc/xray/database/vmess/${username}.txt" ]]; do
        random_number=$((RANDOM % 10000))
        username="${prefix}${random_number}"
    done
    
    echo "$username"
}

# Function to create trial VMESS account
create_trial_vmess_account() {
    local duration="$1"
    local custom_prefix="${2:-trial}"
    
    # Validasi input
    if [[ -z "$duration" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Duration is required\"}"
        return 1
    fi

    if ! validate_input "$duration" "duration"; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Duration format must be like: 30m, 2h, 1d\"}"
        return 1
    fi

    # Create necessary directories if they don't exist
    mkdir -p /etc/xray/limit/quota/vmess
    mkdir -p /etc/xray/limit/ip/vmess
    mkdir -p /etc/xray/database/vmess
    mkdir -p /etc/xray/usage/quota/vmess

    # Generate random username
    user=$(generate_random_username "$custom_prefix")

    # Generate random UUID (standard format)
    uuid=$(cat /proc/sys/kernel/random/uuid)

    # Set default values for trial
    local quota=10  # 10 GB
    local iplimit=2 # 2 IP limit

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
        TEXT+="<b>     [ TRIAL VMESS ACCOUNT ]     </b>%0A"
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
    "message": "Trial VMESS account created successfully",
    "data": {
        "username": "$user",
        "uuid": "$uuid",
        "domain": "$domain",
        "duration": "$duration",
        "expired_system": "$exp_full",
        "expired_display": "$exp_display",
        "limits": {
            "quota": $quota,
            "quota_display": "$quota_display",
            "quota_bytes": $bytes,
            "quota_human": "$quota_human",
            "ip_limit": $iplimit,
            "ip_limit_display": "$iplimit_display"
        },
        "configuration": {
            "encryption": "none",
            "alter_id": 0,
            "path_ws": "/multipath",
            "sni": "$domain",
            "ports": {
                "vmess_ws_tls": 443,
                "vmess_ws_http": 80
            }
        },
        "links": {
            "vmess_ws_tls": "$vmesslink1",
            "vmess_ws_http": "$vmesslink2"
        },
        "account_type": "trial",
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
    echo -e "\e[0;41;36m  CREATE TRIAL VMESS ACCOUNT     \e[0m"
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
        echo "Duration format must be like: 30m, 2h, 1d"
        read -n 1 -s -r -p "Press any key to continue..."
    done

    # Get custom prefix (optional)
    read -rp "Username prefix (default: trial): " custom_prefix
    if [[ -z "$custom_prefix" ]]; then
        custom_prefix="trial"
    fi

    create_trial_vmess_account "$duration" "$custom_prefix"
else
    # Mode POST - membaca input JSON dari stdin
    input_data=$(cat)
    duration=$(echo "$input_data" | jq -r '.duration' 2>/dev/null)
    custom_prefix=$(echo "$input_data" | jq -r '.prefix' 2>/dev/null)
    
    if [[ -z "$duration" || "$duration" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing duration field\"}"
        exit 1
    fi
    
    # Jika prefix tidak disediakan, gunakan default
    if [[ -z "$custom_prefix" || "$custom_prefix" == "null" ]]; then
        custom_prefix="trial"
    fi
    
    # Eksekusi pembuatan trial account VMESS
    create_trial_vmess_account "$duration" "$custom_prefix"
fi