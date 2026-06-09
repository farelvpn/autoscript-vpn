#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: View VMESS account details
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/db.sh

db_init
domain=$(get_domain)

vmess_link() {
  local port="$1" tls="$2"
  jq -nc --arg ps "$user" --arg add "$domain" --arg port "$port" \
        --arg id "$uuid" --arg host "$domain" --arg tls "$tls" \
        '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:"/vmess",type:"none",host:$host,tls:$tls}' \
    | base64 -w 0 | sed 's/^/vmess:\/\//'
}

clear
line
echo -e "${WHITE}  VMESS ACCOUNT DETAILS${NC}"
line
db_query "SELECT username, datetime(expired_at,'unixepoch','localtime')
          FROM accounts WHERE protocol='vmess' AND status!='deleted'
          ORDER BY username;" \
  | while IFS='|' read -r u e; do printf "%-20s %-22s\n" "$u" "$e"; done
line

read -rp "Enter username: " user
if ! valid_username "$user" || ! db_account_exists "vmess" "$user"; then
  err "User not found."; read -n1 -s -r -p "Press any key..."; menu; exit 1
fi

uuid=$(db_get_field "vmess" "$user" "secret")
exp=$(db_query "SELECT datetime(expired_at,'unixepoch','localtime') FROM accounts WHERE protocol='vmess' AND username='$(sql_escape "$user")' AND status!='deleted';")
ip=$(db_get_field "vmess" "$user" "limit_ip"); [[ "$ip" == "0" ]] && ip="Unlimited"
qb=$(db_get_field "vmess" "$user" "quota_bytes")
[[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"

link_tls=$(vmess_link 443 tls)
link_http=$(vmess_link 80 none)

clear
line
echo -e "${WHITE}  VMESS ACCOUNT DETAILS${NC}"
line
echo -e "Hostname    : ${domain}"
echo -e "Username    : ${user}"
echo -e "UUID        : ${uuid}"
echo -e "Limit IP    : ${ip}"
echo -e "Quota       : ${quota}"
echo -e "Expired     : ${exp}"
echo -e "Path WS     : /vmess"
line
echo -e "Link TLS    :\n${link_tls}"
line
echo -e "Link HTTP   :\n${link_http}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
