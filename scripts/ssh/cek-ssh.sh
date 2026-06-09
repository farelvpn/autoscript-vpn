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

database_tmp="/root/.system"
DB_DIR="/etc/xray/database/ssh"

# File konfigurasi Telegram
bot_token_file="/etc/xray/bot.key"
chat_id_file="/etc/xray/client.id"

# Pastikan file sementara bersih
> "$database_tmp"

# Fungsi kirim notifikasi Telegram (background)
send_telegram() {
    local message="$1"
    if [[ -f "$bot_token_file" && -f "$chat_id_file" ]]; then
        local bot_token=$(cat "$bot_token_file" | tr -d ' \t\n\r')
        local chat_id=$(cat "$chat_id_file" | tr -d ' \t\n\r')
        if [[ -n "$bot_token" && -n "$chat_id" ]]; then
            curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
                -d "chat_id=$chat_id" \
                -d "text=$message" \
                -d "parse_mode=Markdown" \
                -d "disable_web_page_preview=true" \
                >/dev/null 2>&1
        fi
    fi
}

mesinssh() {
    if [ -e "/var/log/auth.log" ]; then
        LOG="/var/log/auth.log"
    elif [ -e "/var/log/secure" ]; then
        LOG="/var/log/secure"
    fi

    # Dropbear
    data=( $(ps aux | grep -i dropbear | awk '{print $2}') )
    echo "----------=[ Dropbear User Login ]=-----------"
    echo "ID  |  Username  |  IP Address"
    echo "----------------------------------------------"
    grep -i dropbear "$LOG" | grep -i "Password auth succeeded" > /tmp/login-db.txt
    for PID in "${data[@]}"; do
        grep "dropbear\[$PID\]" /tmp/login-db.txt > /tmp/login-db-pid.txt
        NUM=$(wc -l < /tmp/login-db-pid.txt)
        USER=$(awk '{print $10}' /tmp/login-db-pid.txt)
        IP=$(awk '{print $12}' /tmp/login-db-pid.txt)
        if [ "$NUM" -eq 1 ]; then
            echo "$PID - $USER - $IP"
        fi
    done

    # OpenSSH
    echo " "
    echo "----------=[ OpenSSH User Login ]=------------"
    echo "ID  |  Username  |  IP Address"
    echo "----------------------------------------------"
    grep -i sshd "$LOG" | grep -i "Accepted password for" > /tmp/login-ssh.txt
    data=( $(ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}') )
    for PID in "${data[@]}"; do
        grep "sshd\[$PID\]" /tmp/login-ssh.txt > /tmp/login-ssh-pid.txt
        NUM=$(wc -l < /tmp/login-ssh-pid.txt)
        USER=$(awk '{print $9}' /tmp/login-ssh-pid.txt)
        IP=$(awk '{print $11}' /tmp/login-ssh-pid.txt)
        if [ "$NUM" -eq 1 ]; then
            echo "$PID - $USER - $IP"
        fi
    done

    # OpenVPN TCP
    if [ -f "/etc/openvpn/server/openvpn-status-tcp.log" ]; then
        echo ""
        echo "---------=[ OpenVPN TCP User Login ]=---------"
        echo "Username  |  IP Address  |  Connected"
        echo "----------------------------------------------"
        grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-status-tcp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g'
    fi

    # OpenVPN UDP
    if [ -f "/etc/openvpn/server/openvpn-status-udp.log" ]; then
        echo ""
        echo "---------=[ OpenVPN UDP User Login ]=---------"
        echo "Username  |  IP Address  |  Connected"
        echo "----------------------------------------------"
        grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-status-udp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g'
    fi
}

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "     =[ SSH User Login Monitor ]=         "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

mulog=$(mesinssh)

# Ambil semua user yang punya home directory
users=( $(awk -F: '$6 ~ /home/ {print $1}' /etc/passwd) )

violations=""

for user in "${users[@]}"; do
    # Hitung jumlah login aktif user
    login_count=$(echo -e "$mulog" | grep -w "$user" | wc -l)

    if [[ $login_count -gt 0 ]]; then
        # Ambil limit dari database
        db_file="$DB_DIR/${user}.txt"
        if [[ -f "$db_file" ]]; then
            limit=$(grep -i "limit_ip:" "$db_file" | awk '{print $2}')
        else
            limit="∞"
        fi

        echo -e "\e[33;1mUser\e[32;1m    : $user"
        echo -e "\e[33;1mLogin\e[32;1m   : $login_count / $limit IP Login"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo "slot" >> "$database_tmp"

        # Auto kick jika login > limit
        if [[ "$limit" != "∞" && $login_count -gt $limit ]]; then
            echo -e "\e[31m[⚠] Peringatan:\e[0m User '\e[33m$user\e[0m' melebihi limit."
            echo -e "\e[31m     Login Aktif : $login_count (Limit: $limit)\e[0m"
            echo -e "\e[31m     → User akan dikick dari sistem.\e[0m"
            echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            pkill -u "$user"

            # Tambahkan ke daftar pelanggaran
            violations+="- *$user*: $login_count / $limit\n"
        fi
    fi
    sleep 0.1
done

aktif=$(wc -l < "$database_tmp")
echo -e "$aktif User Online"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# Bersihkan file temporary
> "$database_tmp"

# Kirim notifikasi Telegram jika ada pelanggaran dan file konfigurasi tersedia
if [[ -n "$violations" ]]; then
    telegram_msg="🚨 *SSH Limit Violation Detected!*\n\nUser yang melebihi batas login:\n$violations\nServer: \`$(hostname)\`\nWaktu: \`$(date '+%Y-%m-%d %H:%M:%S')\`"
    send_telegram "$telegram_msg" &
fi