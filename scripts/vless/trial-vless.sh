#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create trial VLESS account
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)

clear
line
echo -e "${WHITE}  TRIAL VLESS ACCOUNT${NC}"
line
while true; do read -rp "Duration (e.g. 30m/1h): " duration; valid_duration "$duration" && break; err "Format: 30m, 1h, 1d."; done

user="trial$(gen_pass 6)"
uuid=$(gen_uuid)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "vless" "$user" "$uuid" 10 2 "$exp_epoch"; then
  err "Failed to create trial."; exit 1
fi

exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")
link_tls="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"

tg_send "<b>[ VLESS TRIAL ]</b>%0AUsername: <code>${user}</code>%0AExpired: <code>${exp_disp}</code>%0A<code>${link_tls}</code>"

clear
line
echo -e "${WHITE}  VLESS TRIAL CREATED${NC}"
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
