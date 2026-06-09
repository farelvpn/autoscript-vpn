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

DB_PATH="/etc/xray/database/ssh"

# Fungsi untuk menampilkan daftar akun
show_ssh_accounts() {
    clear
    echo "============================================================"
    echo "                 EXTEND SSH ACCOUNT"
    echo "============================================================"
    printf "%-20s %-20s %-15s\n" "USERNAME" "EXPIRED" "SISA HARI"
    echo "------------------------------------------------------------"

    COUNT=0
    for file in "$DB_PATH"/*.txt; do
        [[ ! -f "$file" ]] && continue
        USERNAME=$(grep -i "username:" "$file" | awk '{print $2}')
        EXPIRED=$(grep -i "expired:" "$file" | cut -d' ' -f2-3)

        # Ambil tanggal saja (DD-MM-YYYY)
        EXPIRED_DATE=$(echo "$EXPIRED" | awk '{print $1}')
        DD=$(echo "$EXPIRED_DATE" | cut -d'-' -f1)
        MM=$(echo "$EXPIRED_DATE" | cut -d'-' -f2)
        YYYY=$(echo "$EXPIRED_DATE" | cut -d'-' -f3)

        # Konversi ke YYYY-MM-DD
        EXPIRED_SYSTEM="$YYYY-$MM-$DD"

        # Hitung sisa hari
        if DATE_EPOCH=$(date -d "$EXPIRED_SYSTEM" +%s 2>/dev/null); then
            TODAY=$(date +%s)
            DIFF=$(( (DATE_EPOCH - TODAY) / 86400 ))
            if [[ $DIFF -lt 0 ]]; then
                DIFF="EXPIRED"
            fi
        else
            DIFF="?"
        fi

        printf "%-20s %-20s %-15s\n" "$USERNAME" "$EXPIRED" "$DIFF"
        ((COUNT++))
    done

    if [[ $COUNT -eq 0 ]]; then
        echo "Tidak ada akun SSH di database."
    fi
    
    echo "------------------------------------------------------------"
    return $COUNT
}

# Fungsi untuk memperpanjang masa aktif akun SSH
extend_ssh_account() {
    local username="$1"
    local days="$2"
    
    # Validasi input
    if [[ -z "$username" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username is required\"}"
        return 1
    fi

    # Validasi format username (cegah path traversal & injeksi)
    if ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid username format\"}"
        return 1
    fi

    if [[ -z "$days" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Days parameter is required\"}"
        return 1
    fi

    if ! [[ $days =~ ^[0-9]+$ ]] || [[ $days -lt 1 ]] || [[ $days -gt 3650 ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Days must be a number between 1 and 3650\"}"
        return 1
    fi

    # Cek apakah user ada di database
    if [[ ! -f "$DB_PATH/$username.txt" ]]; then
        echo "{\"status\": \"false\", \"code\": 404, \"message\": \"User '$username' does not exist in database\"}"
        return 1
    fi

    # Ambil data expired lama
    OLD_EXP=$(grep -i "expired:" "$DB_PATH/$username.txt" | cut -d' ' -f2-3)
    if [[ -z "$OLD_EXP" ]]; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Cannot read expired date from database\"}"
        return 1
    fi

    OLD_DATE=$(echo "$OLD_EXP" | awk '{print $1}')
    DD=$(echo "$OLD_DATE" | cut -d'-' -f1)
    MM=$(echo "$OLD_DATE" | cut -d'-' -f2)
    YYYY=$(echo "$OLD_DATE" | cut -d'-' -f3)

    OLD_DATE_SYSTEM="$YYYY-$MM-$DD"

    # Validasi format tanggal
    if ! date -d "$OLD_DATE_SYSTEM" >/dev/null 2>&1; then
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Invalid date format in database: $OLD_DATE_SYSTEM\"}"
        return 1
    fi

    # Hitung expired baru
    NEW_DATE_SYSTEM=$(date -d "$OLD_DATE_SYSTEM +$days days" +%Y-%m-%d)
    NEW_EXP_DISPLAY=$(date -d "$OLD_DATE_SYSTEM +$days days" +"%d-%m-%Y %H:%M:%S")

    # Update sistem user
    local system_updated="false"
    if id "$username" &>/dev/null; then
        if chage -E "$NEW_DATE_SYSTEM" "$username" 2>/dev/null; then
            system_updated="true"
        else
            echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to update system user expiration\"}"
            return 1
        fi
    fi

    # Update database
    if sed -i "s|expired:.*|expired: $NEW_EXP_DISPLAY|" "$DB_PATH/$username.txt"; then
        # Response sukses
        echo "{\"status\": \"true\", \"code\": 200, \"message\": \"Account '$username' successfully extended by $days days\", \"data\": {\"username\": \"$username\", \"days_added\": $days, \"old_expiration\": \"$OLD_EXP\", \"new_expiration\": \"$NEW_EXP_DISPLAY\", \"system_updated\": $system_updated}}"
        return 0
    else
        echo "{\"status\": \"false\", \"code\": 500, \"message\": \"Failed to update database\"}"
        return 1
    fi
}

# Main execution
if [[ "$1" == "--list" ]] || [[ "$1" == "-l" ]]; then
    # Mode list untuk debugging/monitoring
    show_ssh_accounts
    exit 0
fi

# Mode PUT - membaca input JSON dari stdin
if [ ! -t 0 ]; then
    # Ada input dari pipe/redirect (JSON input)
    input_data=$(cat)
    username=$(echo "$input_data" | jq -r '.username' 2>/dev/null)
    days=$(echo "$input_data" | jq -r '.days' 2>/dev/null)
    
    if [[ -z "$username" || "$username" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing username field\"}"
        exit 1
    fi
    
    if [[ -z "$days" || "$days" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Missing days field in JSON input\"}"
        exit 1
    fi
    
    # Eksekusi perpanjangan masa aktif
    extend_ssh_account "$username" "$days"
else
    # Mode interaktif (fallback)
    show_ssh_accounts
    
    if [[ $? -eq 0 ]]; then
        exit 0
    fi
    
    echo ""
    read -p "Masukkan username yang ingin diperpanjang: " USER
    read -p "Tambahkan masa aktif (hari): " DAYS
    
    extend_ssh_account "$USER" "$DAYS"
fi