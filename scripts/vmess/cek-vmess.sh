#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# VMESS USER LOGIN INFO + TELEGRAM (Multi-Chunk HTML)
# Sends long reports in multiple clean <pre> messages
# ========================================================

# Color definitions (for terminal only)
NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BICyan='\033[1;96m'
BIWhite='\033[1;97m'

# Telegram config
bot_token_file="/etc/xray/bot.key"
chat_id_file="/etc/xray/client.id"

# Fungsi: kirim teks panjang dalam beberapa pesan Telegram (HTML <pre>)
send_telegram_chunks() {
    local full_text="$1"
    local max=3900  # Aman di bawah batas 4096

    # Escape karakter HTML
    local safe_text
    safe_text=$(echo "$full_text" | sed 's/&/\&amp;/g; s/</\</g; s/>/\>/g')

    # Simpan ke file sementara lalu baca per baris
    local tmpfile="/tmp/tg_chunk_$$"
    echo "$safe_text" > "$tmpfile"
    mapfile -t lines < "$tmpfile"
    rm -f "$tmpfile"

    # Cek keberadaan & validitas konfigurasi bot
    if [[ ! -f "$bot_token_file" ]] || [[ ! -f "$chat_id_file" ]]; then return; fi
    local bot_token=$(cat "$bot_token_file" | tr -d ' \t\n\r')
    local chat_id=$(cat "$chat_id_file" | tr -d ' \t\n\r')
    if [[ -z "$bot_token" ]] || [[ -z "$chat_id" ]]; then return; fi

    # Bangun potongan berdasarkan baris agar tidak potong di tengah
    local current=""
    local chunks=()
    local total_lines=${#lines[@]}

    for ((i=0; i < total_lines; i++)); do
        local line="${lines[i]}"
        local test_next="$current$line"
        if [[ ${#test_next} -gt $max ]]; then
            if [[ -n "$current" ]]; then
                chunks+=("$current")
                current="$line"
            else
                # Jika satu baris saja sudah terlalu panjang, potong paksa
                chunks+=("${line:0:$max}")
                current="${line:$max}"
            fi
        else
            current="$test_next"
        fi
        # Tambahkan newline kecuali di baris terakhir
        if [[ $i -lt $((total_lines - 1)) ]]; then
            current="$current"$'\n'
        fi
    done
    [[ -n "$current" ]] && chunks+=("$current")

    # Kirim setiap bagian
    local total=${#chunks[@]}
    for i in "${!chunks[@]}"; do
        local idx=$((i + 1))
        local prefix=""
        if [[ $total -gt 1 ]]; then
            prefix="[${idx}/${total}] "
        fi
        local msg="<pre>${prefix}${chunks[$i]}</pre>"

        curl -s -X POST "https://api.telegram.org/bot$bot_token/sendMessage" \
            -d "chat_id=$chat_id" \
            -d "text=$msg" \
            -d "parse_mode=HTML" \
            -d "disable_web_page_preview=true" \
            >/dev/null 2>&1 &
        [[ $total -gt 1 ]] && sleep 0.2
    done
}

clear

# Jalankan logika utama dan simpan output CLI ke variabel
exec 3>&1
CLI_OUTPUT=$( {
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m                   VMESS USER LOGIN INFO                   \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

    # Ambil daftar user VMESS dari config.json
    readarray -t data < <(grep '###' /etc/xray/config.json | cut -d ' ' -f 2 | sort | uniq)

    if [[ ${#data[@]} -eq 0 ]]; then
        echo "No VMESS users found!"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        exit 0
    fi

    active_users_found=false
    first_user=true

    for akun in "${data[@]}"; do
        [[ -z "$akun" ]] && continue
        
        temp_log="/tmp/vmess_${akun}_log.tmp"
        temp_ips="/tmp/vmess_${akun}_ips.tmp"
        temp_unique_networks="/tmp/vmess_${akun}_networks.tmp"
        
        # Ambil log akses terbaru (maks 100 baris)
        grep -w "email: $akun" /var/log/xray/access.log | grep "accepted" | tail -n 100 > "$temp_log" 2>/dev/null
        
        if [[ -s "$temp_log" ]]; then
            active_users_found=true
            
            if [[ "$first_user" == false ]]; then
                echo -e "\033[0;34m────────────────────────────────────────────────────────────────\e[037;1m"
            fi
            first_user=false
            
            # Ekstrak IP sumber
            awk '{print $4}' "$temp_log" | cut -d':' -f1 | grep -v "^$" > "$temp_ips"
            
            # Kelompokkan berdasarkan /24 (3 oktet pertama)
            if [[ -s "$temp_ips" ]]; then
                awk -F'.' '{print $1"."$2"."$3}' "$temp_ips" | sort -u > "$temp_unique_networks"
            fi
            
            # Baca limit IP
            limit_ip="Unlimited"
            if [[ -f "/etc/xray/limit/ip/vmess/$akun" ]] && val=$(cat "/etc/xray/limit/ip/vmess/$akun") && [[ -n "$val" ]] && [[ "$val" != "0" ]]; then
                limit_ip="$val"
            fi
            
            # Baca limit kuota
            limit_quota="Unlimited"
            if [[ -f "/etc/xray/limit/quota/vmess/$akun" ]] && bytes=$(cat "/etc/xray/limit/quota/vmess/$akun") && [[ "$bytes" -gt 0 ]]; then
                gb=$((bytes / (1024**3)))
                [[ $gb -gt 0 ]] && limit_quota="${gb} GB"
            fi
            
            # Baca penggunaan kuota
            usage_quota="0"
            if [[ -f "/etc/xray/usage/quota/vmess/$akun" ]] && bytes=$(cat "/etc/xray/usage/quota/vmess/$akun") && [[ "$bytes" -gt 0 ]]; then
                if [[ $bytes -gt $((1024**3)) ]]; then
                    usage_quota="$((bytes / (1024**3))) GB"
                else
                    usage_quota="$((bytes / (1024**2))) MB"
                fi
            fi
            
            # Info login terakhir
            lastlogin=$(tail -n 1 "$temp_log" | cut -d " " -f 1,2)
            current_networks=$(wc -l < "$temp_unique_networks" 2>/dev/null || echo "0")
            
            # Tampilkan di CLI
            echo -e "${BIWhite}Username        :${NC} ${GREEN}$akun${NC}"
            echo -e "${BIWhite}Last Login      :${NC} ${lastlogin}"
            echo -e "${BIWhite}IP Connections  :${NC} ${RED}$current_networks${NC} / ${BICyan}$limit_ip${NC}"
            echo -e "${BIWhite}Data Usage      :${NC} ${RED}$usage_quota${NC} / ${BICyan}$limit_quota${NC}"
            
            # Tampilkan jaringan aktif
            if [[ -s "$temp_unique_networks" ]]; then
                echo -e "${BIWhite}Active Networks :${NC}"
                i=1
                while IFS= read -r net; do
                    [[ -z "$net" ]] && continue
                    dest=$(grep "$net" "$temp_log" | tail -n 1 | grep -oE '(tcp|udp):[^ ]+' | head -1)
                    if [[ -n "$dest" ]]; then
                        echo -e "  ${BIWhite}Network $i:${NC} ${GREEN}$net.x${NC} ${BICyan}→${NC} ${CYAN}$dest${NC}"
                    else
                        echo -e "  ${BIWhite}Network $i:${NC} ${GREEN}$net.x${NC}"
                    fi
                    ((i++))
                done < "$temp_unique_networks"
            else
                echo -e "${BIWhite}Active Networks :${NC} None"
            fi
            
            # Bersihkan file sementara
            rm -f "$temp_log" "$temp_ips" "$temp_unique_networks"
        else
            rm -f "$temp_log" "$temp_ips" "$temp_unique_networks"
        fi
    done

    if [[ "$active_users_found" == false ]]; then
        echo "No active VMESS users found!"
    fi

    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
} 2>&1 )

# Tampilkan output di terminal (dengan warna)
echo -e "$CLI_OUTPUT"

# Siapkan versi bersih untuk Telegram (hapus kode ANSI)
TELEGRAM_TEXT=$(echo "$CLI_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

# Kirim ke Telegram hanya jika ada user aktif
if [[ "$TELEGRAM_TEXT" == *"Username        :"* ]]; then
    send_telegram_chunks "$TELEGRAM_TEXT"
fi

# Jika tidak ada user sama sekali, tampilkan prompt menu
#if [[ ${#data[@]} -eq 0 ]]; then
#    read -n 1 -s -r -p "Press any key to back on menu"
#    menu
#fi