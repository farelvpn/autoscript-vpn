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
        '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:"/",type:"none",host:$host,tls:$tls}' \
    | base64 -w 0 | sed 's/^/vmess:\/\//'
}

clear
ui_header "CREATE VMESS TRIAL ACCOUNT"
while true; do read -rp "Expired (60m/1h/1d): " duration; valid_duration "$duration" && break; err "Format: 60m, 1h, 1d."; done

user="trial$(gen_pass 6)"
uuid=$(gen_uuid)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "vmess" "$user" "$uuid" 10 2 "$exp_epoch"; then err "Failed to create trial."; exit 1; fi

exp_disp=$(date -d "@${exp_epoch}" +"%Y-%m-%d %H:%M:%S")
vmesslink1=$(vmess_link 443 tls)
vmesslink2=$(vmess_link 80 none)

TEKS="<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>    ⊹ VMESS TRIAL ACCOUNT ⊹</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Remarks   :</b> <code>${user}</code>
<b>Host/IP   :</b> <code>${domain}</code>
<b>Port TLS  :</b> <code>443</code>
<b>Port HTTP :</b> <code>80</code>
<b>UUID      :</b> <code>${uuid}</code>
<b>AlterId   :</b> <code>0</code>
<b>Network   :</b> <code>ws</code>
<b>Path      :</b> <code>/ (multipath)</code>
<b>Quota     :</b> <code>10 GB</code>
<b>Limit IP  :</b> <code>2</code>
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
ui_header "VMESS TRIAL CREATED"
echo -e " Remarks      : ${user}"
echo -e " Host/IP      : ${domain}"
echo -e " UUID         : ${uuid}"
echo -e " Network/Path : ws  / (multipath)"
echo -e " Quota        : 10 GB     Limit IP : 2"
echo -e " Expired      : ${exp_disp}"
ui_rule
echo -e " Link TLS  :"
echo -e " ${vmesslink1}"
ui_rule
echo -e " Link HTTP :"
echo -e " ${vmesslink2}"
ui_rule
read -n 1 -s -r -p " Press any key to back to menu..."
menu
