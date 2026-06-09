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

# Configuration
DB_DIR="/etc/xray/database/ssh"
LIMIT_PATH="/etc/xray/limit/ip/ssh"
RECOVERY_PATH="/etc/xray/recovery/ssh"
LOG_DIR="/var/log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to get login information
get_login_info() {
    local user="$1"
    local login_data=""
    
    # Check which auth log exists
    if [ -e "${LOG_DIR}/auth.log" ]; then
        LOG="${LOG_DIR}/auth.log"
    elif [ -e "${LOG_DIR}/secure" ]; then
        LOG="${LOG_DIR}/secure"
    else
        echo "No auth log found!"
        return 1
    fi

    # Get Dropbear logins
    if command -v dropbear >/dev/null 2>&1; then
        login_data+=$(grep -i dropbear "$LOG" | grep -i "Password auth succeeded" | grep "$user" | awk '{print $12}' | sort -u | tr '\n' ' ')
    fi

    # Get OpenSSH logins
    login_data+=$(grep -i sshd "$LOG" | grep -i "Accepted password for" | grep "$user" | awk '{print $11}' | sort -u | tr '\n' ' ')

    echo "$login_data" | xargs  # Trim whitespace and return
}

# Function to delete user (matching delete-ssh.sh functionality)
delete_user() {
    local Pengguna="$1"
    
    if [[ -n "$Pengguna" ]]; then
        if [[ -f "$DB_DIR/$Pengguna.txt" ]]; then
            # Pindahkan file username.txt ke recovery
            mkdir -p "$RECOVERY_PATH"
            mv "$DB_DIR/$Pengguna.txt" "$RECOVERY_PATH/$Pengguna.txt"

            # Hapus file limit jika ada
            rm -rf "$LIMIT_PATH/$Pengguna" 2>/dev/null
            rm -rf /etc/xray/limit/ip/ssh/$Pengguna 2>/dev/null

            # Hapus user dari sistem jika masih ada
            if getent passwd "$Pengguna" > /dev/null 2>&1; then
                userdel --force "$Pengguna" > /dev/null 2>&1
            fi

            echo "User $Pengguna has been removed and moved to recovery."
            systemctl restart dropbear ssh-ws >/dev/null 2>&1
            
            # Telegram Notification
            BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
            CHAT_ID=$(cat /etc/xray/client.id 2>/dev/null)

            if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
                TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                TEXT+="<b>     IP LIMIT EXCEEDED     </b>%0A"
                TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
                TEXT+="<b>Protocol     :</b> <code>SSH</code>%0A"
                TEXT+="<b>Username     :</b> <code>$Pengguna</code>%0A"
                TEXT+="<b>Status       :</b> <code>DELETED</code>%0A"
                TEXT+="<b>Recovery     :</b> <code>Available</code>%0A"
                TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

                curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                    -d chat_id="${CHAT_ID}" \
                    -d parse_mode="HTML" \
                    -d text="${TEXT}" > /dev/null
            fi
            > /var/log/auth.log
            > /var/log/secure
            > /var/log/syslog
            return 0
        else
            echo "Failure: User $Pengguna does not exist in database."
            return 1
        fi
    else
        echo "No username specified."
        return 1
    fi
}

# Function to check and enforce limits
check_limits() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "         ${YELLOW}=[ SSH IP Limit Enforcement ]=${NC}         "
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Get all SSH users from database
    if [[ ! -d "$DB_DIR" ]]; then
        echo -e "${RED}Error: Database directory $DB_DIR not found!${NC}"
        return 1
    fi

    local deleted_count=0
    local checked_count=0

    for user_file in "$DB_DIR"/*.txt; do
        [[ ! -f "$user_file" ]] && continue
        
        local username=$(basename "$user_file" .txt)
        local limit=$(grep -i "limit_ip:" "$user_file" | awk '{print $2}')
        
        # Skip users with no limit or infinite limit
        if [[ -z "$limit" || "$limit" == "∞" || "$limit" == "unlimited" ]]; then
            continue
        fi

        # Convert limit to integer
        limit=$((limit))
        if [[ $limit -le 0 ]]; then
            continue
        fi

        ((checked_count++))
        
        # Get current login IPs for this user
        local login_ips=$(get_login_info "$username")
        local ip_count=$(echo "$login_ips" | wc -w)
        
        echo -e "${YELLOW}Checking user:${NC} ${GREEN}$username${NC}"
        echo -e "  Limit: ${YELLOW}$limit${NC} IPs, Current: ${YELLOW}$ip_count${NC} IPs"
        echo -e "  Connected IPs: ${BLUE}$login_ips${NC}"
        
        # Check if user exceeds limit
        if [[ $ip_count -gt $limit ]]; then
            echo -e "  ${RED}❌ User exceeds IP limit!${NC}"
            echo -e "  ${RED}Deleting user account...${NC}"
            
            # Delete user with recovery functionality
            output=$(delete_user "$username" 2>&1)
            if [[ $? -eq 0 ]]; then
                echo -e "  ${GREEN}✅ User $username successfully deleted and moved to recovery${NC}"
                ((deleted_count++))
                
                # Log the deletion
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Deleted user $username for exceeding IP limit ($ip_count/$limit)" >> /var/log/ssh-limit.log
            else
                echo -e "  ${RED}❌ Failed to delete user: $output${NC}"
            fi
        else
            echo -e "  ${GREEN}✅ User within allowed limits${NC}"
        fi
        
        echo -e "${BLUE}──────────────────────────────────────────────────────${NC}"
    done

    echo -e "${YELLOW}Summary:${NC}"
    echo -e "  Checked: ${GREEN}$checked_count${NC} users with IP limits"
    echo -e "  Deleted: ${RED}$deleted_count${NC} users for exceeding limits"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Main execution
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}" 
        exit 1
    fi

    check_limits
}

# Run main function
main "$@"