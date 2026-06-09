#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# ========================================================
# RENEW VLESS ACCOUNT EXPIRATION (JSON API)
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

# Function to validate input
validate_input() {
    local input="$1"
    local type="$2"
    
    case "$type" in
        "username")
            [[ -n "$input" ]] && return 0
            ;;
        "days")
            [[ "$input" =~ ^[0-9]+$ ]] && [[ "$input" -gt 0 ]] && return 0
            ;;
    esac
    return 1
}

# Function to display account list
show_vless_accounts() {
    clear
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    echo -e "\e[0;41;36m              RENEW VLESS ACCOUNT EXPIRATION               \e[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"

    # Display all users with expiration info
    echo -e "Username\t\tExpired Date\t\tDays Remaining"
    echo -e "────────────────────────────────────────────────────────────────"

    # Check if database directory exists
    if [[ ! -d "/etc/xray/database/vless" ]]; then
        echo "Database directory not found!"
        return 1
    fi

    # Get list of user files
    user_files=$(ls /etc/xray/database/vless/ 2>/dev/null)

    if [[ -z "$user_files" ]]; then
        echo "No VLESS users found in database!"
        return 1
    fi

    # Display user list from database files
    for user_file in $user_files; do
        if [[ -f "/etc/xray/database/vless/$user_file" ]]; then
            username=$(echo "$user_file" | sed 's/\.txt$//')
            exp_date=$(grep "^expired:" "/etc/xray/database/vless/$user_file" | cut -d' ' -f2-)
            
            if [[ -n "$exp_date" && "$exp_date" != " " ]]; then
                days_remaining=$(calculate_days_remaining "$exp_date")
                printf "%-20s\t%s\t%s\n" "$username" "$exp_date" "$days_remaining"
            fi
        fi
    done

    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[037;1m"
    return 0
}

# Function to renew VLESS account
renew_vless_account() {
    local renew_user="$1"
    local renew_days="$2"
    
    # Validasi input
    if [[ -z "$renew_user" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username is required\"}"
        return 1
    fi

    if [[ -z "$renew_days" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Days parameter is required\"}"
        return 1
    fi

    if ! validate_input "$renew_days" "days"; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Days must be a positive number\"}"
        return 1
    fi

    # Check if user exists in database
    if [[ ! -f "/etc/xray/database/vless/${renew_user}.txt" ]]; then
        echo "{\"status\": \"false\", \"code\": 404, \"message\": \"User '$renew_user' not found in database\"}"
        return 1
    fi

    # Get current expiration date from database
    current_exp=$(grep "^expired:" "/etc/xray/database/vless/${renew_user}.txt" | cut -d' ' -f2-)
    if [[ -z "$current_exp" ]]; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Cannot read current expiration date from database\"}"
        return 1
    fi

    # Get user UUID for response
    user_uuid=$(grep "^uuid:" "/etc/xray/database/vless/${renew_user}.txt" | cut -d' ' -f2-)

    # Calculate new expiration date
    IFS='-' read -r year month day hour minute second <<< "$current_exp"

    # Create a proper date string for the date command
    current_date_str="$year-$month-$day $hour:$minute:$second"

    # Calculate new expiration using timestamp arithmetic
    current_timestamp=$(date -d "$current_date_str" +%s 2>/dev/null)
    if [[ -z "$current_timestamp" ]]; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Cannot parse current expiration date: $current_exp\"}"
        return 1
    fi

    # Add the specified number of days (in seconds)
    seconds_to_add=$((renew_days * 24 * 60 * 60))
    new_timestamp=$((current_timestamp + seconds_to_add))

    # Convert back to our desired format
    new_exp=$(date -d "@$new_timestamp" +"%Y-%m-%d-%H-%M-%S" 2>/dev/null)

    # Check if new_exp was calculated successfully
    if [[ -z "$new_exp" || "$new_exp" == " " ]]; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to calculate new expiration date\"}"
        return 1
    fi

    # Also create a display format for response
    new_exp_display=$(date -d "@$new_timestamp" +"%d-%m-%Y %H:%M:%S" 2>/dev/null)

    # Update expiration in database file
    if ! sed -i "s/expired:.*/expired: $new_exp/" "/etc/xray/database/vless/${renew_user}.txt" 2>/dev/null; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to update database file\"}"
        return 1
    fi

    # Update expiration in config.json (if user exists there)
    local config_updated="false"
    if grep -q "\"$renew_user\"" /etc/xray/config.json 2>/dev/null; then
        if sed -i "s/#÷ $renew_user .*/#÷ $renew_user $new_exp/" /etc/xray/config.json 2>/dev/null; then
            config_updated="true"
        else
            echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to update config.json\"}"
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
        TEXT+="<b>     ACCOUNT RENEWAL     </b>%0A"
        TEXT+="<b>━━━━━━━━━━━━━━━━━━━━━━━━</b>%0A"
        TEXT+="<b>Username     :</b> <code>$renew_user</code>%0A"
        TEXT+="<b>Old Expired  :</b> <code>$current_exp</code>%0A"
        TEXT+="<b>New Expired  :</b> <code>$new_exp_display</code>%0A"
        TEXT+="<b>Added Days   :</b> <code>${renew_days} days</code>%0A"
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
    "message": "VLESS account '$renew_user' renewed successfully",
    "data": {
        "username": "$renew_user",
        "uuid": "$user_uuid",
        "days_added": $renew_days,
        "old_expiration": "$current_exp",
        "new_expiration": "$new_exp",
        "new_expiration_display": "$new_exp_display",
        "config_updated": $config_updated,
        "service_restarted": $service_restarted,
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
    show_vless_accounts
    exit 0
fi

if [[ "$1" == "--interactive" ]] || [[ "$1" == "-i" ]]; then
    # Mode interaktif
    show_vless_accounts
    
    if [[ $? -ne 0 ]]; then
        read -n 1 -s -r -p "Press any key to return to menu..."
        exit 1
    fi

    # Get username to renew
    until false; do
        read -rp "Enter username to renew: " renew_user
        
        if validate_input "$renew_user" "username"; then
            # Check if user exists in database
            if [[ -f "/etc/xray/database/vless/${renew_user}.txt" ]]; then
                break
            else
                echo "User '$renew_user' not found in database!"
                read -n 1 -s -r -p "Press any key to continue..."
            fi
        else
            echo "Username cannot be empty"
            read -n 1 -s -r -p "Press any key to continue..."
        fi
        echo ""
    done

    # Get current expiration date from database
    current_exp=$(grep "^expired:" "/etc/xray/database/vless/${renew_user}.txt" | cut -d' ' -f2-)
    echo ""
    echo "Current expiration: $current_exp"

    # Get renewal days
    until false; do
        read -rp "Enter additional days (e.g., 30 for 30 days): " renew_days
        
        if validate_input "$renew_days" "days"; then
            break
        else
            echo "Days must be a positive number"
            read -n 1 -s -r -p "Press any key to continue..."
        fi
        echo ""
    done

    renew_vless_account "$renew_user" "$renew_days"
else
    # Mode PUT - membaca input JSON dari stdin
    input_data=$(cat)
    renew_user=$(echo "$input_data" | jq -r '.username' 2>/dev/null)
    renew_days=$(echo "$input_data" | jq -r '.days' 2>/dev/null)
    
    if [[ -z "$renew_user" || "$renew_user" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing username field\"}"
        exit 1
    fi
    
    if [[ -z "$renew_days" || "$renew_days" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing days field in JSON input\"}"
        exit 1
    fi
    
    # Eksekusi perpanjangan masa aktif account VLESS
    renew_vless_account "$renew_user" "$renew_days"
fi