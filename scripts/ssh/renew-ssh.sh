#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
DB_PATH="/etc/xray/database/ssh"

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
    else
        DIFF="?"
    fi

    printf "%-20s %-20s %-15s\n" "$USERNAME" "$EXPIRED" "$DIFF"
    ((COUNT++))
done

if [[ $COUNT -eq 0 ]]; then
    echo "Tidak ada akun SSH di database."
    exit 0
fi

echo "------------------------------------------------------------"
read -p "Masukkan username yang ingin diperpanjang: " USER
read -p "Tambahkan masa aktif (hari): " DAYS

if ! [[ "$USER" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
    echo "[!] Format username tidak valid."
    exit 1
fi
if [[ ! -f "$DB_PATH/$USER.txt" ]]; then
    echo "[!] Username tidak ditemukan di database."
    exit 1
fi
if ! [[ $DAYS =~ ^[0-9]+$ ]]; then
    echo "[!] Input harus berupa angka."
    exit 1
fi

# Ambil expired lama
OLD_EXP=$(grep -i "expired:" "$DB_PATH/$USER.txt" | cut -d' ' -f2-3)
OLD_DATE=$(echo "$OLD_EXP" | awk '{print $1}')

DD=$(echo "$OLD_DATE" | cut -d'-' -f1)
MM=$(echo "$OLD_DATE" | cut -d'-' -f2)
YYYY=$(echo "$OLD_DATE" | cut -d'-' -f3)

OLD_DATE_SYSTEM="$YYYY-$MM-$DD"

# Hitung expired baru
NEW_DATE_SYSTEM=$(date -d "$OLD_DATE_SYSTEM +$DAYS days" +%Y-%m-%d)
NEW_EXP_DISPLAY=$(date -d "$OLD_DATE_SYSTEM +$DAYS days" +"%d-%m-%Y %H:%M:%S")

# Update sistem user
if id "$USER" &>/dev/null; then
    chage -E "$NEW_DATE_SYSTEM" "$USER"
fi

# Update database
sed -i "s|expired:.*|expired: $NEW_EXP_DISPLAY|" "$DB_PATH/$USER.txt"

echo "------------------------------------------------------------"
echo "Username   : $USER"
echo "Expired    : $OLD_EXP → $NEW_EXP_DISPLAY"
echo "Tambahan   : $DAYS hari"
echo "------------------------------------------------------------"
