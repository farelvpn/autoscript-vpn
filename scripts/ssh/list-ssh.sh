#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Author: risqinf
# Description: List SSH accounts in vertical format
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================

# Paths
DB_PATH="/etc/xray/database/ssh"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color

# Function to mask password
mask_password() {
    local password="$1"
    local length=${#password}
    
    if [[ $length -eq 0 ]]; then
        echo "***"
    elif [[ $length -eq 1 ]]; then
        echo "*"
    elif [[ $length -eq 2 ]]; then
        echo "${password:0:1}*"
    elif [[ $length -eq 3 ]]; then
        echo "${password:0:1}**"
    else
        local visible_chars=$((length / 3))
        local masked_chars=$((length - visible_chars))
        echo "${password:0:$visible_chars}$(printf '*%.0s' $(seq 1 $masked_chars))"
    fi
}

# Function to calculate days until expiration
calculate_days_remaining() {
    local expired_date="$1"
    
    # Convert display format (DD-MM-YYYY HH:MM:SS) to timestamp
    local day=$(echo "$expired_date" | awk '{print $1}' | cut -d'-' -f1)
    local month=$(echo "$expired_date" | awk '{print $1}' | cut -d'-' -f2)
    local year=$(echo "$expired_date" | awk '{print $1}' | cut -d'-' -f3)
    local expired_timestamp=$(date -d "${year}-${month}-${day}" +%s 2>/dev/null)
    
    if [[ -z "$expired_timestamp" ]]; then
        echo "N/A"
        return
    fi
    
    local current_timestamp=$(date +%s)
    local seconds_remaining=$((expired_timestamp - current_timestamp))
    local days_remaining=$((seconds_remaining / 86400))
    
    if [[ $days_remaining -lt 0 ]]; then
        echo "${RED}EXPIRED${NC}"
    elif [[ $days_remaining -eq 0 ]]; then
        echo "${YELLOW}TODAY${NC}"
    elif [[ $days_remaining -eq 1 ]]; then
        echo "${YELLOW}1 day${NC}"
    else
        echo "${GREEN}$days_remaining days${NC}"
    fi
}

# Function to display account in vertical format
display_account() {
    local number="$1"
    local username="$2"
    local password="$3"
    local limit_ip="$4"
    local expired="$5"
    local days_remaining="$6"
    
    echo -e "${WHITE}╔══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}║ ${CYAN}ACCOUNT #$number${NC} ${WHITE}${NC}"
    echo -e "${WHITE}╠══════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}║ ${YELLOW}Username:${NC}  ${GREEN}$username${NC}"
    echo -e "${WHITE}║ ${YELLOW}Password:${NC}  ${BLUE}$password${NC}"
    echo -e "${WHITE}║ ${YELLOW}Limit IP:${NC}  ${MAGENTA}$limit_ip${NC}"
    echo -e "${WHITE}║ ${YELLOW}Expired:${NC}   ${WHITE}$expired${NC}"
    echo -e "${WHITE}║ ${YELLOW}Days Left:${NC} $days_remaining"
    echo -e "${WHITE}╚══════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to display account list
show_account_list() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               SSH ACCOUNTS LIST                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    local files=("$DB_PATH"/*.txt)
    local total=0
    
    for i in "${!files[@]}"; do
        file="${files[$i]}"
        [[ -f "$file" ]] || continue

        username=$(basename "$file" .txt)
        password=$(grep -i "password:" "$file" | awk '{print $2}')
        limit_ip=$(grep -i "limit_ip:" "$file" | awk '{print $2}')
        expired=$(grep -i "expired:" "$file" | cut -d' ' -f2-)
        
        # Mask password
        masked_password=$(mask_password "$password")
        
        # Format expired date for display (only show date part)
        expired_display=$(echo "$expired" | awk '{print $1}')
        
        # Calculate days remaining
        days_remaining=$(calculate_days_remaining "$expired")
        
        # Display account
        display_account "$((i+1))" "$username" "$masked_password" "$limit_ip" "$expired_display" "$days_remaining"
        
        total=$((total+1))
    done

    if [[ $total -eq 0 ]]; then
        echo -e "${RED}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║           NO SSH ACCOUNTS FOUND                  ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           TOTAL SSH ACCOUNTS: $total                  ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    fi
}

# Check if database directory exists
if [[ ! -d "$DB_PATH" ]]; then
    echo -e "${RED}Error: Database directory $DB_PATH not found.${NC}"
    exit 1
fi

# Display account list
show_account_list

# Additional information
echo -e "\n${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                     NOTE                         ║${NC}"
echo -e "${YELLOW}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║ • Passwords are masked for security              ║${NC}"
echo -e "${YELLOW}║ • ${GREEN}Green days${YELLOW} = Active account                    ║${NC}"
echo -e "${YELLOW}║ • ${YELLOW}Yellow days${YELLOW} = Expiring soon                    ║${NC}"
echo -e "${YELLOW}║ • ${RED}Red days${YELLOW} = Account expired                     ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"