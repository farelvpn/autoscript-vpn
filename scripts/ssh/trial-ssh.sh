#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by risqinf
# Description: Create trial SSH account
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/risqinf/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

require_root
db_init
domain=$(get_domain)
ip=$(get_ip)

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;41;36m                 CREATE SSH TRIAL ACCOUNT                   \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
while true; do read -rp "Expired (60m/2h/1d): " duration; valid_duration "$duration" && break; err "Format: 60m, 2h, 1d."; done
while true; do read -rp "Limit IP           : " limit_ip; valid_number "$limit_ip" && break; err "Number only."; done

user="trial$(gen_pass 6)"
pass=$(gen_pass 10)
secs=$(duration_to_seconds "$duration")
exp_epoch=$(( $(date +%s) + secs ))
exp_system=$(date -d "@${exp_epoch}" +%Y-%m-%d)

if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then err "Username collision, retry."; exit 1; fi
useradd -e "$exp_system" -M -N -s /sbin/nologin "$user" || { err "useradd failed"; exit 1; }
echo "${user}:${pass}" | chpasswd || { userdel --force "$user" >/dev/null 2>&1; err "chpasswd failed"; exit 1; }
db_insert_account "ssh" "$user" "$pass" 0 "$limit_ip" "$exp_epoch"
db_audit "create" "ssh" "$user" "trial ${duration}"

exp_disp=$(date -d "@${exp_epoch}" +"%Y-%m-%d %H:%M:%S")

TEKS="<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>     ⊹ SSH TRIAL ACCOUNT ⊹</b>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Username  :</b> <code>${user}</code>
<b>Password  :</b> <code>${pass}</code>
<b>Host/IP   :</b> <code>${domain}</code> / <code>${ip}</code>
<b>Limit IP  :</b> <code>${limit_ip}</code>
<b>Expired   :</b> <code>${exp_disp}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Port OpenSSH :</b> <code>22, 109</code>
<b>Port WS HTTP :</b> <code>80, 8888</code>
<b>Port WS TLS  :</b> <code>443</code>
<b>Port BadVPN  :</b> <code>7300</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
<b>Config HTTP Custom :</b>
<code>${domain}:1-65535@${user}:${pass}</code>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>"
tg_send "$TEKS"

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e "\e[0;42;30m                  SSH TRIAL CREATED                         \e[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Username     : ${user}"
echo -e " Password     : ${pass}"
echo -e " Host/IP      : ${domain} / ${ip}"
echo -e " Limit IP     : ${limit_ip}"
echo -e " Expired      : ${exp_disp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
echo -e " Config HTTP Custom :"
echo -e " ${domain}:1-65535@${user}:${pass}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
read -n 1 -s -r -p " Press any key to back to menu..."
menu
