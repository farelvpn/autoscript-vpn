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
line
echo -e "${WHITE}  CREATE SSH TRIAL ACCOUNT${NC}"
line
while true; do read -rp "Duration (m/h/d, e.g. 60m): " duration; valid_duration "$duration" && break; err "Format: 60m, 2h, 1d."; done
while true; do read -rp "Limit IP (number): " limit_ip; valid_number "$limit_ip" && break; err "Number only."; done

user="trial$(gen_pass 6)"
pass=$(gen_pass 10)
secs=$(duration_to_seconds "$duration")
# acc_ssh_create works in whole days; for sub-day trials compute epoch directly.
exp_epoch=$(( $(date +%s) + secs ))
exp_system=$(date -d "@${exp_epoch}" +%Y-%m-%d)

if db_account_exists "ssh" "$user" || id "$user" &>/dev/null; then
  err "Generated username collision, retry."; exit 1
fi
useradd -e "$exp_system" -M -N -s /sbin/nologin "$user" || { err "useradd failed"; exit 1; }
echo "${user}:${pass}" | chpasswd || { userdel --force "$user" >/dev/null 2>&1; err "chpasswd failed"; exit 1; }
db_insert_account "ssh" "$user" "$pass" 0 "$limit_ip" "$exp_epoch"
db_audit "create" "ssh" "$user" "trial ${duration}"

exp_disp=$(date -d "@${exp_epoch}" +"%d-%m-%Y %H:%M:%S")

tg_send "<b>[ SSH TRIAL ]</b>
Domain   : <code>${domain}</code> / <code>${ip}</code>
Username : <code>${user}</code>
Password : <code>${pass}</code>
Limit IP : <code>${limit_ip}</code>
Expired  : <code>${exp_disp}</code>"

clear
line
echo -e "${WHITE}  SSH TRIAL CREATED${NC}"
line
echo -e "Domain   : ${domain} / ${ip}"
echo -e "Username : ${user}"
echo -e "Password : ${pass}"
echo -e "Limit IP : ${limit_ip}"
echo -e "Expired  : ${exp_disp}"
line
echo -e "Config HTTP Custom: ${domain}:1-65535@${user}:${pass}"
line
read -n 1 -s -r -p "Press any key to menu..."
menu
