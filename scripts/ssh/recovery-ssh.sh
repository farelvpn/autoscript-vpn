#!/bin/bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: AutoScript VPN & Tunneling Management System
# Developed for Rocky Linux 9
# ========================================================
# recovery-ssh.sh
# Recovery SSH Account by risqinf

REC_DIR="/etc/xray/recovery/ssh"
DB_DIR="/etc/xray/database/ssh"

# Warna
RED="\033[0;31m"
GREEN="\033[0;32m"
WHITE="\033[1;37m"
NC="\033[0m" # No Color

clear
echo -e "${WHITE}============================================================"
echo -e "                       RECOVERY SSH ACCOUNT"
echo -e "============================================================${NC}"
printf "%-5s %-15s %-15s %-10s\n" "NO" "USERNAME" "EXPIRED" "LIMIT-IP"
echo -e "------------------------------------------------------------"

FILES=("$REC_DIR"/*.txt)
TOTAL=0
for i in "${!FILES[@]}"; do
    file="${FILES[$i]}"
    [ -e "$file" ] || continue

    USERNAME=$(grep -i "username:" "$file" | awk '{print $2}')
    LIMIT_IP=$(grep -i "limit_ip:" "$file" | awk '{print $2}')
    EXPIRED_RAW=$(grep -i "expired:" "$file" | cut -d' ' -f2-3)

    printf "%-5s %-15s %-15s %-10s\n" "$((i+1))" "$USERNAME" "$EXPIRED_RAW" "$LIMIT_IP"
    TOTAL=$((TOTAL+1))
done

if [ $TOTAL -eq 0 ]; then
    echo -e "${RED}[!] Tidak ada akun untuk direcovery.${NC}"
    exit 1
fi

echo -e "------------------------------------------------------------"
echo -e "Total Accounts : $TOTAL file(s)"
echo -e "============================================================"

# Pilih username
read -p "Pilih nomor akun yang ingin direcovery: " CHOICE
INDEX=$((CHOICE-1))
file="${FILES[$INDEX]}"

if [ ! -f "$file" ]; then
    echo -e "${RED}[!] File tidak ditemukan.${NC}"
    exit 1
fi

# Ambil data dari file
USERNAME=$(grep -i "username:" "$file" | awk '{print $2}')
PASSWORD=$(grep -i "password:" "$file" | awk '{print $2}')
LIMIT_IP=$(grep -i "limit_ip:" "$file" | awk '{print $2}')
EXPIRED_RAW=$(grep -i "expired:" "$file" | cut -d' ' -f2-3)

DAY=$(echo "$EXPIRED_RAW" | awk -F'-' '{print $1}')
MONTH=$(echo "$EXPIRED_RAW" | awk -F'-' '{print $2}')
YEAR=$(echo "$EXPIRED_RAW" | awk -F'-' '{print $3}' | awk '{print $1}')
EXPIRED="$YEAR-$MONTH-$DAY"

# Status
if id "$USERNAME" &>/dev/null; then
    STATUS="${RED}Already${NC}"
else
    useradd -e "$EXPIRED" -M -s /sbin/nologin "$USERNAME"
    echo -e "$PASSWORD\n$PASSWORD" | passwd "$USERNAME" &>/dev/null
    STATUS="${GREEN}Recovered${NC}"
fi

# Pindahkan file
mv "$file" "$DB_DIR/$USERNAME.txt"

echo -e "${WHITE}============================================================"
printf "%-15s %-15s %-10s %-10s\n" "USERNAME" "EXPIRED" "LIMIT-IP" "STATUS"
echo -e "------------------------------------------------------------"
printf "%-15s %-15s %-10s %-10b\n" "$USERNAME" "$EXPIRED_RAW" "$LIMIT_IP" "$STATUS"
echo -e "============================================================${NC}"