#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# DELETE TROJAN ACCOUNT WITH RECOVERY (JSON API)
# ========================================================

# Data
domain=$(cat /etc/xray/domain 2>/dev/null)
telegram_bot_token=$(cat /etc/xray/bot.key 2>/dev/null)
telegram_chatid=$(cat /etc/xray/client.id 2>/dev/null)

# Cek apakah kosong
if [[ -z "$domain" ]]; then
    domain="not set"
fi

if [[ -z "$telegram_bot_token" ]]; then
    telegram_bot_token="not set"
fi

if [[ -z "$telegram_chatid" ]]; then
    telegram_chatid="not set"
fi

# Function to calculate days remaining
calculate_days_remaining() {
    local exp_date="$1"
    # Convert YYYY-MM-DD-HH-MM-SS to YYYY-MM-DD for date comparison (only date part)
    local exp_date_only=$(echo "$exp_date" | cut -d'-' -f1-3)
    local current_date=$(date +%Y-%m-%d)
    
    local exp_timestamp=$(date -d "$exp_date_only" +%s 2>/dev/null)
    local current_timestamp=$(date -d "$current_date" +%s)
    
    if [[ -n "$exp_timestamp" ]]; then
        local diff_seconds=$((exp_timestamp - current_timestamp))
        local days_remaining=$((diff_seconds / 86400))
        if [[ $days_remaining -lt 0 ]]; then
            echo "0"
        else
            echo "$days_remaining"
        fi
    else
        echo "Invalid"
    fi
}

# Function to display account list
show_trojan_accounts() {
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m              DELETE TROJAN ACCOUNT                         \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

    # Display all users with expiration info
    echo -e "Username\t\tExpired Date\t\tDays Remaining"
    echo -e "────────────────────────────────────────────────────────────────"

    # Check if database directory exists
    if [[ ! -d "/etc/xray/database/trojan" ]]; then
        echo "Database directory not found!"
        return 1
    fi

    # Get list of user files
    user_files=$(ls /etc/xray/database/trojan/ 2>/dev/null)

    if [[ -z "$user_files" ]]; then
        echo "No Trojan users found in database!"
        return 1
    fi

    # Display user list from database files
    for user_file in $user_files; do
        if [[ -f "/etc/xray/database/trojan/$user_file" ]]; then
            username=$(echo "$user_file" | sed 's/\.txt$//')
            exp_date=$(grep "^expired:" "/etc/xray/database/trojan/$user_file" | cut -d' ' -f2-)
            
            if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
                days_remaining=$(calculate_days_remaining "$exp_date")
                printf "%-20s\t%s\t%s\n" "$username" "$exp_date" "$days_remaining"
            fi
        fi
    done

    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    return 0
}

