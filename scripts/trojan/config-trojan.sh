#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: View Trojan account details
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
domain=$(get_domain)

clear
line
echo -e "${WHITE}  TROJAN ACCOUNT DETAILS${NC}"
line
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='trojan' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf "%-20s %-22s\n" "$u" "$e"; done
line

read -rp "Enter username: " user
if ! valid_username "$user" || ! db_account_exists "trojan" "$user"; then
  err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

secret=$(db_get_field "trojan" "$user" "secret")
exp=$(db_query "SELECT datetime(expired_at,'unixepoch','localtime') FROM accounts WHERE protocol='trojan' AND username='$(sql_escape "$user")' AND status!='deleted';")
ip=$(db_get_field "trojan" "$user" "limit_ip"); [[ "$ip" == "0" ]] && ip="Unlimited"
qb=$(db_get_field "trojan" "$user" "quota_bytes")
[[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"

link_tls="trojan://${secret}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

clear
line
echo -e "${WHITE}  TROJAN ACCOUNT DETAILS${NC}"
line
echo -e "Hostname    : ${domain}"
echo -e "Username    : ${user}"
echo -e "Key         : ${secret}"
echo -e "Limit IP    : ${ip}"
echo -e "Quota       : ${quota}"
echo -e "Expired     : ${exp}"
echo -e "Path WS     : /trojan"
line
echo -e "Link TLS    :\n${link_tls}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
