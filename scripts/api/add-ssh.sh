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

# Fungsi untuk mengecek apakah username sudah ada
cek_username() {
  if id "$1" &>/dev/null; then
    echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username '$1' is already in use in system\"}"
    exit 1
  elif [[ -e /etc/xray/database/ssh/$1.txt ]]; then
    echo "{\"status\": \"false\", \"code\": 409, \"message\": \"Username '$1' already exists in database\"}"
    exit 1
  else
    clear
  fi
}

# Membuat direktori jika belum ada
mkdir -p /etc/xray/limit/ip/ssh
mkdir -p /etc/xray/database/ssh

# Membaca input JSON dari API
input_data=$(cat)

# Ekstrak data dari JSON
username=$(echo "$input_data" | jq -r '.username')
password=$(echo "$input_data" | jq -r '.password')
masa=$(echo "$input_data" | jq -r '.expired')
limit_ip=$(echo "$input_data" | jq -r '.limit_ip')

# Validasi input
if [[ -z "$username" || "$username" == "null" || -z "$password" || "$password" == "null" || -z "$masa" || "$masa" == "null" ]]; then
    echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing required fields: username, password, expired\"}"
    exit 1
fi

# Validasi username: huruf, angka, underscore (3-32 char). Cegah path traversal & injeksi argumen.
if ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
    echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username can only contain letters, numbers and underscores (3-32 chars)\"}"
    exit 1
fi

# Validasi password: tanpa karakter kontrol/spasi/titik dua (cegah injeksi chpasswd)
if [[ "$password" == *[$'\n\r\t:']* ]] || [[ "$password" == *" "* ]]; then
    echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Password must not contain spaces, tabs, newlines or colons\"}"
    exit 1
fi

# Validasi masa: angka 1-3650 hari
if ! [[ "$masa" =~ ^[0-9]+$ ]] || [[ "$masa" -lt 1 ]] || [[ "$masa" -gt 3650 ]]; then
    echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Expired must be a number between 1 and 3650 days\"}"
    exit 1
fi

# Validasi limit_ip hanya angka
if ! [[ $limit_ip =~ ^[0-9]+$ ]]; then
    echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Limit IP must be a number\"}"
    exit 1
fi

# Cek ketersediaan username
cek_username "$username"

# Hitung tanggal kedaluwarsa
exp_system=$(date +%F -d "$masa days")
exp_display=$(date -d "$masa days" +"%d-%m-%Y %H:%M:%S")

# Buat akun SSH
useradd -e "$exp_system" -M -N -s /sbin/nologin "$username" && echo "$username:$password" | chpasswd

# Simpan limit ip
echo "$limit_ip" > "/etc/xray/limit/ip/ssh/$username"

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
<b>Success Create SSH Account</b>
<b>———————————————————</b>
<b>Domain:</b> <code>$domain</code> / <code>$ip</code>
<b>Username:</b> <code>$username</code>
<b>Password:</b> <code>$password</code>
<b>Limit IP:</b> <code>$limit_ip</code>
<b>———————————————————</b>
<b>Port OpenSSH:</b> <code>109</code>
<b>Port WS HTTP:</b> <code>80, 8888</code>
<b>Port WS TLS:</b> <code>443</code>
<b>Port BadVPN:</b> <code>7300</code>
<b>Port Openvpn:</b> <code>1194 (TCP), 2200 (UDP)</code>

<b>Port Squid:</b> <code>8080</code>
<b>Port OHP:</b> <code>3128, 8000</code>

<b>———————————————————</b>
<b>Config HTTP Custom:</b> <code>${domain}:1-65535@${username}:${password}</code>
<b>———————————————————</b>
<b>Payload:</b> <code>GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]</code>
<b>———————————————————</b>
<b>OVPN TCP:</b> <code>https://$domain:444/risqinf/openvpn/tcp.ovpn</code>
<b>OVPN UDP:</b> <code>https://$domain:444/risqinf/openvpn/udp.ovpn</code>
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
    "message": "SSH Account created successfully",
    "data": {
        "username": "$username",
        "password": "$password",
        "domain": "$domain",
        "ip": "$ip",
        "limit_ip": "$limit_ip",
        "expired_system": "$exp_system",
        "expired_display": "$exp_display",
        "ports": {
            "ssh": "109",
            "ws_http": "80, 8888",
            "ws_tls": "443",
            "badvpn": "7300",
            "openvpn_tcp": "1194",
            "openvpn_udp": "2200",
            "squid": "8080",
            "ohp": "3128, 8000"
        },
        "config": "${domain}:1-65535@${username}:${password}",
        "payload": "GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]",
        "ovpn_tcp_url": "https://$domain:444/risqinf/openvpn/tcp.ovpn",
        "ovpn_udp_url": "https://$domain:444/risqinf/openvpn/udp.ovpn",
        "telegram": {
            "bot_token_set": "$([[ "$telegram_bot_token" != "not set" ]] && echo "true" || echo "false")",
            "chat_id_set": "$([[ "$telegram_chatid" != "not set" ]] && echo "true" || echo "false")"
        }
    }
}
EOF
)

# Outputkan respons dalam format JSON
clear
echo -e "$response"