# Function to delete Trojan account
delete_trojan_account() {
    local delete_user="$1"
    local force_delete="${2:-false}"
    
    # Validasi input
    if [[ -z "$delete_user" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username is required\"}"
        return 1
    fi

    # Validasi format username (cegah path traversal & injeksi sed)
    if ! [[ "$delete_user" =~ ^[a-zA-Z0-9_]{1,32}$ ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid username format\"}"
        return 1
    fi

    # Check if user exists in database
    if [[ ! -f "/etc/xray/database/trojan/${delete_user}.txt" ]]; then
        echo "{\"status\": \"false\", \"code\": 404, \"message\": \"User '$delete_user' not found in database\"}"
        return 1
    fi

    # Get user data before deletion for response
    local user_data=""
    local user_uuid=""
    local user_expired=""
    
    if [[ -f "/etc/xray/database/trojan/${delete_user}.txt" ]]; then
        user_data=$(cat "/etc/xray/database/trojan/${delete_user}.txt")
        user_uuid=$(grep "^uuid:" "/etc/xray/database/trojan/${delete_user}.txt" | cut -d' ' -f2-)
        user_expired=$(grep "^expired:" "/etc/xray/database/trojan/${delete_user}.txt" | cut -d' ' -f2-)
    fi

    # Create recovery directory if it doesn't exist
    mkdir -p /etc/xray/recovery/trojan

    # Files to track what was removed
    local files_removed=()
    local recovery_created="false"

    # Move database file to recovery directory
    if [[ -f "/etc/xray/database/trojan/${delete_user}.txt" ]]; then
        if mv "/etc/xray/database/trojan/${delete_user}.txt" "/etc/xray/recovery/trojan/${delete_user}.txt" 2>/dev/null; then
            recovery_created="true"
            files_removed+=("database")
        else
            echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to move database file to recovery\"}"
            return 1
        fi
    fi

    # Remove quota limit file if exists
    if [[ -f "/etc/xray/limit/quota/trojan/${delete_user}" ]]; then
        if rm -f "/etc/xray/limit/quota/trojan/${delete_user}" 2>/dev/null; then
            files_removed+=("quota_limit")
        fi
    fi

    # Remove IP limit file if exists
    if [[ -f "/etc/xray/limit/ip/trojan/${delete_user}" ]]; then
        if rm -f "/etc/xray/limit/ip/trojan/${delete_user}" 2>/dev/null; then
            files_removed+=("ip_limit")
        fi
    fi

    # Remove usage quota file if exists
    if [[ -f "/etc/xray/usage/quota/trojan/${delete_user}" ]]; then
        if rm -f "/etc/xray/usage/quota/trojan/${delete_user}" 2>/dev/null; then
            files_removed+=("usage_quota")
        fi
    fi

    # Remove user from config.json
    local config_updated="false"
    if grep -q "#@ $delete_user " /etc/xray/config.json 2>/dev/null; then
        # Backup config before modification
        cp /etc/xray/config.json /etc/xray/config.json.backup.$(date +%s) 2>/dev/null
        
        # Remove the user entry (2 lines: the #@ comment line and the user data line)
        if sed -i "/#@ $delete_user /,/^}/d" /etc/xray/config.json 2>/dev/null; then
            # Also remove any trailing comma that might be left
            sed -i '/},/ { :a;N;$!ba;s/},\n\s*}/}\n}/g; }' /etc/xray/config.json 2>/dev/null
            config_updated="true"
            files_removed+=("config_entry")
        else
            echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to remove user from config.json\"}"
            # Restore backup on failure
            mv /etc/xray/config.json.backup.* /etc/xray/config.json 2>/dev/null
            return 1
        fi
    fi

    # Restart Xray service
    local service_restarted="false"
    if systemctl restart xray.service 2>/dev/null; then
        service_restarted="true"
    else
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to restart Xray service\"}"
        return 1
    fi

    # Send to Telegram if configured
    local telegram_sent="false"
    if [[ "$telegram_bot_token" != "not set" && "$telegram_chatid" != "not set" ]]; then
        TEXT="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>     ACCOUNT DELETED     </b>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>Username     :</b> <code>$delete_user</code>%0A"
        TEXT+="<b>Status       :</b> <code>DELETED</code>%0A"
        TEXT+="<b>Recovery     :</b> <code>Available</code>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"

        if curl -s -X POST "https://api.telegram.org/bot${telegram_bot_token}/sendMessage" \
            -d chat_id="${telegram_chatid}" \
            -d parse_mode="HTML" \
            -d text="${TEXT}" > /dev/null 2>&1; then
            telegram_sent="true"
        fi
    fi

    # Response data
    response=$(cat <<EOF
{
    "status": "true",
    "code": 200,
    "message": "Trojan account '$delete_user' deleted successfully",
    "data": {
        "username": "$delete_user",
        "uuid": "$user_uuid",
        "expired": "$user_expired",
        "recovery": {
            "created": $recovery_created,
            "path": "/etc/xray/recovery/trojan/${delete_user}.txt"
        },
        "files_removed": $(printf '%s\n' "${files_removed[@]}" | jq -R . | jq -s .),
        "service_restarted": $service_restarted,
        "config_updated": $config_updated,
        "telegram_notification": "$telegram_sent",
        "domain": "$domain"
    }
}
EOF
    )

    echo "$response"
    return 0
}

# Main execution
if [[ "$1" == "--list" ]] || [[ "$1" == "-l" ]]; then
    # Mode list untuk debugging/monitoring
    show_trojan_accounts
    exit 0
fi

if [[ "$1" == "--interactive" ]] || [[ "$1" == "-i" ]]; then
    # Mode interaktif
    show_trojan_accounts
    
    if [[ $? -ne 0 ]]; then
        read -n 1 -s -r -p "Press any key to return to menu..."
        exit 1
    fi

    # Get username to delete
    read -rp "Enter username to delete: " delete_user

    # Check if user exists in database
    if [[ ! -f "/etc/xray/database/trojan/${delete_user}.txt" ]]; then
        echo "User '$delete_user' not found in database!"
        read -n 1 -s -r -p "Press any key to return to menu..."
        exit 1
    fi

    # Confirmation
    echo ""
    read -rp "Are you sure you want to delete user '$delete_user'? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Account deletion cancelled."
        read -n 1 -s -r -p "Press any key to return to menu..."
        exit 0
    fi

    delete_trojan_account "$delete_user"
else
    # Mode DELETE - membaca input JSON dari stdin
    input_data=$(cat)
    delete_user=$(echo "$input_data" | jq -r '.username' 2>/dev/null)
    force_delete=$(echo "$input_data" | jq -r '.force' 2>/dev/null)
    
    if [[ -z "$delete_user" || "$delete_user" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing username field\"}"
        exit 1
    fi
    
    # Eksekusi penghapusan account Trojan
    delete_trojan_account "$delete_user" "$force_delete"
fi