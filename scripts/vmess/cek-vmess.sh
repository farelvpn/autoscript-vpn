#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Check active VMESS logins (from xray access log)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
LOG="/var/log/xray/access.log"

clear
line
echo -e "${WHITE}  VMESS LOGIN MONITOR${NC}"
line
printf "%-20s %-8s %s\n" "USERNAME" "IPCOUNT" "IP ADDRESSES"
echo "------------------------------------------------------------"

while IFS='|' read -r user limit; do
  [[ -z "$user" ]] && continue
  ips=$(grep -w "email: $user" "$LOG" 2>/dev/null | grep "accepted" | tail -n 100 \
        | awk '{print $4}' | cut -d':' -f1 | sort -u | tr '\n' ' ')
  cnt=$(echo "$ips" | wc -w)
  [[ "$cnt" -eq 0 ]] && continue
  printf "%-20s %-8s %s\n" "$user" "${cnt}/${limit}" "$ips"
done < <(db_query "SELECT username, limit_ip FROM accounts WHERE protocol='vmess' AND status='active' ORDER BY username;")
line
read -n 1 -s -r -p "Press any key to menu..."
menu
