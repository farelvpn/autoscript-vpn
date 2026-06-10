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
        '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:"/",type:"none",host:$host,tls:$tls}' \
    | base64 -w 0 | sed 's/^/vmess:\/\//'
}

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;41;36m                   ADD VMESS ACCOUNT                        \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

while true; do
  read -rp "Username       : " user
  if ! valid_username "$user"; then err "Username 3-32 chars: letters, numbers, underscore."; continue; fi
  if db_account_exists "vmess" "$user" || cfg_client_exists "$user"; then err "Username '$user' already exists."; continue; fi
  break
done

read -rp "Custom UUID    : (Enter to auto) " uuid
if [[ -z "$uuid" ]]; then uuid=$(gen_uuid)
elif ! valid_uuid "$uuid"; then err "Invalid UUID format."; exit 1; fi

while true; do read -rp "Quota (GB,0=unl): " quota; valid_number "$quota" && break; err "Number only."; done
while true; do read -rp "Limit IP (0=unl): " iplimit; valid_number "$iplimit" && break; err "Number only."; done
while true; do read -rp "Expired (30m/2h/1d): " duration; valid_duration "$duration" && break; err "Format: 30m, 2h, 1d."; done

secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "vmess" "$user" "$uuid" "$quota" "$iplimit" "$exp_epoch"; then
  err "Failed to create account."; exit 1
fi

exp_disp=$(date -d "@${exp_epoch}" +"%Y-%m-%d %H:%M:%S")
[[ "$quota" == "0" ]] && quota_disp="Unlimited" || quota_disp="${quota} GB"
[[ "$iplimit" == "0" ]] && ip_disp="Unlimited" || ip_disp="$iplimit"

vmesslink1=$(vmess_link 443 tls)
vmesslink2=$(vmess_link 80 none)

TEKS="<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>      ⊹ VMESS ACCOUNT ⊹</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Remarks   :</b> <code>${user}</code>
<b>Host/IP   :</b> <code>${domain}</code>
<b>Port TLS  :</b> <code>443</code>
<b>Port HTTP :</b> <code>80</code>
<b>UUID      :</b> <code>${uuid}</code>
<b>AlterId   :</b> <code>0</code>
<b>Network   :</b> <code>ws</code>
<b>Path      :</b> <code>/ (multipath)</code>
<b>Quota     :</b> <code>${quota_disp}</code>
<b>Limit IP  :</b> <code>${ip_disp}</code>
<b>Expired   :</b> <code>${exp_disp}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Link TLS  :</b>
<code>${vmesslink1}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Link HTTP :</b>
<code>${vmesslink2}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>"
tg_send "$TEKS"

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;42;30m                 VMESS ACCOUNT CREATED                      \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Remarks      : ${user}"
echo -e " Host/IP      : ${domain}"
echo -e " Port TLS     : 443"
echo -e " Port HTTP    : 80"
echo -e " UUID         : ${uuid}"
echo -e " AlterId      : 0"
echo -e " Network      : ws"
echo -e " Path         : / (multipath)"
echo -e " Quota        : ${quota_disp}"
echo -e " Limit IP     : ${ip_disp}"
echo -e " Expired      : ${exp_disp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Link TLS  :"
echo -e " ${vmesslink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Link HTTP :"
echo -e " ${vmesslink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
read -n 1 -s -r -p " Press any key to back to menu..."
menu
