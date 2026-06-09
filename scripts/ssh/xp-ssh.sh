#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# Author: risqinf
# Description: Auto delete expired SSH accounts with Telegram notification
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================

auto() {

# Configurations
TELEGRAM_BOT_TOKEN=$(cat /etc/xray/bot.key 2>/dev/null)
TELEGRAM_CHATID=$(cat /etc/xray/client.id 2>/dev/null)
DB_PATH="/etc/xray/database/ssh"
LIMIT_PATH="/etc/xray/limit/ip/ssh"
RECOVERY_PATH="/etc/xray/recovery/ssh"
LOG_FILE="/var/log/auto-delete-ssh.log"

# Create necessary directories
mkdir -p "$RECOVERY_PATH"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHATID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHATID" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=$message" > /dev/null 2>&1
    fi
}

# Function to check and delete expired accounts
check_expired_accounts() {
    local current_date=$(date +%s)
    local deleted_count=0
    
    log_message "Starting expired SSH accounts check..."
    
    # Check if database directory exists
    if [[ ! -d "$DB_PATH" ]]; then
        log_message "Error: Database directory $DB_PATH does not exist."
        return 1
    fi
    
    # Process each account in the database
    for user_file in "$DB_PATH"/*.txt; do
        [[ ! -f "$user_file" ]] && continue
        
        local username=$(basename "$user_file" .txt)
        local expired_date=$(grep -i "expired:" "$user_file" | cut -d' ' -f2-)
        
        if [[ -z "$expired_date" ]]; then
            log_message "Warning: No expiration date found for $username"
            continue
        fi
        
        # Convert display format (DD-MM-YYYY HH:MM:SS) to timestamp
        local day=$(echo "$expired_date" | awk '{print $1}' | cut -d'-' -f1)
        local month=$(echo "$expired_date" | awk '{print $1}' | cut -d'-' -f2)
        local year=$(echo "$expired_date" | awk '{print $1}' | cut -d'-' -f3)
        local expired_timestamp=$(date -d "${year}-${month}-${day}" +%s 2>/dev/null)
        
        if [[ -z "$expired_timestamp" ]]; then
            log_message "Error: Invalid date format for $username: $expired_date"
            continue
        fi
        
        # Check if account is expired
        if [[ $current_date -gt $expired_timestamp ]]; then
            log_message "Deleting expired account: $username (Expired: $expired_date)"
            
            # Move to recovery directory
            mv -f "$user_file" "$RECOVERY_PATH/${username}.txt" 2>/dev/null
            
            # Remove limit file
            rm -f "$LIMIT_PATH/$username" 2>/dev/null
            
            # Delete user from system if exists
            if id "$username" &>/dev/null; then
                userdel --force "$username" >/dev/null 2>&1
            fi
            
            # Send Telegram notification
            local TEKS=$(cat <<EOF
<b>Auto Delete Expired SSH Account</b>
<b>———————————————————</b>
<b>Username:</b> <code>$username</code>
<b>Expired:</b> <code>$expired_date</code>
<b>Status:</b> <code>Moved to recovery</code>
<b>———————————————————</b>
<b>Note:</b> Account can be recovered using recovery script.
EOF
            )
            send_telegram "$TEKS"
            
            ((deleted_count++))
        fi
    done
    
    log_message "Completed. Deleted $deleted_count expired accounts."
    
    # Restart SSH service if accounts were deleted
    if [[ $deleted_count -gt 0 ]]; then
        systemctl restart dropbear >/dev/null 2>&1
    fi
}

# Main execution
case "${1:-}" in
    --run|"")
        check_expired_accounts
        ;;
    --help)
        echo "Usage: $0 [OPTION]"
        echo "Options:"
        echo "  --run    Check and delete expired accounts (default)"
        echo "  --help   Show this help message"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac

}

auto --run