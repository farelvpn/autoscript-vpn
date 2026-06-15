#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create VLESS account (SQLite + pure-JSON config)
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)

clear
ui_header "ADD VLESS ACCOUNT"

# Username
while true; do
  read -rp "Username       : " user
  if ! valid_username "$user"; then
    err "Username must be 3-32 chars: letters, numbers, underscore."; continue
  fi
  if db_account_exists "vless" "$user" || cfg_client_exists "$user"; then
    err "Username '$user' already exists."; continue
  fi
  break
done

# UUID
read -rp "Custom UUID    : (Enter to auto) " uuid
if [[ -z "$uuid" ]]; then
  uuid=$(gen_uuid)
elif ! valid_uuid "$uuid"; then
  err "Invalid UUID format."; exit 1
fi

while true; do read -rp "Quota (GB,0=unl): " quota; valid_number "$quota" && break; err "Number only."; done
while true; do read -rp "Limit IP (0=unl): " iplimit; valid_number "$iplimit" && break; err "Number only."; done
while true; do read -rp "Expired (30m/2h/1d): " duration; valid_duration "$duration" && break; err "Format: 30m, 2h, 1d."; done

secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "vless" "$user" "$uuid" "$quota" "$iplimit" "$exp_epoch"; then
  err "Failed to create account."; exit 1
fi

exp_disp=$(date -d "@${exp_epoch}" +"%Y-%m-%d %H:%M:%S")
[[ "$quota" == "0" ]] && quota_disp="Unlimited" || quota_disp="${quota} GB"
[[ "$iplimit" == "0" ]] && ip_disp="Unlimited" || ip_disp="$iplimit"

vlesslink1="vless://${uuid}@${domain}:443?path=/vless&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:80?path=/vless&encryption=none&type=ws&host=${domain}#${user}"

# Telegram (HTML, properly escaped + delivery-checked via tg_send)
tg_send "$(xray_tg_text vless "$user" "$uuid" "$domain" "$quota_disp" "$ip_disp" "$exp_disp")"

clear
ui_header "VLESS ACCOUNT CREATED"
echo -e " Remarks      : ${user}"
echo -e " Host/IP      : ${domain}"
echo -e " Port TLS     : 443"
echo -e " Port HTTP    : 80"
echo -e " UUID         : ${uuid}"
echo -e " Encryption   : none"
echo -e " Network      : ws"
echo -e " Path         : /vless"
echo -e " Quota        : ${quota_disp}"
echo -e " Limit IP     : ${ip_disp}"
echo -e " Expired      : ${exp_disp}"
ui_rule
echo -e " Link TLS  :"
echo -e " ${vlesslink1}"
ui_rule
echo -e " Link HTTP :"
echo -e " ${vlesslink2}"
ui_rule
read -n 1 -s -r -p " Press any key to back to menu..."
menu
