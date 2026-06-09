#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create VMESS account (SQLite + pure-JSON config)
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
echo -e "${WHITE}  ADD VMESS ACCOUNT${NC}"
line

while true; do
  read -rp "Username: " user
  if ! valid_username "$user"; then err "Username 3-32 chars: letters, numbers, underscore."; continue; fi
  if db_account_exists "vmess" "$user" || cfg_client_exists "$user"; then err "Username '$user' already exists."; continue; fi
  break
done

read -rp "Custom UUID (Enter to auto-generate): " uuid
if [[ -z "$uuid" ]]; then uuid=$(gen_uuid)
elif ! valid_uuid "$uuid"; then err "Invalid UUID format."; exit 1; fi

while true; do read -rp "Quota (GB, 0=unlimited): " quota; valid_number "$quota" && break; err "Number only."; done
while true; do read -rp "Limit IP (0=unlimited): " iplimit; valid_number "$iplimit" && break; err "Number only."; done
while true; do read -rp "Duration (e.g. 30m/2h/1d): " duration; valid_duration "$duration" && break; err "Format: 30m, 2h, 1d."; done

secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "vmess" "$user" "$uuid" "$quota" "$iplimit" "$exp_epoch"; then
  err "Failed to create account."; exit 1
fi

exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")
[[ "$quota" == "0" ]] && quota_disp="Unlimited" || quota_disp="${quota} GB"
[[ "$iplimit" == "0" ]] && ip_disp="Unlimited" || ip_disp="$iplimit"

link_tls=$(vmess_link 443 tls)
link_http=$(vmess_link 80 none)

tg_send "<b>[ VMESS ACCOUNT ]</b>
Hostname : <code>${domain}</code>
Username : <code>${user}</code>
UUID     : <code>${uuid}</code>
Quota    : <code>${quota_disp}</code>
Limit IP : <code>${ip_disp}</code>
Expired  : <code>${exp_disp}</code>
<code>${link_tls}</code>"

clear
line
echo -e "${WHITE}  VMESS ACCOUNT CREATED${NC}"
line
echo -e "Hostname    : ${domain}"
echo -e "Username    : ${user}"
echo -e "UUID        : ${uuid}"
echo -e "Quota       : ${quota_disp}"
echo -e "Limit IP    : ${ip_disp}"
echo -e "Expired     : ${exp_disp}"
echo -e "Path WS     : /vmess"
line
echo -e "Link TLS    :\n${link_tls}"
line
echo -e "Link HTTP   :\n${link_http}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
