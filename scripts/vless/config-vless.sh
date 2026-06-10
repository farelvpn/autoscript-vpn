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
ui_header "VLESS ACCOUNT DETAILS"
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='vless' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf " %-20s %s\n" "$u" "$e"; done
ui_rule

read -rp "Enter username: " user
if ! valid_username "$user" || ! db_account_exists "vless" "$user"; then
  err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

uuid=$(db_get_field "vless" "$user" "secret")
exp=$(db_query "SELECT datetime(expired_at,'unixepoch','localtime') FROM accounts WHERE protocol='vless' AND username='$(sql_escape "$user")' AND status!='deleted';")
ip=$(db_get_field "vless" "$user" "limit_ip"); [[ "$ip" == "0" ]] && ip="Unlimited"
qb=$(db_get_field "vless" "$user" "quota_bytes")
[[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"

vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${user}"

clear
ui_header "VLESS ACCOUNT DETAILS"
echo -e " Remarks      : ${user}"
echo -e " Host/IP      : ${domain}"
echo -e " Port TLS     : 443      Port HTTP : 80"
echo -e " UUID         : ${uuid}"
echo -e " Network/Path : ws  /vless"
echo -e " Quota        : ${quota}     Limit IP : ${ip}"
echo -e " Expired      : ${exp}"
ui_rule
echo -e " Link TLS  :"
echo -e " ${vlesslink1}"
ui_rule
echo -e " Link HTTP :"
echo -e " ${vlesslink2}"
ui_rule
read -n 1 -s -r -p " Press any key to back to menu..."
menu
