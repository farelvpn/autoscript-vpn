#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: View VLESS account details
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
domain=$(get_domain)

clear
line
echo -e "${WHITE}  VLESS ACCOUNT DETAILS${NC}"
line
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='vless' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf "%-20s %-22s\n" "$u" "$e"; done
line

read -rp "Enter username: " user
if ! valid_username "$user" || ! db_account_exists "vless" "$user"; then
  err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

uuid=$(db_get_field "vless" "$user" "secret")
exp=$(db_query "SELECT datetime(expired_at,'unixepoch','localtime') FROM accounts WHERE protocol='vless' AND username='$(sql_escape "$user")' AND status!='deleted';")
ip=$(db_get_field "vless" "$user" "limit_ip"); [[ "$ip" == "0" ]] && ip="Unlimited"
qb=$(db_get_field "vless" "$user" "quota_bytes")
[[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"

link_tls="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
link_http="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${user}"

clear
line
echo -e "${WHITE}  VLESS ACCOUNT DETAILS${NC}"
line
echo -e "Hostname    : ${domain}"
echo -e "Username    : ${user}"
echo -e "UUID        : ${uuid}"
echo -e "Limit IP    : ${ip}"
echo -e "Quota       : ${quota}"
echo -e "Expired     : ${exp}"
echo -e "Path WS     : /vless"
line
echo -e "Link TLS    :\n${link_tls}"
line
echo -e "Link HTTP   :\n${link_http}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
