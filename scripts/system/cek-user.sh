#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Unified account lookup across all protocols (DB-driven)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init
domain=$(get_domain)
ip=$(get_ip)

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

vmess_link() {
  local secret="$1" port="$2" tls="$3"
  jq -nc --arg ps "$user" --arg add "$domain" --arg port "$port" \
        --arg id "$secret" --arg host "$domain" --arg tls "$tls" \
        '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:"/",type:"none",host:$host,tls:$tls}' \
    | base64 -w 0 | sed 's/^/vmess:\/\//'
}

found=0
while IFS='|' read -r proto secret iplim qb exp status; do
  [[ -z "$proto" ]] && continue
  found=1
  [[ "$iplim" == "0" ]] && iplim="Unlimited"
  if [[ "$proto" == "ssh" ]]; then
    ssh_print_cli "$user" "$secret" "$iplim" "$exp" "SSH ACCOUNT ($status)"
    continue
  fi
  [[ "$qb" == "0" ]] && quota="Unlimited" || quota="$(( qb / 1073741824 )) GB"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  printf "\e[0;42;30m %-56s \e[0m\n" "${proto^^} ACCOUNT ($status)"
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  echo -e " Remarks      : ${user}"
  echo -e " Host / IP    : ${domain}"
  case "$proto" in
    vless)
      echo -e " UUID         : ${secret}"
      echo -e " Network/Path : ws  /vless     Port: 443 (TLS) / 80 (HTTP)"
      echo -e " Quota        : ${quota}     Limit IP : ${iplim}"
      echo -e " Expired      : ${exp}"
      echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
      echo -e " Link TLS  :\n vless://${secret}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
      echo -e " Link HTTP :\n vless://${secret}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${user}"
      ;;
    vmess)
      echo -e " UUID         : ${secret}      AlterId: 0"
      echo -e " Network/Path : ws  / (multipath)   Port: 443 (TLS) / 80 (HTTP)"
      echo -e " Quota        : ${quota}     Limit IP : ${iplim}"
      echo -e " Expired      : ${exp}"
      echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
      echo -e " Link TLS  :\n $(vmess_link "$secret" 443 tls)"
      echo -e " Link HTTP :\n $(vmess_link "$secret" 80 none)"
      ;;
    trojan)
      echo -e " Key          : ${secret}"
      echo -e " Network/Path : ws  /trojan    Port: 443 (TLS)"
      echo -e " Quota        : ${quota}     Limit IP : ${iplim}"
      echo -e " Expired      : ${exp}"
      echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
      echo -e " Link TLS  :\n trojan://${secret}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"
      ;;
  esac
  echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
done < <(db_query "SELECT protocol, secret, limit_ip, quota_bytes,
                          datetime(expired_at,'unixepoch','localtime'), status
                   FROM accounts
                   WHERE username='$(sql_escape "$user")' AND status!='deleted'
                   ORDER BY protocol;")

[[ $found -eq 0 ]] && err "Account '$user' not found in any protocol."
line
read -n 1 -s -r -p "Press any key to menu..."
menu
