#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create trial Trojan account
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;41;36m                 CREATE TROJAN TRIAL ACCOUNT                \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
while true; do read -rp "Expired (60m/1h/1d): " duration; valid_duration "$duration" && break; err "Format: 60m, 1h, 1d."; done

user="trial$(gen_pass 6)"
secret=$(gen_uuid)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))

if ! acc_xray_create "trojan" "$user" "$secret" 10 2 "$exp_epoch"; then err "Failed to create trial."; exit 1; fi

exp_disp=$(date -d "@${exp_epoch}" +"%Y-%m-%d %H:%M:%S")
trojanlink1="trojan://${secret}@${domain}:443?type=ws&security=tls&host=${domain}&path=/trojan&sni=${domain}#${user}"

TEKS="<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>   ⊹ TROJAN TRIAL ACCOUNT ⊹</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Remarks   :</b> <code>${user}</code>
<b>Host/IP   :</b> <code>${domain}</code>
<b>Port TLS  :</b> <code>443</code>
<b>Key       :</b> <code>${secret}</code>
<b>Network   :</b> <code>ws</code>
<b>Path      :</b> <code>/trojan</code>
<b>Quota     :</b> <code>10 GB</code>
<b>Limit IP  :</b> <code>2</code>
<b>Expired   :</b> <code>${exp_disp}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Link TLS  :</b>
<code>${trojanlink1}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>"
tg_send "$TEKS"

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;42;30m                 TROJAN TRIAL CREATED                       \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Remarks      : ${user}"
echo -e " Host/IP      : ${domain}"
echo -e " Key          : ${secret}"
echo -e " Network/Path : ws  /trojan"
echo -e " Quota        : 10 GB     Limit IP : 2"
echo -e " Expired      : ${exp_disp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Link TLS  :"
echo -e " ${trojanlink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
read -n 1 -s -r -p " Press any key to back to menu..."
menu
