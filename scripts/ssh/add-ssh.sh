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

telegram_bot_token=$(cat /etc/xray/bot.key 2>/dev/null)
telegram_chatid=$(cat /etc/xray/client.id 2>/dev/null)

# Data
domain=$(cat /etc/xray/domain)
if [[ -s /root/.ip ]]; then
  ip=$(cat /root/.ip)
else
  ip=$(hostname -I | awk '{print $1}')
fi

cek_username() {
  if id "$1" &>/dev/null; then
    echo -e "\e[31m[404 Not Found]\e[0m Username '$1' sudah digunakan di sistem."
    exit 1
  elif [[ -e /etc/xray/database/ssh/$1.txt ]]; then
    echo -e "\e[31m[409 Conflict]\e[0m Username '$1' sudah ada di database."
    exit 1
  else
    echo -e "\e[32m[200 OK]\e[0m Username '$1' tersedia."
  fi
}

mkdir -p /etc/xray/limit/ip/ssh
mkdir -p /etc/xray/database/ssh

clear
echo -e "———————————————————"
echo -e " Create SSH Account "
echo -e "———————————————————"
read -p "Input Username : " username

# Validasi username: hanya huruf, angka, underscore (3-32 char). Cegah path traversal & injeksi.
if ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
  echo -e "\e[31m[400 Bad Request]\e[0m Username hanya boleh huruf, angka, underscore (3-32 karakter)!"
  exit 1
fi
cek_username "$username"
read -p "Input Password : " password

# Validasi password: tidak boleh kosong, tanpa karakter kontrol/spasi (cegah injeksi chpasswd)
if [[ -z "$password" ]] || [[ "$password" == *[$'\n\r\t:']* ]]; then
  echo -e "\e[31m[400 Bad Request]\e[0m Password tidak boleh kosong atau mengandung spasi/tab/newline/titik dua!"
  exit 1
fi
read -p "Expired (hari) : " masa

# Validasi masa hanya angka (1-3650 hari)
if ! [[ "$masa" =~ ^[0-9]+$ ]] || [[ "$masa" -lt 1 ]] || [[ "$masa" -gt 3650 ]]; then
  echo -e "\e[31m[400 Bad Request]\e[0m Expired harus angka 1-3650 hari!"
  exit 1
fi
read -p "Limit IP (angka): " limit_ip

# validasi limit_ip hanya angka
if ! [[ $limit_ip =~ ^[0-9]+$ ]]; then
  echo -e "\e[31m[400 Bad Request]\e[0m Limit IP harus berupa angka!"
  exit 1
fi

# Format expired
exp_system=$(date -d "$masa days" +%Y-%m-%d)            # untuk useradd
exp_display=$(date -d "$masa days" +"%d-%m-%Y %H:%M:%S") # untuk database & notif

# Tambah user
useradd -e "$exp_system" -M -N -s /sbin/nologin "$username" && echo "$username:$password" | chpasswd

# Simpan limit ip
echo "$limit_ip" > /etc/xray/limit/ip/ssh/$username

# Simpan database akun
cat > /etc/xray/database/ssh/$username.txt <<EOF
username: $username
password: $password
limit_ip: $limit_ip
expired: $exp_display
EOF

# Notif Telegram
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

clear
echo -e " Success Create SSH Account "
echo -e "———————————————————"
echo -e "Domain   : $domain / $ip "
echo -e "Username : $username "
echo -e "Password : $password "
echo -e "Limit IP : $limit_ip "
echo -e "———————————————————"
echo -e "Port OpenSSH : 109"
echo -e "Port WS HTTP : 80, 8888"
echo -e "Port WS TLS  : 443"
echo -e "Port BadVPN  : 7300"
echo -e "Port Openvpn : 1194 (TCP) / 2200 (UDP)"
echo -e "Port Squid   : 8080"
echo -e "Port OHP     : 3128, 8000"
echo -e "———————————————————"
echo -e "Config HTTP Custom: ${domain}:1-65535@${username}:${password}"
echo -e "———————————————————"
echo -e "Payload: GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "———————————————————"
echo -e "OVPN TCP : https://$domain:444/risqinf/openvpn/tcp.ovpn"
echo -e "OVPN UDP : https://$domain:444/risqinf/openvpn/udp.ovpn"
echo -e "———————————————————"
echo -e "Expired  : $exp_display"
echo -e "———————————————————"
echo ""
read -n 1 -s -r -p "Press any key to return to menu..."
menu