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
telegram_bot_token=$(cat /etc/xray/bot.key 2>/dev/null)
telegram_chatid=$(cat /etc/xray/client.id 2>/dev/null)
domain=$(cat /etc/xray/domain 2>/dev/null)

if [[ -s /root/.ip ]]; then
  ip=$(cat /root/.ip)
else
  ip=$(hostname -I | awk '{print $1}')
fi

# Cek apakah kosong
if [[ -z "$telegram_bot_token" ]]; then
    telegram_bot_token="not set"
fi

if [[ -z "$telegram_chatid" ]]; then
    telegram_chatid="not set"
fi

if [[ -z "$domain" ]]; then
    domain="not set"
fi

mkdir -p /etc/xray/limit/ip/ssh
mkdir -p /etc/xray/database/ssh

# Fungsi untuk generate random username & password
generate_random() {
  length=$((RANDOM % 7 + 8)) # 8–14 chars
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c $length
}

# Fungsi untuk membuat trial account
create_trial_account() {
    local duration="$1"
    local limit_ip="$2"
    
    # Validasi input
    if [[ -z "$duration" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Duration is required\"}"
        return 1
    fi

    if [[ -z "$limit_ip" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Limit IP is required\"}"
        return 1
    fi

    # Validasi limit_ip hanya angka
    if ! [[ $limit_ip =~ ^[0-9]+$ ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Limit IP must be a number\"}"
        return 1
    fi

    # Generate random username & password
    username="trial$(generate_random)"
    password=$(generate_random)

    # Hitung expired
    unit="${duration: -1}"
    value="${duration%?}"

    case $unit in
        m) 
            exp_system=$(date -d "+$value minutes" +%Y-%m-%d)
            exp_display=$(date -d "+$value minutes" +"%d-%m-%Y %H:%M:%S")
            ;;
        h) 
            exp_system=$(date -d "+$value hours" +%Y-%m-%d)
            exp_display=$(date -d "+$value hours" +"%d-%m-%Y %H:%M:%S")
            ;;
        d) 
            exp_system=$(date -d "+$value days" +%Y-%m-%d)
            exp_display=$(date -d "+$value days" +"%d-%m-%Y %H:%M:%S")
            ;;
        *) 
            echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid duration format. Use m (minutes), h (hours), or d (days)\"}"
            return 1
            ;;
    esac

    # Tambah user
    if ! useradd -e "$exp_system" -M -N -s /sbin/nologin "$username" 2>/dev/null; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to create system user\"}"
        return 1
    fi

    if ! echo "$username:$password" | chpasswd 2>/dev/null; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to set password\"}"
        userdel --force "$username" 2>/dev/null
        return 1
    fi

    # Simpan limit ip
    echo "$limit_ip" > /etc/xray/limit/ip/ssh/$username

    # Simpan database akun
    cat > /etc/xray/database/ssh/$username.txt <<EOF
username: $username
password: $password
limit_ip: $limit_ip
expired: $exp_display
EOF

    # Kirim notifikasi Telegram jika token dan chat ID tersedia
    if [[ "$telegram_bot_token" != "not set" && "$telegram_chatid" != "not set" ]]; then
        TEKS=$(cat <<EOF
<b>Success Create SSH Trial Account</b>
<b>———————————————————</b>
<b>Domain:</b> <code>$domain</code> / <code>$ip</code>
<b>Username:</b> <code>$username</code>
<b>Password:</b> <code>$password</code>
<b>Limit IP:</b> <code>$limit_ip</code>
<b>———————————————————</b>
<b>Port OpenSSH:</b> <code>443</code>
<b>Port WS HTTP:</b> <code>80, 2082</code>
<b>Port WS TLS:</b> <code>443</code>
<b>Port BadVPN:</b> <code>7300</code>
<b>———————————————————</b>
<b>Config HTTP Custom:</b> <code>${domain}:1-65535@${username}:${password}</code>
<b>———————————————————</b>
<b>Payload:</b> <code>GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]</code>
<b>———————————————————</b>
<b>Expired:</b> <code>$exp_display</code>
<b>———————————————————</b>
EOF
        )

        curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
            -d "chat_id=$telegram_chatid" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=$TEKS" > /dev/null
    fi

    # Response data
    response=$(cat <<EOF
{
    "status": "true",
    "code": 201,
    "message": "SSH Trial account created successfully",
    "data": {
        "username": "$username",
        "password": "$password",
        "domain": "$domain",
        "ip": "$ip",
        "limit_ip": "$limit_ip",
        "duration": "$duration",
        "expired_system": "$exp_system",
        "expired_display": "$exp_display",
        "ports": {
            "ssh": "443",
            "ws_http": "80, 2082",
            "ws_tls": "443",
            "badvpn": "7300"
        },
        "config": "${domain}:1-65535@${username}:${password}",
        "payload": "GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]",
        "telegram_notification": "$([[ "$telegram_bot_token" != "not set" && "$telegram_chatid" != "not set" ]] && echo "sent" || echo "disabled")"
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
    echo -e "———————————————————"
    echo -e " Create SSH Trial Account "
    echo -e "———————————————————"
    read -p "Expired (m/h/d): " duration
    read -p "Limit IP (angka): " limit_ip

    create_trial_account "$duration" "$limit_ip"
else
    # Mode POST - membaca input JSON dari stdin
    input_data=$(cat)
    duration=$(echo "$input_data" | jq -r '.duration' 2>/dev/null)
    limit_ip=$(echo "$input_data" | jq -r '.limit_ip' 2>/dev/null)
    
    if [[ -z "$duration" || "$duration" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing duration field\"}"
        exit 1
    fi
    
    if [[ -z "$limit_ip" || "$limit_ip" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing limit_ip field in JSON input\"}"
        exit 1
    fi
    
    # Eksekusi pembuatan trial account
    create_trial_account "$duration" "$limit_ip"
fi