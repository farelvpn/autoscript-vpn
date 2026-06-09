#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Unified account lookup across all protocols (DB-driven)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
domain=$(get_domain)

clear
line
echo -e "${WHITE}  UNIFIED ACCOUNT CHECKER${NC}"
line
read -rp "Input Username : " user
line

if ! valid_username "$user"; then
  err "Invalid username format."
  read -n 1 -s -r -p "Press any key to menu..."; menu; exit 1
fi

found=0
while IFS='|' read -r proto secret ip qb exp status; do
  [[ -z "$proto" ]] && continue
  found=1
  [[ "$ip" == "0" ]] && ip="Unlimited"
  [[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"
  echo -e "Protocol : ${proto}"
  echo -e "Username : ${user}"
  echo -e "Secret   : ${secret}"
  echo -e "Limit IP : ${ip}"
  echo -e "Quota    : ${quota}"
  echo -e "Expired  : ${exp}"
  echo -e "Status   : ${status}"
  line
done < <(db_query "SELECT protocol, secret, limit_ip, quota_bytes,
                          datetime(expired_at,'unixepoch','localtime'), status
                   FROM accounts
                   WHERE username='$(sql_escape "$user")' AND status!='deleted'
                   ORDER BY protocol;")

[[ $found -eq 0 ]] && err "Account '$user' not found in any protocol."
line
read -n 1 -s -r -p "Press any key to menu..."
menu
