#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: List TROJAN accounts
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
clear
line
echo -e "${WHITE}  TROJAN ACCOUNT LIST${NC}"
line
printf "%-20s %-22s %-8s %-10s\n" "USERNAME" "EXPIRED" "LIMITIP" "STATUS"
echo "------------------------------------------------------------"
total=0
while IFS='|' read -r u e ip s; do
  [[ -z "$u" ]] && continue
  printf "%-20s %-22s %-8s %-10s\n" "$u" "$e" "$ip" "$s"
  total=$((total+1))
done < <(db_query "SELECT username, datetime(expired_at,'unixepoch','localtime'), limit_ip, status
                   FROM accounts WHERE protocol='trojan' AND status!='deleted'
                   ORDER BY username;")
line
echo -e "Total: ${total} account(s)"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
