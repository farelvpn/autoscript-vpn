#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Author: risqinf
# Description: Show SSH account details from database
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================

# Data
domain=$(cat /etc/xray/domain 2>/dev/null)
if [[ -s /root/.ip ]]; then
  ip=$(cat /root/.ip)
else
  ip=$(hostname -I | awk '{print $1}')
fi

# Paths
DB_PATH="/etc/xray/database/ssh"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color

# Function to display account list
show_account_list() {
    clear
    echo -e "${WHITE}============================================================"
    echo -e "                       SSH ACCOUNT LIST"
    echo -e "============================================================${NC}"
    printf "%-5s %-15s %-15s %-10s\n" "NO" "USERNAME" "EXPIRED" "LIMIT-IP"
    echo -e "------------------------------------------------------------"

    local files=("$DB_PATH"/*.txt)
    local total=0
    
    for i in "${!files[@]}"; do
        file="${files[$i]}"
        [[ -f "$file" ]] || continue

        username=$(basename "$file" .txt)
        expired=$(grep -i "expired:" "$file" | cut -d' ' -f2-)
        limit_ip=$(grep -i "limit_ip:" "$file" | awk '{print $2}')
        
        # Format expired date for display (only show date part)
        expired_display=$(echo "$expired" | awk '{print $1}')
        
        printf "%-5s %-15s %-15s %-10s\n" "$((i+1))" "$username" "$expired_display" "$limit_ip"
        total=$((total+1))
    done

    if [[ $total -eq 0 ]]; then
        echo -e "${RED}[!] Tidak ada akun SSH yang ditemukan.${NC}"
        exit 1
    fi

    echo -e "------------------------------------------------------------"
    echo -e "Total Accounts : $total user(s)"
    echo -e "============================================================"
    echo ""
}

# Function to display account details
show_account_details() {
    local username="$1"
    local user_file="$DB_PATH/$username.txt"
    
    if [[ ! -f "$user_file" ]]; then
        echo -e "${RED}[!] File database untuk $username tidak ditemukan.${NC}"
        return 1
    fi

    # Get account details
    password=$(grep -i "password:" "$user_file" | awk '{print $2}')
    limit_ip=$(grep -i "limit_ip:" "$user_file" | awk '{print $2}')
    expired=$(grep -i "expired:" "$user_file" | cut -d' ' -f2-)

    clear
    echo -e "${WHITE} Success Show SSH Account Details "
    echo -e "———————————————————${NC}"
    echo -e "Domain   : ${GREEN}$domain${NC} / ${GREEN}$ip${NC}"
    echo -e "Username : ${GREEN}$username${NC}"
    echo -e "Password : ${GREEN}$password${NC}"
    echo -e "Limit IP : ${GREEN}$limit_ip${NC}"
    echo -e "———————————————————"
    echo -e "Port OpenSSH : 109"
    echo -e "Port WS HTTP : 80, 8888"
    echo -e "Port WS TLS  : 443"
    echo -e "Port BadVPN  : 7300"
    echo -e "Port Openvpn : 1194 / 2200"
    echo -e "Port Squid   : 8080"
    echo -e "Port OHP     : 3128, 8000"
    echo -e "———————————————————"
    echo -e "Config HTTP Custom: ${domain}:1-65535@${username}:${password}"
    echo -e "———————————————————"
    echo -e "Payload: GET / HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]"
    echo -e "———————————————————"
    echo -e "OVPN File: https://$domain/risqinf/index.html"
    echo -e "———————————————————${NC}"
    echo -e "Expired  : ${RED}$expired${NC}"
    echo -e "———————————————————${NC}"

    echo ""
    
    read -p "Tekan Enter untuk kembali ke menu..." -n 1 -r
}

# Main function
main() {
    while true; do
        show_account_list
        
        read -p "Pilih nomor akun (0 untuk keluar): " choice
        
        # Check if user wants to exit
        if [[ "$choice" == "0" ]]; then
            echo -e "${GREEN}Keluar dari program.${NC}"
            exit 0
        fi
        
        # Validate input
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Input harus berupa angka!${NC}"
            sleep 2
            continue
        fi
        
        local files=("$DB_PATH"/*.txt)
        local index=$((choice-1))
        
        if [[ $index -lt 0 || $index -ge ${#files[@]} ]]; then
            echo -e "${RED}Pilihan tidak valid!${NC}"
            sleep 2
            continue
        fi
        
        local selected_file="${files[$index]}"
        local username=$(basename "$selected_file" .txt)
        
        show_account_details "$username"
    done
}

# Check if database directory exists
if [[ ! -d "$DB_PATH" ]]; then
    echo -e "${RED}Error: Database directory $DB_PATH tidak ditemukan.${NC}"
    exit 1
fi

# Start the program
main