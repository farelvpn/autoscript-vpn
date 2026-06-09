#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Check active SSH/Dropbear logins and enforce IP limit
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init

if   [ -e /var/log/secure ];   then LOG=/var/log/secure
elif [ -e /var/log/auth.log ]; then LOG=/var/log/auth.log
else LOG=""
fi

clear
line
echo -e "${WHITE}  SSH LOGIN MONITOR${NC}"
line
printf "%-20s %-10s %s\n" "USERNAME" "LOGIN" "IP ADDRESSES"
echo "------------------------------------------------------------"

while IFS='|' read -r user limit; do
  [[ -z "$user" ]] && continue
  ips=""
  if [[ -n "$LOG" ]]; then
    db_ips=$(grep -i "dropbear" "$LOG" 2>/dev/null | grep -i "Password auth succeeded" | grep -w "'$user'" | awk '{print $(NF)}' | sort -u | tr '\n' ' ')
    ssh_ips=$(grep -i "sshd" "$LOG" 2>/dev/null | grep "Accepted" | grep -w "$user" | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | sort -u | tr '\n' ' ')
    ips="$db_ips $ssh_ips"
  fi
  cnt=$(echo "$ips" | tr ' ' '\n' | grep -c '[0-9]')
  [[ "$cnt" -eq 0 ]] && continue
  printf "%-20s %-10s %s\n" "$user" "${cnt}/${limit}" "$ips"
done < <(db_query "SELECT username, limit_ip FROM accounts WHERE protocol='ssh' AND status='active' ORDER BY username;")
line
read -n 1 -s -r -p "Press any key to menu..."
menu
