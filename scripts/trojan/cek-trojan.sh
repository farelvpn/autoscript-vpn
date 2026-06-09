#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# TROJAN USER LOGIN INFO + TELEGRAM (Multi-Chunk HTML)
# Sends long reports in multiple clean <pre> messages
# ========================================================

NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BICyan='\033[1;96m'
BIWhite='\033[1;97m'

bot_token_file="/etc/xray/bot.key"
chat_id_file="/etc/xray/client.id"

# Fungsi: kirim teks panjang dalam beberapa pesan Telegram
send_telegram_chunks() {
    local full_text="$1"
    local max=3900

    # Escape HTML
    local safe_text
    safe_text=$(echo "$full_text" | sed 's/&/\&amp;/g; s/</\</g; s/>/\>/g')

    # Simpan ke file sementara lalu baca per baris
    local tmpfile="/tmp/tg_chunk_$$"
    echo "$safe_text" > "$tmpfile"
    mapfile -t lines < "$tmpfile"
    rm -f "$tmpfile"

    # Cek konfigurasi bot
    if [[ ! -f "$bot_token_file" ]] || [[ ! -f "$chat_id_file" ]]; then return; fi
    local bot_token=$(cat "$bot_token_file" | tr -d ' \t\n\r')
    local chat_id=$(cat "$chat_id_file" | tr -d ' \t\n\r')
    if [[ -z "$bot_token" ]] || [[ -z "$chat_id" ]]; then return; fi

    # Bangun potongan berdasarkan baris
    local current=""
    local chunks=()
    local total_lines=${#lines[@]}

    for ((i=0; i<total_lines; i++)); do
        local line="${lines[i]}"
        local test_next="$current$line"
        if [[ ${#test_next} -gt $max ]]; then
            if [[ -n "$current" ]]; then
                chunks+=("$current")
                current="$line"
            else
                chunks+=("${line:0:$max}")
                current="${line:$max}"
            fi
        else
            current="$test_next"
        fi
        if [[ $i -lt $((total_lines - 1)) ]]; then
            current="$current"$'\n'
        fi
    done
    [[ -n "$current" ]] && chunks+=("$current")

    local total=${#chunks[@]}
    for i in "${!chunks[@]}"; do
        local idx=$((i+1))
        local prefix=""
        if [[ $total -gt 1 ]]; then prefix="[${idx}/${total}] "; fi
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
exec 3>&1
CLI_OUTPUT=$( {
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m                   TROJAN USER LOGIN INFO                   \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

    readarray -t data < <(grep '#@' /etc/xray/config.json | cut -d ' ' -f 2 | sort | uniq)

    if [[ ${#data[@]} -eq 0 ]]; then
        echo "No TROJAN users found!"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
        exit 0
    fi

    active_users_found=false
    first_user=true

    for akun in "${data[@]}"; do
        [[ -z "$akun" ]] && continue
        temp_log="/tmp/trojan_${akun}_log.tmp"
        temp_ips="/tmp/trojan_${akun}_ips.tmp"
        temp_unique_networks="/tmp/trojan_${akun}_networks.tmp"
        
        grep -w "email: $akun" /var/log/xray/access.log | grep "accepted" | tail -n 100 > "$temp_log" 2>/dev/null
        
        if [[ -s "$temp_log" ]]; then
            active_users_found=true
            if [[ "$first_user" == false ]]; then
                echo -e "\033[0;34m────────────────────────────────────────────────────────────────\e[037;1m"
            fi
            first_user=false
            
            awk '{print $4}' "$temp_log" | cut -d':' -f1 | grep -v "^$" > "$temp_ips"
            if [[ -s "$temp_ips" ]]; then
                awk -F'.' '{print $1"."$2"."$3}' "$temp_ips" | sort -u > "$temp_unique_networks"
            fi
            
            limit_ip="Unlimited"
            if [[ -f "/etc/xray/limit/ip/trojan/$akun" ]] && val=$(cat "/etc/xray/limit/ip/trojan/$akun") && [[ -n "$val" ]] && [[ "$val" != "0" ]]; then
                limit_ip="$val"
            fi
            
            limit_quota="Unlimited"
            if [[ -f "/etc/xray/limit/quota/trojan/$akun" ]] && bytes=$(cat "/etc/xray/limit/quota/trojan/$akun") && [[ "$bytes" -gt 0 ]]; then
                gb=$((bytes / (1024**3)))
                [[ $gb -gt 0 ]] && limit_quota="${gb} GB"
            fi
            
            usage_quota="0"
            if [[ -f "/etc/xray/usage/quota/trojan/$akun" ]] && bytes=$(cat "/etc/xray/usage/quota/trojan/$akun") && [[ "$bytes" -gt 0 ]]; then
                if [[ $bytes -gt $((1024**3)) ]]; then
                    usage_quota="$((bytes / (1024**3))) GB"
                else
                    usage_quota="$((bytes / (1024**2))) MB"
                fi
            fi
            
            lastlogin=$(tail -n 1 "$temp_log" | cut -d " " -f 1,2)
            current_networks=$(wc -l < "$temp_unique_networks" 2>/dev/null || echo "0")
            
            echo -e "${BIWhite}Username        :${NC} ${GREEN}$akun${NC}"
            echo -e "${BIWhite}Last Login      :${NC} ${lastlogin}"
            echo -e "${BIWhite}IP Connections  :${NC} ${RED}$current_networks${NC} / ${BICyan}$limit_ip${NC}"
            echo -e "${BIWhite}Data Usage      :${NC} ${RED}$usage_quota${NC} / ${BICyan}$limit_quota${NC}"
            
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
            
            rm -f "$temp_log" "$temp_ips" "$temp_unique_networks"
        else
            rm -f "$temp_log" "$temp_ips" "$temp_unique_networks"
        fi
    done

    if [[ "$active_users_found" == false ]]; then
        echo "No active TROJAN users found!"
    fi

    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
} 2>&1 )

echo -e "$CLI_OUTPUT"
TELEGRAM_TEXT=$(echo "$CLI_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

if [[ "$TELEGRAM_TEXT" == *"Username        :"* ]]; then
    send_telegram_chunks "$TELEGRAM_TEXT"
fi

#if [[ ${#data[@]} -eq 0 ]]; then
#    read -n 1 -s -r -p "Press any key to back on menu"
#    menu
#fi