#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: View SSH account details
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
domain=$(get_domain)
ip=$(get_ip)

clear
line
echo -e "${WHITE}  SSH ACCOUNT DETAILS${NC}"
line
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='ssh' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf "%-20s %-22s\n" "$u" "$e"; done
line

read -rp "Enter username: " user
if ! valid_username "$user" || ! db_account_exists "ssh" "$user"; then
  err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

pass=$(db_get_field "ssh" "$user" "secret")
ipl=$(db_get_field "ssh" "$user" "limit_ip"); [[ "$ipl" == "0" ]] && ipl="Unlimited"
exp=$(db_query "SELECT datetime(expired_at,'unixepoch','localtime') FROM accounts WHERE protocol='ssh' AND username='$(sql_escape "$user")' AND status!='deleted';")

clear
line
echo -e "${WHITE}  SSH ACCOUNT DETAILS${NC}"
line
echo -e "Domain   : ${domain} / ${ip}"
echo -e "Username : ${user}"
echo -e "Password : ${pass}"
echo -e "Limit IP : ${ipl}"
echo -e "Expired  : ${exp}"
line
echo -e "Port OpenSSH : 109     Port WS HTTP : 80, 8888"
echo -e "Port WS TLS  : 443     Port BadVPN  : 7300"
line
echo -e "Config HTTP Custom: ${domain}:1-65535@${user}:${pass}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
