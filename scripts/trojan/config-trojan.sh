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
ui_header "TROJAN ACCOUNT DETAILS"
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='trojan' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf " %-20s %s\n" "$u" "$e"; done
ui_rule

read -rp "Enter username: " user
if ! valid_username "$user" || ! db_account_exists "trojan" "$user"; then
  err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

secret=$(db_get_field "trojan" "$user" "secret")
exp=$(db_query "SELECT datetime(expired_at,'unixepoch','localtime') FROM accounts WHERE protocol='trojan' AND username='$(sql_escape "$user")' AND status!='deleted';")
ip=$(db_get_field "trojan" "$user" "limit_ip"); [[ "$ip" == "0" ]] && ip="Unlimited"
qb=$(db_get_field "trojan" "$user" "quota_bytes")
[[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"

trojanlink1="trojan://${secret}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

clear
ui_header "TROJAN ACCOUNT DETAILS"
echo -e " Remarks      : ${user}"
echo -e " Host/IP      : ${domain}"
echo -e " Port TLS     : 443"
echo -e " Key          : ${secret}"
echo -e " Network/Path : ws  /trojan"
echo -e " Quota        : ${quota}     Limit IP : ${ip}"
echo -e " Expired      : ${exp}"
ui_rule
echo -e " Link TLS  :"
echo -e " ${trojanlink1}"
ui_rule
read -n 1 -s -r -p " Press any key to back to menu..."
menu
