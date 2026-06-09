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

mkdir -p /etc/xray/limit/ip/ssh
mkdir -p /etc/xray/database/ssh

# Generate random username & password
generate_random() {
  length=$((RANDOM % 7 + 8)) # 8–14 chars
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c $length
}
username="trial$(generate_random)"
password=$(generate_random)

clear
echo -e "———————————————————"
echo -e " Create SSH Trial Account "
echo -e "———————————————————"
read -p "Expired (m/h/d): " duration
read -p "Limit IP (angka): " limit_ip

# validasi limit_ip hanya angka
if ! [[ $limit_ip =~ ^[0-9]+$ ]]; then
  echo -e "\e[31m[400 Bad Request]\e[0m Limit IP harus berupa angka!"
  exit 1
fi

# validasi format durasi: angka diikuti m/h/d (mis. 30m, 2h, 1d)
if ! [[ "$duration" =~ ^[0-9]+[mhd]$ ]]; then
  echo -e "\e[31m[400 Bad Request]\e[0m Format salah! gunakan angka diikuti m/h/d (mis. 30m, 2h, 1d)"
  exit 1
fi

# Hitung expired
unit="${duration: -1}"
value="${duration%?}"

case $unit in
  m) exp_system=$(date -d "+$value minutes" +%Y-%m-%d)
     exp_display=$(date -d "+$value minutes" +"%d-%m-%Y %H:%M:%S") ;;
  h) exp_system=$(date -d "+$value hours" +%Y-%m-%d)
     exp_display=$(date -d "+$value hours" +"%d-%m-%Y %H:%M:%S") ;;
  d) exp_system=$(date -d "+$value days" +%Y-%m-%d)
     exp_display=$(date -d "+$value days" +"%d-%m-%Y %H:%M:%S") ;;
  *) echo -e "\e[31m[400 Bad Request]\e[0m Format salah! gunakan m/h/d"; exit 1 ;;
esac

# Tambah user
useradd -e "$exp_system" -M -N -s /sbin/nologin "$username"
echo "$username:$password" | chpasswd

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
echo -e " Success Create SSH Trial Account "
echo -e "———————————————————"
echo -e "Domain   : $domain / $ip "
echo -e "Username : $username "
echo -e "Password : $password "
echo -e "Limit IP : $limit_ip "
echo -e "———————————————————"
echo -e "Port OpenSSH : 443"
echo -e "Port WS HTTP : 80, 2082"
echo -e "Port WS TLS  : 443"
echo -e "Port BadVPN  : 7300"
echo -e "Port Openvpn : 1194 (TCP) / 2200 (UDP)"
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