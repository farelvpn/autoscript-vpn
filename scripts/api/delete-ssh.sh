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
LIMIT_PATH="/etc/xray/limit/ip/ssh"
RECOVERY_PATH="/etc/xray/recovery/ssh"

mkdir -p "$RECOVERY_PATH"

# Fungsi untuk menampilkan daftar akun (opsional, untuk debugging)
show_accounts() {
    clear
    echo "============================================================"
    echo "                         SSH ACCOUNT LIST"
    echo "============================================================"
    printf "%-20s %-20s %-15s\n" "USERNAME" "EXPIRED" "STATUS"
    echo "------------------------------------------------------------"

    COUNT=0
    for file in "$DB_PATH"/*.txt; do
        [[ ! -f "$file" ]] && continue
        USERNAME=$(basename "$file" .txt)

        # Ambil expired dari file database user
        EXPIRED=$(grep -i "expired" "$file" | awk -F': ' '{print $2}')
        [[ -z "$EXPIRED" ]] && EXPIRED="Unknown"

        # Ambil status dari passwd -S (cek apakah user masih ada di sistem)
        if getent passwd "$USERNAME" > /dev/null 2>&1; then
            STATUS=$(passwd -S "$USERNAME" | awk '{print $2}')
            if [[ "$STATUS" == "L" ]]; then
                STATUS="LOCKED"
                printf "%-20s %-20s \033[31m%-15s\033[0m\n" "$USERNAME" "$EXPIRED" "$STATUS"
            else
                STATUS="ACTIVE"
                printf "%-20s %-20s \033[32m%-15s\033[0m\n" "$USERNAME" "$EXPIRED" "$STATUS"
            fi
        else
            STATUS="REMOVED"
            printf "%-20s %-20s \033[31m%-15s\033[0m\n" "$USERNAME" "$EXPIRED" "$STATUS"
        fi

        ((COUNT++))
    done

    echo "------------------------------------------------------------"
    echo "Total Accounts : $COUNT user(s)"
    echo "============================================================"
}

# Fungsi untuk menghapus akun SSH
delete_ssh_account() {
    local username="$1"
    
    # Validasi input
    if [[ -z "$username" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Username is required\"}"
        return 1
    fi

    # Cek apakah user ada di database
    if [[ ! -f "$DB_PATH/$username.txt" ]]; then
        echo "{\"status\": \"false\", \"code\": 404, \"message\": \"User '$username' does not exist in database\"}"
        return 1
    fi

    # Ambil data user sebelum dihapus untuk response
    local user_data=""
    if [[ -f "$DB_PATH/$username.txt" ]]; then
        user_data=$(cat "$DB_PATH/$username.txt")
    fi

    # Pindahkan file username.txt ke recovery
    mv "$DB_PATH/$username.txt" "$RECOVERY_PATH/$username.txt" 2>/dev/null

    # Hapus file limit jika ada
    rm -rf "$LIMIT_PATH/$username" 2>/dev/null
    rm -rf "/etc/xray/limit/ip/ssh/$username" 2>/dev/null

    # Hapus user dari sistem jika masih ada
    local user_deleted="false"
    if getent passwd "$username" > /dev/null 2>&1; then
        userdel --force "$username" > /dev/null 2>&1
        user_deleted="true"
    fi

    # Restart services
    systemctl restart dropbear ssh-ws >/dev/null 2>&1

    # Response sukses
    echo "{\"status\": \"true\", \"code\": 200, \"message\": \"User '$username' has been successfully deleted\", \"data\": {\"username\": \"$username\", \"system_user_removed\": $user_deleted, \"recovery_backup\": true}}"
    return 0
}

# Main execution
if [[ "$1" == "--list" ]] || [[ "$1" == "-l" ]]; then
    # Mode list untuk debugging/monitoring
    show_accounts
    exit 0
fi

# Mode DELETE - membaca input JSON dari stdin
if [ ! -t 0 ]; then
    # Ada input dari pipe/redirect (JSON input)
    input_data=$(cat)
    username=$(echo "$input_data" | jq -r '.username' 2>/dev/null)
    
    if [[ -z "$username" || "$username" == "null" ]]; then
        echo "{\"status\": \"false\", \"code\": 400, \"message\": \"Invalid JSON input or missing username field\"}"
        exit 1
    fi
    
    # Eksekusi penghapusan
    delete_ssh_account "$username"
else
    # Mode interaktif (fallback)
    show_accounts
    echo ""
    read -p "Username SSH to Delete : " Pengguna
    delete_ssh_account "$Pengguna"
fi