#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create trial VMESS account
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
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
echo -e "${WHITE}  TRIAL VMESS ACCOUNT${NC}"
line
while true; do read -rp "Duration (e.g. 30m/1h): " duration; valid_duration "$duration" && break; err "Format: 30m, 1h, 1d."; done

user="trial$(gen_pass 6)"
uuid=$(gen_uuid)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "vmess" "$user" "$uuid" 10 2 "$exp_epoch"; then
  err "Failed to create trial."; exit 1
fi

exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")
link_tls=$(vmess_link 443 tls)

tg_send "<b>[ VMESS TRIAL ]</b>%0AUsername: <code>${user}</code>%0AExpired: <code>${exp_disp}</code>%0A<code>${link_tls}</code>"

clear
line
echo -e "${WHITE}  VMESS TRIAL CREATED${NC}"
line
echo -e "Username : ${user}"
echo -e "UUID     : ${uuid}"
echo -e "Quota    : 10 GB    Limit IP : 2"
echo -e "Expired  : ${exp_disp}"
line
echo -e "Link TLS :\n${link_tls}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
